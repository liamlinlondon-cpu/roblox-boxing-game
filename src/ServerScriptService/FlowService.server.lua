local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))
local Shop = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shop"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local flowEvent = eventsFolder:FindFirstChild("FlowAction")
if not flowEvent then
	flowEvent = Instance.new("RemoteEvent")
	flowEvent.Name = "FlowAction"
	flowEvent.Parent = eventsFolder
end

local stateEvent = eventsFolder:FindFirstChild("StateUpdate")
if not stateEvent then
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "StateUpdate"
	stateEvent.Parent = eventsFolder
end

-- Other scripts WaitForChild these, so they must exist even though they're used elsewhere
for _, eventName in ipairs({ "MatchResult", "ShopAction", "ArenaAction", "VipAuction" }) do
	if not eventsFolder:FindFirstChild(eventName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = eventName
		remote.Parent = eventsFolder
	end
end

local function getPlayerData(player)
	return FighterStats.GetPlayerData(player)
end

local function setLocation(player, location)
	local data = getPlayerData(player)
	data.location = location
	stateEvent:FireClient(player, {
		type = "location",
		location = location,
	})
end

local function sendPlayerStats(player)
	local data = getPlayerData(player)
	local resultEvent = eventsFolder:FindFirstChild("MatchResult")
	if resultEvent then
		resultEvent:FireClient(player, {
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
end

local function handleGym(player)
	setLocation(player, "gym")
end

local function handleTrainStrength(player)
	local data = getPlayerData(player)
	FighterStats.TrainStrength(data, 50)
	data.health = 100
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	setLocation(player, "gym")
	sendPlayerStats(player)
end

local function handleTreadmill(player, tierKey)
	local data = getPlayerData(player)
	local success, tier = FighterStats.TrainStamina(data, tierKey)
	if not success then
		return false
	end

	local resultEvent = eventsFolder:FindFirstChild("MatchResult")
	if resultEvent then
		resultEvent:FireClient(player, {
			type = "treadmill_result",
			message = string.format("%s complete! +%.0f max stamina.", tier.name, tier.gain),
		})
	end
	sendPlayerStats(player)
	return true
end

local function handleHome(player)
	setLocation(player, "home")
end

local function handleShop(player)
	setLocation(player, "shop")
end

local function handleArena(player)
	setLocation(player, "arena")
end

local running = {} -- players currently on a treadmill

-- Nav bar teleports (GYM / ARENA / SHOP / VIP SHOP)
local function handleGoto(player, place)
	local character = player.Character
	if not character or running[player] or getPlayerData(player).isInMatch then
		return
	end

	local target
	if place == "gym" then
		target = WorldConfig.GetGymPoint(1, WorldConfig.Gyms.Points.Entrance)
	elseif place == "vipshop" then
		target = WorldConfig.GetGymPoint(WorldConfig.Gyms.Count, WorldConfig.Gyms.Points.Entrance)
	elseif place == "arena" then
		target = CFrame.lookAt(WorldConfig.ArenaEntrance, WorldConfig.Arena.Center + Vector3.new(0, WorldConfig.ArenaEntrance.Y, 0))
	elseif place == "shop" then
		local shopPos = WorldConfig.Shop.Position
		target = CFrame.lookAt(shopPos + Vector3.new(0, 4, -10), shopPos + Vector3.new(0, 4, 0))
	end
	if target then
		character:PivotTo(target)
		setLocation(player, "world")
	end
end

-- Punching bag stations inside the gyms (built by WorldBuilder)
local lastTrainTime = {}

local function onStationTriggered(prompt, player)
	local clock = os.clock()
	if lastTrainTime[player] and clock - lastTrainTime[player] < WorldConfig.Gyms.TrainCooldown then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pad = prompt.Parent
	if not root or (root.Position - pad.Position).Magnitude > 12 then
		return
	end
	lastTrainTime[player] = clock

	local amount = prompt:GetAttribute("Vip") and WorldConfig.Gyms.VipTrainAmount or WorldConfig.Gyms.FreeTrainAmount
	FighterStats.TrainStrength(getPlayerData(player), amount)
	sendPlayerStats(player)
end

local function hookStation(prompt)
	prompt.Triggered:Connect(function(player)
		onStationTriggered(prompt, player)
	end)
end

for _, prompt in ipairs(CollectionService:GetTagged("GymStation")) do
	hookStation(prompt)
end
CollectionService:GetInstanceAddedSignal("GymStation"):Connect(hookStation)

-- Treadmill stations inside the gyms (built by WorldBuilder)
local RUN_SECONDS = 6
local RUN_ANIMATIONS = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507767714",
	[Enum.HumanoidRigType.R6] = "rbxassetid://180426354",
}
-- Puts the player on the belt, plays the run animation for RUN_SECONDS, then pays out the stamina.
local function runOnTreadmill(player, deck, tierKey)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	running[player] = true

	local oldSpeed, oldJump, oldUseJumpPower = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower
	local oldJumpHeight = humanoid.JumpHeight
	character:PivotTo(deck.CFrame * CFrame.new(0, 3.6, -1.5) * CFrame.Angles(0, math.pi, 0))
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = RUN_ANIMATIONS[humanoid.RigType] or RUN_ANIMATIONS[Enum.HumanoidRigType.R15]
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play(0.2)
	track:AdjustSpeed(1.6)

	local startTime = os.clock()
	while os.clock() - startTime < RUN_SECONDS do
		task.wait(0.1)
		if humanoid.Health <= 0 or not root.Parent or (root.Position - deck.Position).Magnitude > 12 then
			break
		end
		-- Hold the runner in place on the belt
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
	local completed = os.clock() - startTime >= RUN_SECONDS

	track:Stop(0.2)
	animation:Destroy()
	if humanoid.Parent then
		humanoid.WalkSpeed = oldSpeed
		humanoid.JumpPower = oldJump
		humanoid.JumpHeight = oldJumpHeight
		humanoid.UseJumpPower = oldUseJumpPower
	end
	running[player] = nil

	if completed then
		handleTreadmill(player, tierKey)
	end
end

local function hookTreadmill(prompt)
	prompt.Triggered:Connect(function(player)
		if running[player] then
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - prompt.Parent.Position).Magnitude > 14 then
			return
		end

		local tierKey = prompt:GetAttribute("Tier")
		if not getPlayerData(player).treadmills[tierKey] then
			local openStore = script.Parent:WaitForChild("StoreService"):WaitForChild("OpenStore")
			openStore:Fire(player, "normal")
			return
		end

		runOnTreadmill(player, prompt.Parent, tierKey)
	end)
end

for _, prompt in ipairs(CollectionService:GetTagged("TreadmillStation")) do
	hookTreadmill(prompt)
end
CollectionService:GetInstanceAddedSignal("TreadmillStation"):Connect(hookTreadmill)

Players.PlayerRemoving:Connect(function(player)
	running[player] = nil
	lastTrainTime[player] = nil
end)

flowEvent.OnServerEvent:Connect(function(player, action)
	if action == "home" then
		handleHome(player)
	elseif action == "gym" then
		handleGym(player)
	elseif action == "train_strength" then
		handleTrainStrength(player)
	elseif type(action) == "string" and action:sub(1, 5) == "goto_" then
		handleGoto(player, action:sub(6))
	elseif action == "shop" then
		handleShop(player)
	elseif action == "arena" then
		handleArena(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local data = getPlayerData(player)
	data.location = "world"
	stateEvent:FireClient(player, {
		type = "location",
		location = "world",
	})
	sendPlayerStats(player)
end)

return {
	setLocation = setLocation,
	getPlayerData = getPlayerData,
}
