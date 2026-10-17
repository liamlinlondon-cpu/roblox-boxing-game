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
for _, eventName in ipairs({ "MatchResult", "ShopAction", "ArenaAction", "CombatAction", "VipAuction" }) do
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
		return
	end

	local resultEvent = eventsFolder:FindFirstChild("MatchResult")
	if resultEvent then
		resultEvent:FireClient(player, {
			type = "treadmill_result",
			message = string.format("%s complete! +%.0f max stamina.", tier.name, tier.gain),
		})
	end
	sendPlayerStats(player)
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

Players.PlayerRemoving:Connect(function(player)
	lastTrainTime[player] = nil
end)

flowEvent.OnServerEvent:Connect(function(player, action)
	if action == "home" then
		handleHome(player)
	elseif action == "gym" then
		handleGym(player)
	elseif action == "train_strength" then
		handleTrainStrength(player)
	elseif type(action) == "string" and action:sub(1, 10) == "treadmill_" then
		handleTreadmill(player, action:sub(11))
	elseif action == "shop" then
		handleShop(player)
	elseif action == "arena" then
		handleArena(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local data = getPlayerData(player)
	data.location = "home"
	stateEvent:FireClient(player, {
		type = "location",
		location = "home",
	})
	sendPlayerStats(player)
end)

return {
	setLocation = setLocation,
	getPlayerData = getPlayerData,
}
