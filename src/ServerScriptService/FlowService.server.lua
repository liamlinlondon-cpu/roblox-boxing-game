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
for _, eventName in ipairs({ "MatchResult", "ShopAction", "ArenaAction", "CombatAction", "VipAuction", "GymTraining" }) do
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

-- ==================== GYM TRAINING ====================
-- Punching bag stations are built by WorldBuilder. A player takes a station, picks a punch count
-- and weight in GymTrainingClient, and the server runs the punches and awards power per hit.

local TRAINING = WorldConfig.Training
local PUNCH_BROADCAST_RADIUS = 150

local trainingEvent = eventsFolder:WaitForChild("GymTraining")
local trainingSessions = {} -- [player] = { pad, prompt, bag, isVip, token, running, diedConnection }
local stationOwners = {} -- [pad] = player

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function releaseStation(player)
	local session = trainingSessions[player]
	if not session then
		return
	end
	trainingSessions[player] = nil
	session.token += 1 -- cancels any running set
	stationOwners[session.pad] = nil
	session.prompt.Enabled = true
	if session.diedConnection then
		session.diedConnection:Disconnect()
	end

	local root = getRoot(player)
	if root then
		root.Anchored = false
	end
	if player.Parent then
		trainingEvent:FireClient(player, "close")
	end
end

local function claimStation(prompt, player)
	local pad = prompt.Parent
	if trainingSessions[player] or stationOwners[pad] or running[player] then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(player)
	local bag = pad.Parent:FindFirstChild(pad.Name .. "Bag")
	if not humanoid or humanoid.Health <= 0 or not root or not bag or (root.Position - pad.Position).Magnitude > 12 then
		return
	end

	-- Plant the player on the pad, facing the bag
	local toBag = (bag.Position - pad.Position) * Vector3.new(1, 0, 1)
	local hipOffset = humanoid.RigType == Enum.HumanoidRigType.R6 and 3 or humanoid.HipHeight + root.Size.Y / 2
	local standPosition = pad.Position + toBag.Unit * 1.5 + Vector3.new(0, pad.Size.Y / 2 + hipOffset, 0)
	character:PivotTo(CFrame.lookAt(standPosition, Vector3.new(bag.Position.X, standPosition.Y, bag.Position.Z)))
	root.Anchored = true

	local session = {
		pad = pad,
		prompt = prompt,
		bag = bag,
		isVip = prompt:GetAttribute("Vip") == true,
		token = 0,
		running = false,
	}
	session.diedConnection = humanoid.Died:Connect(function()
		releaseStation(player)
	end)
	trainingSessions[player] = session
	stationOwners[pad] = player
	prompt.Enabled = false

	trainingEvent:FireClient(player, "open", {
		isVip = session.isVip,
		strength = getPlayerData(player).strength,
	})
end

local function broadcastPunch(player, bag, side, lbs)
	local character = player.Character
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = getRoot(other)
		if other == player or (otherRoot and (otherRoot.Position - bag.Position).Magnitude < PUNCH_BROADCAST_RADIUS) then
			trainingEvent:FireClient(other, "punch", character, bag, side, lbs)
		end
	end
end

local function startTraining(player, punchCount, weightIndex, auto)
	local session = trainingSessions[player]
	local weight = TRAINING.Weights[weightIndex]
	if not session or not weight or not table.find(TRAINING.PunchCounts, punchCount) then
		return
	end

	local data = getPlayerData(player)
	if data.strength < weight.requiredStrength then
		trainingEvent:FireClient(player, "notice", string.format("%d lbs punches unlock at %d strength.", weight.lbs, weight.requiredStrength))
		return
	end

	session.token += 1
	local token = session.token
	session.running = true
	local gainPerPunch = weight.power * (session.isVip and TRAINING.VipMultiplier or 1)

	local function isActive()
		return trainingSessions[player] == session and session.token == token
	end

	task.spawn(function()
		repeat
			local gained = 0
			for punch = 1, punchCount do
				task.wait(weight.interval)
				if not isActive() then
					return
				end
				FighterStats.TrainStrength(data, gainPerPunch)
				gained += gainPerPunch
				broadcastPunch(player, session.bag, punch % 2 == 1 and "Right" or "Left", weight.lbs)
				trainingEvent:FireClient(player, "progress", {
					punch = punch,
					total = punchCount,
					gain = gainPerPunch,
					gained = gained,
					strength = data.strength,
				})
				sendPlayerStats(player)
			end
			trainingEvent:FireClient(player, "setComplete", { gained = gained, strength = data.strength, auto = auto })
			if auto then
				task.wait(TRAINING.AutoRestSeconds)
			end
		until not auto or not isActive()

		if isActive() then
			session.running = false
		end
	end)
end

trainingEvent.OnServerEvent:Connect(function(player, action, punchCount, weightIndex, auto)
	if action == "start" then
		startTraining(player, punchCount, weightIndex, auto == true)
	elseif action == "stop" then
		local session = trainingSessions[player]
		if session then
			session.token += 1
			session.running = false
			trainingEvent:FireClient(player, "stopped")
		end
	elseif action == "leave" then
		releaseStation(player)
	end
end)

local function hookStation(prompt)
	prompt.Triggered:Connect(function(player)
		claimStation(prompt, player)
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
	releaseStation(player)
end)

-- Free stations whose player was moved away (e.g. teleported off the VIP floor when their session ended)
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in pairs(trainingSessions) do
			local root = getRoot(player)
			if not root or (root.Position - session.pad.Position).Magnitude > 10 then
				releaseStation(player)
			end
		end
	end
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
