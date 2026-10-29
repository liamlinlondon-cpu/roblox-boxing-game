-- The Infinity Room, sealed under the secret base under the map (WorldBuilder, WorldConfig.SecretBase):
-- anyone who gets inside (by flying down through the floors with /flynoclip) gets infinity everything:
-- strength, kick, stamina, money, wins and beat the game, like the /infinity commands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")
local announcementEvent = eventsFolder:WaitForChild("Announcement")

local ROOM = WorldConfig.SecretBase.InfinityRoom
local CENTER = WorldConfig.Arena.Center

local function insideInfinityRoom(position)
	local offset = position - CENTER
	return math.abs(offset.X) < ROOM.Size / 2
		and math.abs(offset.Z) < ROOM.Size / 2
		and position.Y > ROOM.FloorTop
		and position.Y < ROOM.FloorTop + ROOM.Height
end

local function hasEverything(data)
	return data.strength == math.huge
		and data.kick == math.huge
		and data.maxStamina == math.huge
		and data.money == math.huge
		and data.arenaWins == math.huge
		and data.gameBeats == math.huge
end

local function giveEverything(player)
	local data = FighterStats.GetPlayerData(player)
	FighterStats.TrainStrength(data, math.huge)
	data.kick = math.huge
	data.maxStamina = math.huge
	data.stamina = math.huge
	data.money = math.huge
	data.arenaWins = math.huge
	data.gameBeats = math.huge
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
		arenaWins = data.arenaWins,
		gameBeats = data.gameBeats,
		rebirths = data.rebirths,
	})
	announcementEvent:FireClient(player, "♾️ INFINITY ROOM! You have infinity everything!")
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and insideInfinityRoom(root.Position) and not hasEverything(FighterStats.GetPlayerData(player)) then
				giveEverything(player)
			end
		end
	end
end)
