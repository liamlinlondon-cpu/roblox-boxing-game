-- Strength, kick and stamina bars at the top of the screen. Updated from any MatchResult message that
-- carries those stats (FlowService, StoreService and ArenaService all send them).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local events = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = events:WaitForChild("MatchResult")
local flowEvent = events:WaitForChild("FlowAction")

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 215, 0)
local FILL_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatBarsGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "StatBars"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Size = UDim2.new(0.4, 0, 0, 90)
container.Position = UDim2.new(0.5, 0, 0, 8)
container.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
container.BackgroundTransparency = 0.35
container.BorderSizePixel = 2
container.BorderColor3 = GOLD
container.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(280, 90)
sizeConstraint.MaxSize = Vector2.new(460, 90)
sizeConstraint.Parent = container

local function makeBar(name, y, fillColor)
	local label = Instance.new("TextLabel")
	label.Name = name .. "Label"
	label.Size = UDim2.new(0.25, 0, 0, 22)
	label.Position = UDim2.new(0.02, 0, 0, y)
	label.BackgroundTransparency = 1
	label.Text = string.upper(name)
	label.TextColor3 = GOLD
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local back = Instance.new("Frame")
	back.Name = name .. "Bar"
	back.Size = UDim2.new(0.71, 0, 0, 22)
	back.Position = UDim2.new(0.27, 0, 0, y)
	back.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	back.BorderSizePixel = 0
	back.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -8, 1, 0)
	text.Position = UDim2.new(0, 4, 0, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.4
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.ZIndex = 2
	text.Text = "..."
	text.Parent = back

	return fill, text
end

local strengthFill, strengthText = makeBar("Strength", 6, Color3.fromRGB(210, 60, 60))
local kickFill, kickText = makeBar("Kick", 34, Color3.fromRGB(60, 110, 220))
local staminaFill, staminaText = makeBar("Stamina", 62, Color3.fromRGB(60, 170, 90))

local function setFill(fill, fraction)
	fraction = math.clamp(fraction, 0, 1)
	TweenService:Create(fill, FILL_TWEEN, { Size = UDim2.new(fraction, 0, 1, 0) }):Play()
end

-- The strength bar shows progress through the current body stage toward the next one
local function updateStrength(strength)
	local stages = FighterStats.Stages
	local index = FighterStats.GetStageIndex(strength)
	local current, nextStage = stages[index], stages[index + 1]
	if nextStage then
		setFill(strengthFill, (strength - current.minStrength) / (nextStage.minStrength - current.minStrength))
		strengthText.Text = string.format("%s / %s  ·  next: %s", Catalog.FormatNumber(strength), Catalog.FormatNumber(nextStage.minStrength), nextStage.name)
	else
		setFill(strengthFill, 1)
		strengthText.Text = string.format("%s  ·  %s", Catalog.FormatNumber(strength), current.name)
	end
end

-- Kick has no maximum, so its bar fills toward the next kicking-bag weight unlock
local function updateKick(kick)
	local previous, nextUnlock = 0, nil
	for _, weight in ipairs(WorldConfig.Training.Weights) do
		if kick < weight.required then
			nextUnlock = weight
			break
		end
		previous = weight.required
	end
	if nextUnlock then
		setFill(kickFill, (kick - previous) / (nextUnlock.required - previous))
		kickText.Text = string.format("%s / %s  ·  next: %d lbs kicks", Catalog.FormatNumber(kick), Catalog.FormatNumber(nextUnlock.required), nextUnlock.lbs)
	else
		setFill(kickFill, 1)
		kickText.Text = string.format("%s  ·  all weights unlocked", Catalog.FormatNumber(kick))
	end
end

local function updateStamina(stamina, maxStamina)
	-- Infinite stamina (/infinitystamina) would give inf/inf, so show it as a full bar
	local fraction = maxStamina == math.huge and 1 or (maxStamina > 0 and stamina / maxStamina or 0)
	setFill(staminaFill, fraction)
	staminaText.Text = string.format("%s / %s", Catalog.FormatNumber(stamina), Catalog.FormatNumber(maxStamina))
end

matchResultEvent.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	if data.type == "stats" and type(data.strength) == "number" then
		updateStrength(data.strength)
	end
	if data.type == "stats" and type(data.kick) == "number" then
		updateKick(data.kick)
	end
	if type(data.stamina) == "number" and type(data.maxStamina) == "number" then
		updateStamina(data.stamina, data.maxStamina)
	end
end)

-- The first stats message can arrive before this script connects, so ask for a fresh copy
flowEvent:FireServer("request_stats")
