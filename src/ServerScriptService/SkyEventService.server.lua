-- Sky color events: every few minutes the sky turns a random color (Catalog.SkyColors) for a while.
-- The current event is published as ReplicatedStorage attributes that replicate to every client:
--   SkyEventColor  = color id ("red", "blue", ...) or nil when no event is running
--   SkyEventEndsAt = Workspace:GetServerTimeNow() when the event ends
-- StoreService only sells a color skin while its event is running; SkyEventClient shows the banner.
-- Chat commands like "/ruby" start a specific color's event right away (see WorldConfig.SkyEvents.Commands).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local EVENTS = WorldConfig.SkyEvents
local FADE = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local WHITE = Color3.new(1, 1, 1)

-- The Atmosphere colors the sky and horizon; reuse the place's own if it has one
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 199, 199)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
end
local normalAtmosphere = {
	Color = atmosphere.Color,
	Decay = atmosphere.Decay,
	Density = atmosphere.Density,
	Haze = atmosphere.Haze,
}

-- A light tint over everything so the whole world takes on the event color
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "SkyEventTint"
tint.TintColor = WHITE
tint.Parent = Lighting

local function setLook(sky)
	if sky then
		TweenService:Create(atmosphere, FADE, {
			Color = sky.color,
			Decay = sky.color:Lerp(Color3.new(0, 0, 0), 0.4),
			Density = 0.4,
			Haze = 2.5,
		}):Play()
		TweenService:Create(tint, FADE, { TintColor = WHITE:Lerp(sky.color, 0.35) }):Play()
	else
		TweenService:Create(atmosphere, FADE, normalAtmosphere):Play()
		TweenService:Create(tint, FADE, { TintColor = WHITE }):Play()
	end
end

local function pickColor(previousId)
	local choices = {}
	for _, sky in ipairs(Catalog.SkyColors) do
		if sky.id ~= previousId then
			table.insert(choices, sky)
		end
	end
	return choices[math.random(#choices)]
end

-- Each start bumps `scheduleToken`, which cancels the previous event's pending end/next-start timers.
-- That lets a chat command start an event at any time without the old schedule interfering.
local scheduleToken = 0
local previousId = nil
local startEvent

local function endEvent(token)
	if token ~= scheduleToken then
		return
	end
	ReplicatedStorage:SetAttribute("SkyEventColor", nil)
	ReplicatedStorage:SetAttribute("SkyEventEndsAt", nil)
	setLook(nil)
	task.delay(EVENTS.IntervalSeconds, function()
		if token == scheduleToken then
			startEvent(pickColor(previousId))
		end
	end)
end

function startEvent(sky)
	scheduleToken += 1
	local token = scheduleToken
	previousId = sky.id
	-- Set the end time first so anything reacting to the color change can read it
	ReplicatedStorage:SetAttribute("SkyEventEndsAt", Workspace:GetServerTimeNow() + EVENTS.DurationSeconds)
	ReplicatedStorage:SetAttribute("SkyEventColor", sky.id)
	setLook(sky)
	task.delay(EVENTS.DurationSeconds, function()
		endEvent(token)
	end)
end

task.delay(EVENTS.FirstDelaySeconds, function()
	if scheduleToken == 0 then
		startEvent(pickColor(nil))
	end
end)

-- ==================== CHAT COMMANDS ====================
-- "/ruby", "/sapphire", ... start that color's event right away (WorldConfig.SkyEvents.Commands)

local function canUseCommands(player)
	if RunService:IsStudio() or table.find(EVENTS.CommandUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return player.UserId == game.CreatorId
end

local function runCommand(player, alias)
	local sky = Catalog.SkyColorById[EVENTS.Commands[alias] or ""]
	if sky and canUseCommands(player) then
		startEvent(sky)
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local commandsFolder = Instance.new("Folder")
	commandsFolder.Name = "SkyEventCommands"
	commandsFolder.Parent = TextChatService
	for alias in pairs(EVENTS.Commands) do
		local command = Instance.new("TextChatCommand")
		command.Name = "SkyEvent_" .. alias
		command.PrimaryAlias = "/" .. alias
		command.Parent = commandsFolder
		command.Triggered:Connect(function(textSource)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if player then
				runCommand(player, alias)
			end
		end)
	end
else
	-- Places still on the legacy chat
	local function listen(player)
		player.Chatted:Connect(function(message)
			local alias = string.match(string.lower(message), "^/(%w+)$")
			if alias then
				runCommand(player, alias)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in ipairs(Players:GetPlayers()) do
		listen(player)
	end
end
