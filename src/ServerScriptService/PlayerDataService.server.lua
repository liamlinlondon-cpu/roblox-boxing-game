-- Saves each player's progress with a DataStore so it's still there when they come back.
-- Loaded when a player joins, saved every couple of minutes, when they leave, and when the server
-- shuts down. Progress only goes back to the start with the owner's /reset command.
--
-- Studio: saving only works there with Game Settings > Security > "Enable Studio Access to API
-- Services" turned on. Without it the game still runs, it just doesn't load or save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))

local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")

-- Fired after a player's saved progress is loaded, so StoreService can give back the Magic Carpet
-- and put the worn skin back on
local dataLoaded = Instance.new("BindableEvent")
dataLoaded.Name = "DataLoaded"
dataLoaded.Parent = script

local AUTOSAVE_SECONDS = 120
local LOAD_ATTEMPTS = 3

local store = DataStoreService:GetDataStore("BoxingPlayerData_v1")

-- Everything that's kept between visits (match state and health aren't)
local SAVED_FIELDS = {
	"strength", "kick", "luck", "money", "stamina", "maxStamina", "arenaWins", "arenaLosses",
	"treadmills", "luckPurchases", "winMultiplier", "carpet", "carpetPass", "gameBeats", "soldTools", "rebirths", "milestoneRewarded", "hulkSpinsGiven", "hulkSpins", "moneyGoal", "luckExpiresAt", "permanentLuck", "rebirthSkips", "robuxSpent", "ownedSkins", "skin", "ownerTreadmillAnywhere",
}

-- Players whose data loaded properly. Only they are saved, so a failed load never overwrites
-- good saved progress with a fresh start.
local loaded = {}

-- DataStores can't hold infinite numbers (from the owner's /infinity commands), so store them as "inf"
local function encode(value)
	if value == math.huge then
		return "inf"
	elseif type(value) == "table" then
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = encode(inner)
		end
		return copy
	end
	return value
end

local function decode(value)
	if value == "inf" then
		return math.huge
	elseif type(value) == "table" then
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = decode(inner)
		end
		return copy
	end
	return value
end

local function keyFor(player)
	return "player_" .. player.UserId
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

local function load(player)
	local saved, ok, err
	for attempt = 1, LOAD_ATTEMPTS do
		ok, err = pcall(function()
			saved = store:GetAsync(keyFor(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not player.Parent then
		return
	end
	if not ok then
		warn("Couldn't load progress for " .. player.Name .. "; it won't be saved this visit: " .. tostring(err))
		return
	end

	if type(saved) == "table" then
		local data = FighterStats.GetPlayerData(player)
		for _, field in ipairs(SAVED_FIELDS) do
			if saved[field] ~= nil then
				data[field] = decode(saved[field])
			end
		end
		data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	end
	loaded[player] = true
	sendStats(player)
	dataLoaded:Fire(player)
end

local function save(player)
	if not loaded[player] then
		return
	end
	local data = FighterStats.GetPlayerData(player)
	local payload = {}
	for _, field in ipairs(SAVED_FIELDS) do
		payload[field] = encode(data[field])
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)
	if not ok then
		warn("Couldn't save progress for " .. player.Name .. ": " .. tostring(err))
	end
end

Players.PlayerAdded:Connect(load)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	loaded[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(save, player)
		end
	end
end)

-- Save everyone before the server closes
game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)
