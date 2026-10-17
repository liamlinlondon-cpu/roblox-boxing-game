local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local GYM_NAME = "BoxingGym"
local GYM_ORIGIN = Vector3.new(40, 0, 0)
local STRENGTH_PER_HIT = 50

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local function makePart(parent, name, size, position, material, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = GYM_ORIGIN + position
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sendStats(player, data)
	matchResultEvent:FireClient(player, {
		type = "stats",
		money = data.money,
		strength = data.strength,
		kick = data.kick,
		luck = data.luck,
		bodyStage = data.bodyStage,
		health = data.health,
		stamina = data.stamina,
		maxStamina = data.maxStamina,
	})
end

local function addPrompt(part, actionText, objectText, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(callback)
end

local function buildSandbag(parent, index, x)
	local rack = makePart(parent, "SandbagRack" .. index, Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, 7.5, -12), Enum.Material.Metal, Color3.fromRGB(60, 60, 60))
	local bag = makePart(parent, "Sandbag" .. index, Vector3.new(2, 4.5, 2), Vector3.new(x, 4.5, -12), Enum.Material.Fabric, Color3.fromRGB(170, 40, 40))
	local chain = makePart(parent, "SandbagChain" .. index, Vector3.new(0.2, 1, 0.2), Vector3.new(x, 7, -12), Enum.Material.Metal, Color3.fromRGB(150, 150, 150))
	rack.CanCollide = false
	chain.CanCollide = false

	addPrompt(bag, "Punch", "Sandbag", function(player)
		local data = FighterStats.GetPlayerData(player)
		FighterStats.TrainStrength(data, STRENGTH_PER_HIT)
		sendStats(player, data)
	end)
end

local function buildTreadmill(parent, tierKey, x)
	local tier = FighterStats.TreadmillTiers[tierKey]
	local colors = {
		regular = Color3.fromRGB(90, 90, 90),
		hacker = Color3.fromRGB(0, 200, 80),
		admin = Color3.fromRGB(60, 120, 255),
		owner = Color3.fromRGB(255, 200, 0),
	}

	local belt = makePart(parent, tierKey .. "TreadmillBelt", Vector3.new(3, 0.6, 6), Vector3.new(x, 0.3, 12), Enum.Material.Metal, colors[tierKey])
	makePart(parent, tierKey .. "TreadmillConsole", Vector3.new(3, 2.5, 0.5), Vector3.new(x, 2, 9.2), Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = belt
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tier.name
	label.TextColor3 = colors[tierKey]
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	addPrompt(belt, "Run", tier.name, function(player)
		local data = FighterStats.GetPlayerData(player)
		local success = FighterStats.TrainStamina(data, tierKey)
		if success then
			matchResultEvent:FireClient(player, {
				type = "treadmill_result",
				message = string.format("%s complete! +%.0f max stamina.", tier.name, tier.gain),
			})
			sendStats(player, data)
		end
	end)
end

local function buildGym()
	local existing = Workspace:FindFirstChild(GYM_NAME)
	if existing then
		existing:Destroy()
	end

	local gym = Instance.new("Folder")
	gym.Name = GYM_NAME
	gym.Parent = Workspace

	makePart(gym, "Floor", Vector3.new(40, 1, 36), Vector3.new(0, -0.5, 0), Enum.Material.Wood, Color3.fromRGB(120, 85, 55))

	for i, x in ipairs({ -12, -4, 4, 12 }) do
		buildSandbag(gym, i, x)
	end

	for i, key in ipairs({ "regular", "hacker", "admin", "owner" }) do
		buildTreadmill(gym, key, -12 + (i - 1) * 8)
	end

	return gym
end

buildGym()
