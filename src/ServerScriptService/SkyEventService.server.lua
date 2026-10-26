-- Sky color events: every few minutes the sky turns a color for a while, following
-- WorldConfig.SkyEvents.Schedule (yellow and orange are command-only; green, cyan and pink are banned
-- and only come when the owner spawns them from the VIP ADMIN panel).
-- The current event is published as ReplicatedStorage attributes that replicate to every client:
--   SkyEventColor  = color id ("red", "blue", ...) or nil when no event is running
--   SkyEventEndsAt = Workspace:GetServerTimeNow() when the event ends
-- StoreService only sells a color skin while its event is running; SkyEventClient shows the banner.
-- Chat commands like "/ruby" start a specific color's event right away (see WorldConfig.SkyEvents.Commands).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local Admins = require(script.Parent:WaitForChild("Admins"))

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

local RAINBOW_STEP = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
local lookToken = 0 -- bumped on every look change; stops a running rainbow cycle

local function setLook(sky)
	lookToken += 1
	local token = lookToken
	if sky and sky.rainbow then
		-- Cycle the sky through every hue until the look changes again
		task.spawn(function()
			local hue = 0
			while lookToken == token do
				local color = Color3.fromHSV(hue, 0.85, 1)
				TweenService:Create(atmosphere, RAINBOW_STEP, {
					Color = color,
					Decay = color:Lerp(Color3.new(0, 0, 0), 0.4),
					Density = 0.4,
					Haze = 2.5,
				}):Play()
				TweenService:Create(tint, RAINBOW_STEP, { TintColor = WHITE:Lerp(color, 0.35) }):Play()
				hue = (hue + 0.04) % 1
				task.wait(0.25)
			end
		end)
	elseif sky then
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

-- Natural events walk through EVENTS.Schedule in order and loop. Events started by chat commands
-- don't move the schedule, so it carries on from where it was afterwards.
local scheduleIndex = 0

-- Owner-only colors (green, cyan, pink) are banned from natural events and skipped if ever listed.
local function nextScheduledColor()
	for _ = 1, #EVENTS.Schedule do
		scheduleIndex = scheduleIndex % #EVENTS.Schedule + 1
		local sky = Catalog.SkyColorById[EVENTS.Schedule[scheduleIndex]]
		if sky and not sky.ownerOnly then
			return sky
		end
	end
	return Catalog.SkyColorById.blue
end

-- Each start bumps `scheduleToken`, which cancels the previous event's pending end/next-start timers.
-- That lets a chat command start an event at any time without the old schedule interfering.
local scheduleToken = 0
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
			startEvent(nextScheduledColor())
		end
	end)
end

function startEvent(sky)
	scheduleToken += 1
	local token = scheduleToken
	-- Set the end time first so anything reacting to the color change can read it
	ReplicatedStorage:SetAttribute("SkyEventEndsAt", Workspace:GetServerTimeNow() + EVENTS.DurationSeconds)
	ReplicatedStorage:SetAttribute("SkyEventColor", sky.id)
	setLook(sky)
	task.delay(EVENTS.DurationSeconds, function()
		endEvent(token)
	end)
end

-- Ends the running event now; the next scheduled event follows after the usual interval
local function clearEvent()
	if not ReplicatedStorage:GetAttribute("SkyEventColor") then
		return
	end
	scheduleToken += 1
	endEvent(scheduleToken)
end

task.delay(EVENTS.FirstDelaySeconds, function()
	if scheduleToken == 0 then
		startEvent(nextScheduledColor())
	end
end)

-- ==================== CHAT COMMANDS ====================
-- "/ruby", "/sapphire", ... start that color's event right away (WorldConfig.SkyEvents.Commands);
-- "/non color" ends the event and turns the sky back to normal.

-- Tells everyone who started it, in the banner next to the stat bars (AnnouncementClient)
local announcementEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Announcement")

-- The owner's VIP ADMIN panel starts events with buttons: invoke with a color id ("red", "rainbow", ...)
-- or "clear" for a normal sky. Invoked with nothing it only answers "is this the owner?".
local adminSkyEvent = Instance.new("RemoteFunction")
adminSkyEvent.Name = "AdminSkyEvent"
adminSkyEvent.Parent = ReplicatedStorage:WaitForChild("Events")

adminSkyEvent.OnServerInvoke = function(player, colorId)
	if not Admins.IsOwner(player) then
		return nil
	end
	if colorId == nil then
		return true
	end
	if colorId == "clear" then
		if ReplicatedStorage:GetAttribute("SkyEventColor") then
			clearEvent()
			announcementEvent:FireAllClients("👑 " .. player.DisplayName .. " turned the sky back to normal.")
		end
		return "The sky is back to normal."
	end
	local sky = type(colorId) == "string" and Catalog.SkyColorById[colorId]
	if not sky then
		return "Unknown event."
	end
	startEvent(sky)
	announcementEvent:FireAllClients("👑 " .. player.DisplayName .. " started a " .. string.upper(sky.name) .. " SKY event!")
	return sky.name .. " sky event started!"
end

local function runCommand(player, alias)
	if not Admins.IsAdmin(player) then
		return
	end
	if alias == EVENTS.ClearCommand or alias == EVENTS.ClearCommandAlias then
		if ReplicatedStorage:GetAttribute("SkyEventColor") then
			clearEvent()
			announcementEvent:FireAllClients("👑 " .. player.DisplayName .. " turned the sky back to normal.")
		end
		return
	end
	local sky = Catalog.SkyColorById[EVENTS.Commands[alias] or ""]
	if sky then
		startEvent(sky)
		announcementEvent:FireAllClients("👑 " .. player.DisplayName .. " started a " .. string.upper(sky.name) .. " SKY event!")
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local commandsFolder = Instance.new("Folder")
	commandsFolder.Name = "SkyEventCommands"
	commandsFolder.Parent = TextChatService
	local function addCommand(alias, secondaryAlias)
		local command = Instance.new("TextChatCommand")
		command.Name = "SkyEvent_" .. alias
		command.PrimaryAlias = "/" .. alias
		if secondaryAlias then
			command.SecondaryAlias = "/" .. secondaryAlias
		end
		command.Parent = commandsFolder
		-- Commands match on the first word, so "/non color" triggers "/non"
		command.Triggered:Connect(function(textSource)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if player then
				runCommand(player, alias)
			end
		end)
	end
	for alias in pairs(EVENTS.Commands) do
		addCommand(alias)
	end
	addCommand(EVENTS.ClearCommand, EVENTS.ClearCommandAlias)
else
	-- Places still on the legacy chat: use the first word ("/non color" -> "non")
	local function listen(player)
		player.Chatted:Connect(function(message)
			local alias = string.match(string.lower(message), "^/(%w+)")
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
