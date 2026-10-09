local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))
local Shop = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shop"))

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

local playerDataMap = {}

local function getPlayerData(player)
	if not playerDataMap[player] then
		playerDataMap[player] = FighterStats.CreatePlayerData()
	end
	return playerDataMap[player]
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
		})
	end
end

local function handleGym(player)
	local data = getPlayerData(player)
	FighterStats.TrainStrength(data, 50)
	data.health = 100
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	setLocation(player, "home")
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

flowEvent.OnServerEvent:Connect(function(player, action)
	if action == "home" then
		handleHome(player)
	elseif action == "gym" then
		handleGym(player)
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
