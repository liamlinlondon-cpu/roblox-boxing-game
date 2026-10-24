-- Admin chat commands (only admins can use them, see Admins; ChatCommandFilter keeps them out of chat):
--   /ban <username>             bans the player from the game (all servers) and kicks them if they're here
--   /unban <username>           lifts the ban
--   /fly, /unfly                toggles flying (FlyClient moves the character) / lands
--   /give <name> <item>         gives a player in the server an item, e.g. /give Bob owner treadmill
--   /luck <number> [name]       sets luck, e.g. /luck 64
--   /infinitystrength [name]    infinite strength (also /infinitykick, /infinitystamina, /infinitymoney)
-- <name> is the name shown above a player's head (display name) or their username; the start of it is
-- enough. Commands with [name] apply to the admin when no name is given. Results are shown to the admin
-- in chat, and a player who receives something gets a private message too.
--
-- Bans use Roblox's ban system (Players:BanAsync), which works in live servers. In Studio, where it
-- isn't available, the player is kicked and banned from this test session only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local Catalog = require(Modules:WaitForChild("Catalog"))
local Admins = require(script.Parent:WaitForChild("Admins"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local noticeEvent = Instance.new("RemoteEvent")
noticeEvent.Name = "AdminNotice"
noticeEvent.Parent = eventsFolder

local flyEvent = Instance.new("RemoteEvent")
flyEvent.Name = "AdminFly"
flyEvent.Parent = eventsFolder

local BAN_MESSAGE = "You have been banned from this game."
local sessionBans = {} -- [userId] = true: fallback when Players:BanAsync isn't available (Studio)

local function notify(player, text)
	noticeEvent:FireClient(player, text)
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
	})
end

-- Finds a player in this server by name or display name (exact first, then the start of it)
local function findPlayerInServer(query)
	query = string.lower(query)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == query or string.lower(player.DisplayName) == query then
			return player
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(player.Name), 1, #query) == query or string.sub(string.lower(player.DisplayName), 1, #query) == query then
			return player
		end
	end
	return nil
end

-- Returns userId, name for a player in the server or any Roblox username
local function resolveUser(query)
	local player = findPlayerInServer(query)
	if player then
		return player.UserId, player.Name
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, query)
	if ok and userId then
		return userId, query
	end
	return nil
end

-- For commands with an optional [name]: that player, or the admin when no name is given
local function targetOrSelf(admin, query)
	if not query then
		return admin
	end
	local target = findPlayerInServer(query)
	if not target then
		notify(admin, "Couldn't find \"" .. query .. "\" in this server.")
	end
	return target
end

local function tellTarget(admin, target, text)
	if target ~= admin then
		notify(target, text)
	end
end

-- ==================== BAN ====================

local function ban(admin, args)
	local query = args[1]
	local userId, name = resolveUser(query)
	if not userId then
		notify(admin, "Couldn't find a player called \"" .. query .. "\".")
		return
	end
	if userId == admin.UserId or Admins.IsAdminUserId(userId) then
		notify(admin, "You can't ban " .. name .. " (admins and the owner can't be banned).")
		return
	end

	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,
			Duration = -1, -- permanent
			DisplayReason = BAN_MESSAGE,
			PrivateReason = "Banned by " .. admin.Name .. " with /ban",
			ExcludeAltAccounts = false,
		})
	end)
	if ok then
		-- BanAsync also removes them from the game
		notify(admin, name .. " has been banned.")
		return
	end

	-- Ban API unavailable (e.g. in Studio): kick and keep them out of this server
	sessionBans[userId] = true
	local target = Players:GetPlayerByUserId(userId)
	if target then
		target:Kick(BAN_MESSAGE)
	end
	notify(admin, name .. " was kicked and banned from this server only (Roblox ban failed: " .. tostring(err) .. ").")
end

local function unban(admin, args)
	local query = args[1]
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, query)
	if not ok or not userId then
		notify(admin, "Couldn't find a Roblox user called \"" .. query .. "\".")
		return
	end
	sessionBans[userId] = nil
	local unbanned, err = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	if unbanned then
		notify(admin, query .. " has been unbanned.")
	else
		notify(admin, query .. " was unbanned from this server (Roblox unban failed: " .. tostring(err) .. ").")
	end
end

-- ==================== FLY ====================

local flying = {} -- [player] = true

local function setFlying(admin, enabled)
	flying[admin] = enabled or nil
	flyEvent:FireClient(admin, enabled)
	notify(admin, enabled and "Flying! Space = up, Q or Ctrl = down. Type /fly again to land." or "Landed.")
end

local function fly(admin)
	setFlying(admin, not flying[admin])
end

local function unfly(admin)
	setFlying(admin, false)
end

-- ==================== GIVE ====================
-- Item keywords for /give (spaces and apostrophes are ignored, so "owner's treadmill" works too)

local GIFTS = {
	ownertreadmill = {
		name = "Owner's Treadmill",
		note = " They can use it in public servers too.",
		give = function(data)
			data.treadmills.owner = true
			data.ownerTreadmillAnywhere = true
		end,
	},
	admintreadmill = {
		name = "Admin Treadmill",
		give = function(data)
			data.treadmills.admin = true
		end,
	},
	hackertreadmill = {
		name = "Hacker's Treadmill",
		give = function(data)
			data.treadmills.hacker = true
		end,
	},
}
for _, sky in ipairs(Catalog.SkyColors) do
	GIFTS[sky.id .. "skin"] = {
		name = sky.name .. " Skin",
		note = " They can wear it from the Color Shop.",
		give = function(data)
			data.ownedSkins[sky.id] = true
		end,
	}
