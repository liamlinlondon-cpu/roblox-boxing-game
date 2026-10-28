-- Money goals: how players earn money. A random goal shows at the top of the screen, like "Get 4,473
-- strength" (or kick, or stamina). Everything gained counts, training included. Finishing it pays money
-- and gives a new random goal, about double the last one, paying double too, up to MAX_LEVEL. Every
-- rebirth doubles the money (FighterStats.MoneyMultiplier). MoneyGoalClient shows the goal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local FighterStats = require(Modules:WaitForChild("FighterStats"))

local BASE_AMOUNT = 100 -- the first goal asks for 100 to 300 of a stat
local BASE_REWARD = 100 -- and pays 100 money (before the rebirth multiplier)
local MAX_LEVEL = 30 -- goals stop doubling here (the most money a goal pays)
local STATS = {
	{ key = "strength", field = "strength", name = "strength" },
	{ key = "kick", field = "kick", name = "kick" },
	{ key = "stamina", field = "maxStamina", name = "stamina" },
}

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = eventsFolder:WaitForChild("Announcement")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local goalEvent = Instance.new("RemoteEvent") -- server -> client: the current goal
goalEvent.Name = "MoneyGoal"
goalEvent.Parent = eventsFolder

local lastSeen = {} -- [player] = { strength = n, kick = n, stamina = n }: to spot what was gained

local function statInfo(key)
	for _, info in ipairs(STATS) do
		if info.key == key then
			return info
		end
	end
	return STATS[1]
end

-- A new random goal for the given level: a random stat, a random amount that doubles with the level
local function newGoal(level)
	level = math.clamp(level, 1, MAX_LEVEL)
	local scale = 2 ^ (level - 1)
	local info = STATS[math.random(1, #STATS)]
	return {
		level = level,
		stat = info.key,
		target = math.floor(BASE_AMOUNT * scale * (1 + math.random() * 2)),
		progress = 0,
		reward = BASE_REWARD * scale,
	}
end

local function currentGoal(data)
	if type(data.moneyGoal) ~= "table" or not data.moneyGoal.stat then
		data.moneyGoal = newGoal(1)
	end
	return data.moneyGoal
end

local function sendGoal(player)
	local data = FighterStats.GetPlayerData(player)
	local goal = currentGoal(data)
	goalEvent:FireClient(player, {
		stat = statInfo(goal.stat).name,
		target = goal.target,
		progress = math.min(goal.progress, goal.target),
		reward = goal.reward * FighterStats.MoneyMultiplier(data),
	})
end

local function sendStats(player)
	local data = FighterStats.GetPlayerData(player)
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
end

-- Every second: add whatever the player gained (going down, e.g. a rebirth, doesn't count) to the goal
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = FighterStats.GetPlayerData(player)
			local goal = currentGoal(data)
			local seen = lastSeen[player]
			local now = {}
			for _, info in ipairs(STATS) do
				now[info.key] = tonumber(data[info.field]) or 0
			end
			lastSeen[player] = now
			if seen then
				local gained = now[goal.stat] - (seen[goal.stat] or 0)
				if gained > 0 then
					goal.progress += gained
					if goal.progress >= goal.target then
						local money = goal.reward * FighterStats.MoneyMultiplier(data)
						data.money += money
						data.moneyGoal = newGoal(goal.level + 1)
						announcementEvent:FireClient(player, "💰 Goal done! +$" .. Catalog.FormatWithCommas(money))
						sendStats(player)
					end
					sendGoal(player)
				end
			else
				sendGoal(player)
			end
		end
	end
end)

-- Saved progress (with the saved goal) arrives after joining: show it, and start counting from here
script.Parent:WaitForChild("PlayerDataService"):WaitForChild("DataLoaded").Event:Connect(function(player)
	lastSeen[player] = nil
	sendGoal(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSeen[player] = nil
end)