end

local function findGift(words)
	local key = string.gsub(string.lower(table.concat(words, "")), "[^%w]", "")
	return GIFTS[key] or GIFTS[key .. "treadmill"] or GIFTS[key .. "skin"]
end

local function giftList()
	local keys = {}
	for key in pairs(GIFTS) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return table.concat(keys, ", ")
end

local function give(admin, args)
	local target = findPlayerInServer(args[1])
	if not target then
		notify(admin, "Couldn't find \"" .. args[1] .. "\" in this server.")
		return
	end
	local gift = findGift({ table.unpack(args, 2) })
	if not gift then
		notify(admin, "Unknown item. You can give: " .. giftList())
		return
	end
	gift.give(FighterStats.GetPlayerData(target))
	sendStats(target)
	notify(admin, "Gave " .. target.DisplayName .. " the " .. gift.name .. "." .. (gift.note or ""))
	tellTarget(admin, target, "You received the " .. gift.name .. "!")
end

-- ==================== LUCK / INFINITY ====================

local function luck(admin, args)
	local amount = tonumber((string.gsub(args[1], "[xX]$", "")))
	if not amount or amount < 1 or amount ~= amount then
		notify(admin, "Usage: /luck <number> [name], e.g. /luck 64")
		return
	end
	local target = targetOrSelf(admin, args[2])
	if not target then
		return
	end
	amount = math.floor(amount)
	FighterStats.GetPlayerData(target).luck = amount
	sendStats(target)
	notify(admin, target.DisplayName .. "'s luck is now " .. Catalog.FormatNumber(amount) .. ".")
	tellTarget(admin, target, "Your luck is now " .. Catalog.FormatNumber(amount) .. "!")
end

local INFINITE_STATS = {
	strength = function(data)
		FighterStats.TrainStrength(data, math.huge)
	end,
	kick = function(data)
		data.kick = math.huge
	end,
	stamina = function(data)
		data.maxStamina = math.huge
		data.stamina = math.huge
	end,
	money = function(data)
		data.money = math.huge
	end,
}

local function makeInfinity(stat)
	return function(admin, args)
		local target = targetOrSelf(admin, args[1])
		if not target then
			return
		end
		INFINITE_STATS[stat](FighterStats.GetPlayerData(target))
		sendStats(target)
		notify(admin, target.DisplayName .. " now has infinite " .. stat .. ".")
		tellTarget(admin, target, "You now have infinite " .. stat .. "!")
	end
end

-- ==================== COMMAND TABLE ====================
-- minArgs: how many words must follow the command; usage: shown when they're missing

local COMMANDS = {
	ban = { run = ban, minArgs = 1, usage = "/ban <username>" },
	unban = { run = unban, minArgs = 1, usage = "/unban <username>" },
	fly = { run = fly },
	unfly = { run = unfly },
	give = { run = give, minArgs = 2, usage = "/give <name> <item>, e.g. /give Bob owner treadmill" },
	luck = { run = luck, minArgs = 1, usage = "/luck <number> [name], e.g. /luck 64" },
}
for stat in pairs(INFINITE_STATS) do
	local entry = { run = makeInfinity(stat) }
	COMMANDS["infinity" .. stat] = entry
	COMMANDS["inifinity" .. stat] = entry -- common misspelling
end

-- message is the full chat text, e.g. "/give Bob owner treadmill" or "/fly"
local function runCommand(admin, message)
	if not Admins.IsAdmin(admin) then
		return
	end
	local words = string.split(message, " ")
	local args = {}
	for i = 2, #words do
		if words[i] ~= "" then
			table.insert(args, words[i])
		end
	end
	local command = string.match(words[1] or "", "^/(%a+)$")
	local entry = command and COMMANDS[string.lower(command)]
	if not entry then
		return
	end
	if #args < (entry.minArgs or 0) then
		notify(admin, "Usage: " .. entry.usage)
		return
	end
	task.spawn(entry.run, admin, args)
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local commandsFolder = Instance.new("Folder")
	commandsFolder.Name = "AdminCommands"
	commandsFolder.Parent = TextChatService
	for name in pairs(COMMANDS) do
		local command = Instance.new("TextChatCommand")
		command.Name = "Admin_" .. name
		command.PrimaryAlias = "/" .. name
		command.Parent = commandsFolder
		command.Triggered:Connect(function(textSource, message)
			local admin = Players:GetPlayerByUserId(textSource.UserId)
			if admin then
				runCommand(admin, message)
			end
		end)
	end
else
	-- Places still on the legacy chat
	local function listen(player)
		player.Chatted:Connect(function(message)
			local command = string.match(string.lower(message), "^/(%a+)")
			if command and COMMANDS[command] then
				runCommand(player, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in ipairs(Players:GetPlayers()) do
		listen(player)
	end
end

-- Keep session-banned players out (only used when the Roblox ban API isn't available)
Players.PlayerAdded:Connect(function(player)
	if sessionBans[player.UserId] then
		player:Kick(BAN_MESSAGE)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	flying[player] = nil
end)
