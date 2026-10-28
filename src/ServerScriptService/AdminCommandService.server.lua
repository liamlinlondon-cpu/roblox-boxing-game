-- Admin chat commands (only admins can use them, see Admins; ChatCommandFilter keeps them out of chat):
--   /ban <username> ,reason:<reason>  bans the player from the game (all servers) and kicks them if they're here;
--                               they see the reason (optional), e.g. /ban Bob, exploiting
--   /unban <username>           lifts the ban
--   /fly, /unfly                toggles flying (FlyClient moves the character) / lands
--   /give <name> <item>         gives a player in the server an item, e.g. /give Bob owner treadmill;
--                               "/give <name> commands" gives them the commands (owner only)
--   /take <name> commands       removes commands given with /give (owner only)
--   /reset [name]               resets a player (or yourself) to a new player's start
--   /privateserver              teleports the owner to their own private server (owner only)
--   /clone <count>, /clones ... makes copies of the owner and gives them orders (owner only)
--   /every_clone <x> treadmill  every clone runs on that treadmill (owner/hacker/admin/regular/any)
--   /give <name> clones <n>     gives a player clones of themselves they can order with /clones (owner only)
--   /force <name> <order>       the owner orders a player's clones, which then ignore that player
--                               until /force <name> release; /take <name> clones removes them
--   /luck <number> [name]       sets everyone's luck (or one player's with a name), e.g. /luck 64
--   /infinitystrength [name]    infinite strength (also /infinitykick, /infinitystamina, /infinitymoney,
--                               /infinitywins and /infinitybeatthegame; dashes are fine: /infinity-wins)
-- <name> is the name shown above a player's head (display name) or their username; the start of it is
-- enough. Commands with [name] apply to the admin when no name is given. Results are shown to the admin
-- in chat, and a player who receives something gets a private message too.
--
-- Bans use Roblox's ban system (Players:BanAsync), which works in live servers. In Studio, where it
-- isn't available, the player is kicked and banned from this test session only.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local Admins = require(script.Parent:WaitForChild("Admins"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local noticeEvent = Instance.new("RemoteEvent")
noticeEvent.Name = "AdminNotice"
noticeEvent.Parent = eventsFolder

local flyEvent = Instance.new("RemoteEvent")
flyEvent.Name = "AdminFly"
flyEvent.Parent = eventsFolder

local announcementEvent = eventsFolder:WaitForChild("Announcement")

local BAN_MESSAGE = "You have been banned from this game."
local sessionBans = {} -- [userId] = the ban message: fallback when Players:BanAsync isn't available (Studio)

local function notify(player, text)
	noticeEvent:FireClient(player, text)
end

-- Set in the CLONES section; used by /give <name> clones <n> and /take <name> clones
local giveClonesTo, takeClonesFrom

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

-- Finds a player in this server, preferring the name shown above their head (display name):
-- exact display name, then the start of a display name, then the same for usernames
local function findPlayerInServer(query)
	query = string.lower(query)
	local function find(matches)
		for _, player in ipairs(Players:GetPlayers()) do
			if matches(player) then
				return player
			end
		end
		return nil
	end
	local function startsWith(text)
		return string.sub(string.lower(text), 1, #query) == query
	end
	return find(function(player)
		return string.lower(player.DisplayName) == query
	end) or find(function(player)
		return startsWith(player.DisplayName)
	end) or find(function(player)
		return string.lower(player.Name) == query
	end) or find(function(player)
		return startsWith(player.Name)
	end)
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

-- The reason the banned player sees: "You have been banned from this game. Reason: ..."
local function banMessage(reason, admin)
	if not reason or not string.find(reason, "%S") then
		return BAN_MESSAGE
	end
	local ok, clean = pcall(function()
		return TextService:FilterStringAsync(reason, admin.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return BAN_MESSAGE
	end
	return string.sub(BAN_MESSAGE .. " Reason: " .. clean, 1, 400) -- Roblox allows up to 400 letters
end

-- Carries out a ban the admin said YES to
local function doBan(admin, pending)
	local userId, name, reason = pending.userId, pending.name, pending.reason
	local message = banMessage(reason, admin)
	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,
			Duration = -1, -- permanent
			DisplayReason = message,
			PrivateReason = "Banned by " .. admin.Name .. " with /ban" .. (reason ~= "" and (": " .. reason) or ""),
			ExcludeAltAccounts = false,
		})
	end)
	if ok then
		-- BanAsync also removes them from the game
		notify(admin, name .. " has been banned." .. (reason ~= "" and (" Reason: " .. reason) or ""))
		return
	end

	-- Ban API unavailable (e.g. in Studio): kick and keep them out of this server
	sessionBans[userId] = message
	local target = Players:GetPlayerByUserId(userId)
	if target then
		target:Kick(message)
	end
	notify(admin, name .. " was kicked and banned from this server only (Roblox ban failed: " .. tostring(err) .. ").")
end

-- /ban doesn't ban straight away: the admin first sees who and why in a popup (BanConfirmClient) and
-- the ban only happens when they press YES (within a minute)
local CONFIRM_SECONDS = 60
local pendingBans = {} -- [admin] = { userId, name, reason, expires }
local banConfirm = Instance.new("RemoteEvent")
banConfirm.Name = "BanConfirm"
banConfirm.Parent = eventsFolder

local function ban(admin, args)
	-- "/ban bob ,reason:being mean" (also "/ban bob, being mean", "/ban bob ± being mean"...): usernames are
	-- only letters, numbers and _, so the name ends at the first other character; signs, spaces and a
	-- "reason:" label after it are skipped
	local query, rest = string.match(table.concat(args, " "), "^([%w_]+)(.*)$")
	local reason = rest and (string.gsub(rest, "^[^%w]+", "")) or ""
	if string.match(string.lower(reason), "^reason%s*[:=%-]") then
		reason = string.gsub(reason, "^%a+%s*[:=%-]%s*", "")
	end
	if not query then
		notify(admin, "Usage: /ban <username> ,reason:<reason>")
		return
	end
	local userId, name = resolveUser(query)
	if not userId then
		notify(admin, "Couldn't find a player called \"" .. query .. "\".")
		return
	end
	if userId == admin.UserId or Admins.IsAdminUserId(userId) then
		notify(admin, "You can't ban " .. name .. " (admins and the owner can't be banned).")
		return
	end
	pendingBans[admin] = { userId = userId, name = name, reason = reason, expires = os.clock() + CONFIRM_SECONDS }
	banConfirm:FireClient(admin, name, reason)
end

banConfirm.OnServerEvent:Connect(function(admin, answer)
	local pending = pendingBans[admin]
	pendingBans[admin] = nil
	if not pending or not Admins.IsAdmin(admin) then
		return
	end
	if answer ~= true then
		notify(admin, "Didn't ban " .. pending.name .. ".")
	elseif os.clock() > pending.expires then
		notify(admin, "That ban ran out of time. Type /ban again.")
	else
		doBan(admin, pending)
	end
end)

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
	-- The owner's commands, until the player leaves the server. Only the owner can give these.
	commands = {
		name = "owner commands",
		ownerOnly = true,
		note = " They keep them until they leave this server (/take <name> commands removes them).",
		give = function(_, target)
			Admins.Grant(target.UserId)
		end,
	},
	-- The owner's ADMIN panel, for setting their own stats, until they leave this server. Owner only.
	adminpanel = {
		name = "admin panel",
		ownerOnly = true,
		note = " They can set their own stats with it until they leave (/take <name> admin panel removes it).",
		give = function(_, target)
			target:SetAttribute("HasAdminPanel", true)
		end,
	},
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
	return GIFTS[key] or GIFTS[key .. "s"] or GIFTS[key .. "treadmill"] or GIFTS[key .. "skin"]
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
	-- "/give Bob clones 3": clones of Bob that Bob can order (owner only)
	local giftWord = string.lower(args[2] or "")
	if giftWord == "clones" or giftWord == "clone" then
		if not Admins.IsOwner(admin) then
			notify(admin, "Only the owner can give clones.")
			return
		end
		giveClonesTo(admin, target, tonumber(args[3]) or 1)
		return
	end
	local gift = findGift({ table.unpack(args, 2) })
	if not gift then
		notify(admin, "Unknown item. You can give: " .. giftList())
		return
	end
	if gift.ownerOnly and not Admins.IsOwner(admin) then
		notify(admin, "Only the owner can give " .. gift.name .. ".")
		return
	end
	gift.give(FighterStats.GetPlayerData(target), target)
	sendStats(target)
	notify(admin, "Gave " .. target.DisplayName .. " the " .. gift.name .. "." .. (gift.note or ""))
	tellTarget(admin, target, "You received the " .. gift.name .. "!")
end

-- /take <name> commands: removes commands the owner gave with /give
local function take(admin, args)
	if not Admins.IsOwner(admin) then
		notify(admin, "Only the owner can take commands away.")
		return
	end
	local target = findPlayerInServer(args[1])
	if not target then
		notify(admin, "Couldn't find \"" .. args[1] .. "\" in this server.")
		return
	end
	local key = string.gsub(string.lower(table.concat({ table.unpack(args, 2) }, "")), "[^%w]", "")
	if key == "clones" or key == "clone" then
		takeClonesFrom(admin, target)
		return
	end
	if key == "adminpanel" then
		target:SetAttribute("HasAdminPanel", nil)
		notify(admin, target.DisplayName .. " no longer has the admin panel.")
		tellTarget(admin, target, "Your admin panel was taken away.")
		return
	end
	if key ~= "commands" then
		notify(admin, "Usage: /take <name> commands (or clones, or admin panel)")
		return
	end
	if Admins.IsOwner(target) then
		notify(admin, "You can't take the owner's commands.")
		return
	end
	Admins.Revoke(target.UserId)
	if flying[target] then
		flying[target] = nil
		flyEvent:FireClient(target, false)
	end
	notify(admin, target.DisplayName .. " no longer has commands.")
	tellTarget(admin, target, "Your commands were removed.")
end

-- ==================== LUCK / INFINITY ====================

local function luck(admin, args)
	local amount = tonumber((string.gsub(args[1], "[xX]$", "")))
	if not amount or amount < 1 or amount ~= amount then
		notify(admin, "Usage: /luck <number> [name], e.g. /luck 64 (everyone) or /luck 64 Bob")
		return
	end
	amount = math.floor(amount)
	local amountText = Catalog.FormatNumber(amount)

	-- With a name: just that player. Without: everyone in the server.
	if args[2] then
		local target = findPlayerInServer(args[2])
		if not target then
			notify(admin, "Couldn't find \"" .. args[2] .. "\" in this server.")
			return
		end
		FighterStats.GetPlayerData(target).luck = amount
		sendStats(target)
		notify(admin, target.DisplayName .. "'s luck is now " .. amountText .. ".")
		tellTarget(admin, target, "Your luck is now " .. amountText .. "!")
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		FighterStats.GetPlayerData(player).luck = amount
		sendStats(player)
	end
	notify(admin, "Everyone in the server now has " .. amountText .. " luck.")
	-- Everyone sees who gave it, in the banner next to the stat bars (AnnouncementClient)
	announcementEvent:FireAllClients("👑 " .. admin.DisplayName .. " gave everyone " .. amountText .. "x luck!")
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
	wins = function(data)
		data.arenaWins = math.huge
	end,
	beatthegame = function(data)
		data.gameBeats = math.huge
	end,
}
-- How each stat is named in the messages
local INFINITE_STAT_NAMES = { wins = "wins", beatthegame = "beat the game" }

local function makeInfinity(stat)
	return function(admin, args)
		local target = targetOrSelf(admin, args[1])
		if not target then
			return
		end
		INFINITE_STATS[stat](FighterStats.GetPlayerData(target))
		sendStats(target)
		local statName = INFINITE_STAT_NAMES[stat] or stat
		notify(admin, target.DisplayName .. " now has infinite " .. statName .. ".")
		tellTarget(admin, target, "You now have infinite " .. statName .. "!")
	end
end

-- ==================== RESET ====================
-- /reset [name]: everything goes back to a new player's start (stats, money, items, skins)

local function reset(admin, args)
	local target = admin
	if #args > 0 then
		-- Names can't contain spaces, so "Fulton family" also tries "Fultonfamily"
		target = findPlayerInServer(table.concat(args, " ")) or findPlayerInServer(table.concat(args, ""))
		if not target then
			notify(admin, "Couldn't find \"" .. table.concat(args, " ") .. "\" in this server.")
			return
		end
	end
	if target ~= admin and Admins.IsOwner(target) then
		notify(admin, "You can't reset the owner.")
		return
	end
	local data = FighterStats.GetPlayerData(target)
	if data.isInMatch or data.opponent then
		notify(admin, target.DisplayName .. " is in an arena match. Try again when it's over.")
		return
	end

	FighterStats.ResetPlayerData(target)

	-- Take away the Magic Carpet and take off the worn skin
	local character = target.Character
	for _, container in ipairs({ target:FindFirstChildOfClass("Backpack"), character }) do
		local tool = container and container:FindFirstChild("Magic Carpet")
		if tool then
			tool:Destroy()
		end
	end
	if character then
		local carpet = character:FindFirstChild("MagicCarpet")
		if carpet then
			carpet:Destroy()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid:ApplyDescription(Players:GetHumanoidDescriptionFromUserId(target.UserId))
			end)
			-- Rebirths are reset, so is their speed and jump boost (and any admin panel speed/jump)
			target:SetAttribute("AdminWalkSpeed", nil)
			target:SetAttribute("AdminJumpPower", nil)
			humanoid.WalkSpeed = FighterStats.BaseWalkSpeed
			humanoid.UseJumpPower = true
			humanoid.JumpPower = FighterStats.BaseJumpPower
		end
	end

	sendStats(target)
	notify(admin, target.DisplayName .. " has been reset to the start.")
	tellTarget(admin, target, "Your progress was reset to the start.")
end

-- ==================== STAT LOOKUP ====================
-- The owner's search box (AdminLookupClient): "Bob strength" or "/Bob strength" returns that player's
-- strength; just "Bob" returns all their stats. Called with no query it only answers "is this the owner?".

local lookupFunction = Instance.new("RemoteFunction")
lookupFunction.Name = "AdminLookup"
lookupFunction.Parent = eventsFolder

local STAT_WORDS = {
	strength = "strength",
	str = "strength",
	power = "strength",
	punch = "strength",
	kick = "kick",
	money = "money",
	cash = "money",
	stamina = "stamina",
	beatthegame = "gameBeats",
	beatgame = "gameBeats",
	beat = "gameBeats",
	wins = "arenaWins",
	rebirth = "rebirths",
	rebirths = "rebirths",
}

local function statLine(data, stat)
	if stat == "strength" then
		return "Strength: " .. Catalog.FormatNumber(data.strength)
	elseif stat == "kick" then
		return "Kick: " .. Catalog.FormatNumber(data.kick)
	elseif stat == "money" then
		return "Money: " .. Catalog.FormatNumber(data.money)
	elseif stat == "stamina" then
		return "Stamina: " .. Catalog.FormatNumber(data.stamina) .. " / " .. Catalog.FormatNumber(data.maxStamina)
	elseif stat == "gameBeats" then
		local beats = data.gameBeats or 0
		return "Beat the game: " .. Catalog.FormatNumber(beats) .. (beats == 1 and " time" or " times")
	elseif stat == "arenaWins" then
		return "Arena wins: " .. Catalog.FormatNumber(data.arenaWins or 0)
	elseif stat == "rebirths" then
		return "Rebirths: " .. (data.rebirths or 0) .. "/" .. FighterStats.MaxRebirths
	end
	return nil
end

lookupFunction.OnServerInvoke = function(player, query)
	if not Admins.IsOwner(player) then
		return nil
	end
	if query == nil then
		return true
	end
	if type(query) ~= "string" then
		return nil
	end

	local words = {}
	for word in string.gmatch(string.gsub(query, "^%s*/", ""), "%S+") do
		table.insert(words, word)
	end
	if #words == 0 then
		return "Type a name and a stat, e.g. Bob strength"
	end

	local target = findPlayerInServer(words[1])
	if not target then
		return "Couldn't find \"" .. words[1] .. "\" in this server."
	end
	local data = FighterStats.GetPlayerData(target)

	if words[2] then
		local statText = table.concat({ table.unpack(words, 2) }, " ")
		local stat = STAT_WORDS[string.gsub(string.lower(statText), "[^%a]", "")]
		if not stat then
			return "Unknown stat \"" .. statText .. "\". Try strength, kick, money, stamina, beat the game, wins or rebirths."
		end
		return target.DisplayName .. "  ·  " .. statLine(data, stat)
	end

	local lines = { target.DisplayName }
	for _, stat in ipairs({ "strength", "kick", "money", "stamina", "gameBeats", "arenaWins", "rebirths" }) do
		table.insert(lines, statLine(data, stat))
	end
	return table.concat(lines, "\n")
end

-- ==================== PRIVATE SERVER ====================
-- /privateserver (or "/private server"): teleports the owner to their own private server. The server is
-- reserved once and its code saved, so it's the same server every time. Only people teleported in can
-- join it. Teleporting doesn't work in Studio, only in the published game.

local privateServerStore = DataStoreService:GetDataStore("OwnerPrivateServer_v1")

local function privateServer(admin)
	if not Admins.IsOwner(admin) then
		return
	end
	if RunService:IsStudio() then
		notify(admin, "Teleporting to your private server only works in the published game, not in Studio.")
		return
	end

	local key = "owner_" .. admin.UserId
	local loaded, code = pcall(function()
		return privateServerStore:GetAsync(key)
	end)
	if not loaded or type(code) ~= "string" then
		local reserved, newCode = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
		if not reserved then
			notify(admin, "Couldn't create your private server: " .. tostring(newCode))
			return
		end
		code = newCode
		pcall(function()
			privateServerStore:SetAsync(key, code)
		end)
	end

	notify(admin, "Teleporting you to your private server...")
	local teleported, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, code, { admin })
	end)
	if not teleported then
		notify(admin, "Teleport failed: " .. tostring(err))
	end
end

-- ==================== CLONES ====================
-- /clone <count> makes copies of the owner (their avatar's look, up to OWNER_MAX_CLONES), and
-- /clones follow | stay | dance | copy | fly | fight <name> | kill <name> | train <what> | beat the game |
-- stop | remove gives
-- them orders. Every clone has its own order, so groups can do different things at once: a number at
-- the end of an order says how many clones do it ("/clones dance 3", "/clone stop 2"), taking idle clones
-- (following or standing) first. Without a number, every clone gets the order. Owner only.

local OWNER_MAX_CLONES = 100 -- the owner can have this many clones
local PLAYER_MAX_CLONES = 10 -- anyone the owner gives clones to can have this many
local RING_SLOTS = 20 -- clones stand in rings of this many around their controller, each ring wider

-- Where the nth clone stands around its controller: rings of RING_SLOTS, 6 studs out, then 10, 14...
local function ringOffset(index)
	local ring = math.floor((index - 1) / RING_SLOTS)
	local angle = ((index - 1) % RING_SLOTS) / RING_SLOTS * math.pi * 2
	local radius = 6 + ring * 4
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function maxClonesFor(player)
	return Admins.IsOwner(player) and OWNER_MAX_CLONES or PLAYER_MAX_CLONES
end
local CLONE_PUNCH_DAMAGE = 20 -- per second while a fighting clone is next to its target ("kill" is instant)
-- Clones walk at their controller's speed (see the movement loop), so a fast player has fast clones
-- Roblox's own default animations (usable in any game)
local CLONE_ANIMATIONS = {
	walk = { [Enum.HumanoidRigType.R15] = "rbxassetid://507777826", [Enum.HumanoidRigType.R6] = "rbxassetid://180426354" },
	dance = { [Enum.HumanoidRigType.R15] = "rbxassetid://507771019", [Enum.HumanoidRigType.R6] = "rbxassetid://182435998" },
	run = { [Enum.HumanoidRigType.R15] = "rbxassetid://507767714", [Enum.HumanoidRigType.R6] = "rbxassetid://180426354" },
}

local clonesFolder = Instance.new("Folder")
clonesFolder.Name = "OwnerClones"
clonesFolder.Parent = workspace

-- Each clone: { model, humanoid, root, controller, forced, walkTrack, danceTrack, trainTrack, lastHit,
-- order, target, token }. controller is the player who orders it: the owner for their own clones, or a
-- player the owner gave clones to. forced = the owner took over with /force, so the controller is ignored.
-- order: "follow", "stay", "dance", "copy", "fight", "train" or "busy" (beating the game).
-- token goes up with every new order, which stops whatever the clone was still doing for the old one.
local clones = {}

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function loadTrack(humanoid, kind)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = CLONE_ANIMATIONS[kind][humanoid.RigType] or CLONE_ANIMATIONS[kind][Enum.HumanoidRigType.R15]
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	return track
end

-- Drops clones that died or were deleted
local function liveClones()
	for i = #clones, 1, -1 do
		local clone = clones[i]
		if not clone.model.Parent or clone.humanoid.Health <= 0 then
			table.remove(clones, i)
			local model = clone.model
			task.delay(2, function()
				model:Destroy()
			end)
		end
	end
	return clones
end

-- Makes a clone of `owner` (their avatar's look) that `owner` controls
local function spawnClone(owner, index)
	local ownerRoot = rootOf(owner)
	if not ownerRoot then
		return
	end
	local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, owner.UserId)
	if not ok or not model then
		-- No avatar to load (e.g. Studio test players): copy the player's current character instead
		local character = owner.Character
		if character then
			character.Archivable = true
			model = character:Clone()
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("LuaSourceContainer") or child:IsA("Tool") or child:IsA("BillboardGui") then
					child:Destroy()
				end
			end
			local carpet = model:FindFirstChild("MagicCarpet")
			if carpet then
				carpet:Destroy()
			end
		end
		if not model then
			notify(owner, "Couldn't make a clone.")
			return
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return
	end
	root.Anchored = false -- a copied character may have been held still on a station
	model.Name = owner.Name .. "Clone" .. index
	humanoid.DisplayName = owner.DisplayName .. "'s clone"
	model:PivotTo(ownerRoot.CFrame * CFrame.new(ringOffset(index)))
	model.Parent = clonesFolder
	pcall(root.SetNetworkOwner, root, nil) -- the server moves them

	local clone = { model = model, humanoid = humanoid, root = root, controller = owner, lastHit = 0, order = "follow", token = 0 }
	clone.walkTrack = loadTrack(humanoid, "walk")
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 and not clone.danceTrack then
			if not clone.walkTrack.IsPlaying then
				clone.walkTrack:Play(0.2)
			end
		elseif clone.walkTrack.IsPlaying then
			clone.walkTrack:Stop(0.2)
		end
	end)
	table.insert(clones, clone)
end

-- Gives these clones a new order, ending whatever they were doing
local function assignClones(list, order, target)
	for _, clone in ipairs(list) do
		clone.token += 1
		clone.order, clone.target = order, target
		if clone.trainTrack then
			clone.trainTrack:Stop(0.2)
			clone.trainTrack = nil
		end
		if clone.danceTrack then
			clone.danceTrack:Stop(0.2)
			clone.danceTrack = nil
		end
		clone.root.Anchored = order == "fly" -- flying clones are moved by the fly loop below
		if order == "dance" then
			clone.humanoid:MoveTo(clone.root.Position)
			clone.danceTrack = loadTrack(clone.humanoid, "dance")
			clone.danceTrack:Play(0.2)
		elseif order == "stay" then
			clone.humanoid:MoveTo(clone.root.Position)
		end
	end
end

local function isIdle(clone)
	return clone.order == "follow" or clone.order == "stay"
end

-- A controller's clones; forced ones (taken over by the owner) only when `forcing`
local function clonesOf(controller, forcing)
	local list = {}
	for _, clone in ipairs(liveClones()) do
		if clone.controller == controller and (forcing or not clone.forced) then
			table.insert(list, clone)
		end
	end
	return list
end

-- Which of a controller's clones an order goes to: all of them without a count; otherwise that many,
-- idle ones first (or busy ones first, for stopping)
local function pickClones(controller, count, busyFirst, forcing)
	local list = clonesOf(controller, forcing)
	if not count then
		return list
	end
	local first, second = {}, {}
	for _, clone in ipairs(list) do
		local wantedFirst = (busyFirst and not isIdle(clone)) or (not busyFirst and isIdle(clone))
		table.insert(wantedFirst and first or second, clone)
	end
	local picked = {}
	for _, group in ipairs({ first, second }) do
		for _, clone in ipairs(group) do
			if #picked < count then
				table.insert(picked, clone)
			end
		end
	end
	return picked
end

local function removeClones(list)
	for _, clone in ipairs(list) do
		clone.model:Destroy()
	end
	liveClones()
end

local function cloneCountText(count)
	return count .. (count == 1 and " clone" or " clones")
end

-- /clones beat the game: each clone flies high over the wall and the course, dives into the red portal,
-- comes out in the red button room, walks up and presses the button (each press adds
-- CLONE_BEATS_PER_PRESS to the owner's beat the game count). Then they all come back.
local CLONE_FLY_HEIGHT = 90 -- above the walls, buildings and antennas
local CLONE_BEATS_PER_PRESS = 1000 -- each clone's red button press counts this many beats for the owner
local CLONE_FLY_SPEED = 90 -- studs per second

local function flyCloneTo(root, position)
	local distance = (position - root.Position).Magnitude
	local flat = (position - root.Position) * Vector3.new(1, 0, 1)
	local facing = flat.Magnitude > 0.1 and CFrame.lookAt(position, position + flat) or CFrame.new(position)
	local tween = TweenService:Create(root, TweenInfo.new(math.max(0.4, distance / CLONE_FLY_SPEED), Enum.EasingStyle.Linear), { CFrame = facing })
	tween:Play()
	tween.Completed:Wait()
end

local function clonesBeatTheGame(owner, list)
	local portal = CollectionService:GetTagged("BeatGamePortal")[1]
	local arrival = CollectionService:GetTagged("BeatGameArrival")[1]
	local prompt = CollectionService:GetTagged("BeatGameButton")[1]
	local button = prompt and prompt.Parent
	if not portal or not arrival or not button then
		notify(owner, "The beat-the-game course isn't there.")
		return
	end
	assignClones(list, "busy") -- the movement loop leaves them alone
	notify(owner, cloneCountText(#list) .. " flying off to beat the game!")

	local pending = #list
	for i, clone in ipairs(list) do
		task.spawn(function()
			-- pcall: a problem with one clone must never stop the others from coming back
			pcall(function()
				task.wait((i - 1) * 0.4) -- take off one after another
				local root, humanoid = clone.root, clone.humanoid
				if not root.Parent or humanoid.Health <= 0 then
					return
				end
				-- Fly: straight up, across to just before the portal, then dive into it
				local spread = Vector3.new(0, 0, (i - (#list + 1) / 2) * 3)
				root.Anchored = true
				flyCloneTo(root, Vector3.new(root.Position.X, CLONE_FLY_HEIGHT, root.Position.Z))
				flyCloneTo(root, Vector3.new(portal.Position.X - 25, CLONE_FLY_HEIGHT, portal.Position.Z) + spread)
				flyCloneTo(root, portal.Position)

				-- Through the portal into the room, then walk to the button and press it
				clone.model:PivotTo(arrival.CFrame * CFrame.new(((i - 1) % 4 - 1.5) * 2, 0, 0))
				root.Anchored = false
				humanoid:MoveTo(button.Position)
				local deadline = os.clock() + 6
				while root.Parent and (root.Position - button.Position).Magnitude > 4 and os.clock() < deadline do
					task.wait(0.1)
				end
				local color = button.Color
				button.Color = Color3.new(1, 1, 1)
				task.delay(0.2, function()
					button.Color = color
				end)
				-- Each press counts for whoever controls the clone: CLONE_BEATS_PER_PRESS for the owner, 1 for others
				local beats = Admins.IsOwner(owner) and CLONE_BEATS_PER_PRESS or 1
				local ownerData = FighterStats.GetPlayerData(owner)
				ownerData.gameBeats = (ownerData.gameBeats or 0) + beats
				sendStats(owner)
				notify(owner, humanoid.DisplayName .. " " .. i .. " pressed the red button! +"
					.. Catalog.FormatNumber(beats) .. " beat the game for you.")
			end)
			pending -= 1
		end)
	end

	-- Wait for every clone (at most 30 seconds), then always bring them all back
	local giveUpAt = os.clock() + 30
	while pending > 0 and os.clock() < giveUpAt do
		task.wait(0.25)
	end
	notify(owner, "Your clones beat the game!")
	announcementEvent:FireAllClients("👑 " .. owner.DisplayName .. "'s clones beat the game!")
	task.wait(3)

	local ownerRoot = rootOf(owner)
	local back = {}
	for _, clone in ipairs(list) do
		if clone.model.Parent and clone.humanoid.Health > 0 then
			table.insert(back, clone)
		end
	end
	if ownerRoot then
		for j, clone in ipairs(back) do
			clone.root.Anchored = false
			clone.model:PivotTo(ownerRoot.CFrame * CFrame.new(ringOffset(j)))
			clone.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		-- Replace any clone that was lost on the way, so the owner gets the same number back
		for k = 1, math.min(#list - #back, maxClonesFor(owner) - #clonesOf(owner, true)) do
			task.spawn(spawnClone, owner, #clones + k)
		end
	end
	assignClones(back, "follow")
end

-- /clones train strength | kick | both | stamina: the clones fly to the gym nearest the owner and train
-- on its ground-floor punching bags, kicking bags or treadmills until given another order. What they train
-- goes to the owner: +1 strength per punch, +1 kick per kick, and each second on a treadmill that
-- treadmill's own stamina rate (regular +50, hacker +50,000, admin +50,000,000, owner +5 trillion).
local CLONE_HIT_SECONDS = 0.45 -- same pace as a 10 lbs hit
local trainingEvent = eventsFolder:WaitForChild("GymTraining")

local function nearestGymId(position)
	local bestId, bestDistance = nil, math.huge
	for id, info in ipairs(WorldConfig.Gyms.List) do
		if not info.vipShop then
			local distance = (WorldConfig.GetGymCFrame(id).Position - position).Magnitude
			if distance < bestDistance then
				bestId, bestDistance = id, distance
			end
		end
	end
	return bestId
end

-- The nearest gym whose VIP floor the owner has access to this session (from VipAuctionService)
local function nearestVipGymId(owner, position)
	local bestId, bestDistance = nil, math.huge
	for id in ipairs(WorldConfig.Gyms.List) do
		if owner:GetAttribute("VipFloor" .. id) then
			local distance = (WorldConfig.GetGymCFrame(id).Position - position).Magnitude
			if distance < bestDistance then
				bestId, bestDistance = id, distance
			end
		end
	end
	return bestId
end

-- A gym's stations: "punch" / "kick" bags (their pads) or "treadmill" decks; vip picks the VIP floor's
-- bags; treadmillTier ("regular", "hacker", "admin", "owner") picks one kind of treadmill
local function gymStations(gymId, kind, vip, treadmillTier)
	local stations = {}
	if kind == "treadmill" then
		for _, prompt in ipairs(CollectionService:GetTagged("TreadmillStation")) do
			if prompt:GetAttribute("GymId") == gymId and (not treadmillTier or prompt:GetAttribute("Tier") == treadmillTier)
				and (prompt:GetAttribute("Vip") == true) == vip then
				table.insert(stations, prompt.Parent)
			end
		end
	else
		for _, prompt in ipairs(CollectionService:GetTagged("GymStation")) do
			if prompt:GetAttribute("GymId") == gymId and prompt:GetAttribute("Mode") == kind and (prompt:GetAttribute("Vip") == true) == vip then
				table.insert(stations, prompt.Parent)
			end
		end
	end
	return stations
end

local function trainClone(owner, clone, kind, station, slot, gain)
	local token = clone.token
	local function stillTraining()
		return clone.token == token and clone.model.Parent and owner.Parent
	end
	local root, humanoid = clone.root, clone.humanoid
	root.Anchored = true

	-- Where to stand: facing the bag on its pad, or on the treadmill belt
	local bag, stand
	if kind == "treadmill" then
		stand = station.CFrame * CFrame.new(0, 3.6, -1.5) * CFrame.Angles(0, math.pi, 0)
	else
		bag = station.Parent:FindFirstChild(station.Name .. "Bag")
		if not bag then
			return
		end
		local toBag = (bag.Position - station.Position) * Vector3.new(1, 0, 1)
		local standPosition = station.Position + toBag.Unit * 1.5 + Vector3.new(0, 3.2, 0)
		stand = CFrame.lookAt(standPosition, Vector3.new(bag.Position.X, standPosition.Y, bag.Position.Z))
	end
	-- Clones sharing a station: side by side at a bag; rows of three along the belt on a treadmill
	if kind == "treadmill" then
		local across = (slot - 1) % 3 - 1
		local row = math.floor((slot - 1) / 3)
		local along = (row % 2 == 1 and 1 or -1) * math.ceil(row / 2) * 2.4
		stand = stand * CFrame.new(across * 1.4, 0, along)
	else
		stand = stand * CFrame.new((slot - 1) * 2.5, 0, 0)
	end

	-- Fly over: up, across, down onto the spot
	flyCloneTo(root, Vector3.new(root.Position.X, 60, root.Position.Z))
	flyCloneTo(root, Vector3.new(stand.Position.X, 60, stand.Position.Z))
	flyCloneTo(root, stand.Position)
	if not stillTraining() then
		return
	end
	root.CFrame = stand

	local data = FighterStats.GetPlayerData(owner)
	if kind == "treadmill" then
		-- The stamina per second of the treadmill this clone is on (the tier is set on its prompt)
		local prompt = station:FindFirstChildOfClass("ProximityPrompt")
		local tier = FighterStats.TreadmillTiers[prompt and prompt:GetAttribute("Tier") or "regular"] or FighterStats.TreadmillTiers.regular
		clone.trainTrack = loadTrack(humanoid, "run")
		clone.trainTrack:Play(0.2)
		clone.trainTrack:AdjustSpeed(1.6)
		while stillTraining() do
			task.wait(1)
			if stillTraining() then
				data.maxStamina += tier.gain * gain -- gain is 2 on the VIP floor
				data.stamina = data.maxStamina
			end
		end
	else
		local side = "Right"
		while stillTraining() do
			task.wait(CLONE_HIT_SECONDS)
			if not stillTraining() then
				break
			end
			side = side == "Right" and "Left" or "Right"
			trainingEvent:FireAllClients("punch", clone.model, bag, side, 10, kind)
			if kind == "kick" then
				FighterStats.TrainKick(data, gain)
			else
				FighterStats.TrainStrength(data, gain)
			end
		end
	end
end

-- Refreshes a controller's stats once a second while any of their clones trains
local statsRefreshRunning = {} -- [player] = true
local function refreshStatsWhileTraining(owner)
	if statsRefreshRunning[owner] then
		return
	end
	statsRefreshRunning[owner] = true
	task.spawn(function()
		while owner.Parent do
			task.wait(1)
			local anyTraining = false
			for _, clone in ipairs(clonesOf(owner, true)) do
				if clone.order == "train" or clone.order == "duel" then
					anyTraining = true
				end
			end
			if not anyTraining then
				break
			end
			sendStats(owner)
		end
		statsRefreshRunning[owner] = nil
	end)
end

-- /clones train wins: the clones pair up and box each other 1-on-1 in a row in front of their controller.
-- Every finished fight adds arena wins for the controller, whichever clone won: DUEL_WINS_FOR_OWNER for
-- the owner, 1 for anyone else. Needs an even number.
local DUEL_HIT_SECONDS = 0.5
local DUEL_WINS_FOR_OWNER = 1000

local function clonesDuel(controller, list, admin)
	if #list < 2 or #list % 2 == 1 then
		notify(admin, "Clone fights need an even number of clones (2, 4, 6...), not " .. #list .. ".")
		return
	end
	local controllerRoot = rootOf(controller)
	if not controllerRoot then
		return
	end
	assignClones(list, "duel")
	local base = controllerRoot.CFrame
	local pairCount = #list / 2
	for pair = 1, pairCount do
		local a, b = list[pair * 2 - 1], list[pair * 2]
		-- Each pair faces off 4 studs apart, the pairs side by side 6 studs apart
		local center = base * CFrame.new((pair - (pairCount + 1) / 2) * 6, 0, -8)
		local aPosition = (center * CFrame.new(0, 0, -2)).Position
		local bPosition = (center * CFrame.new(0, 0, 2)).Position
		a.model:PivotTo(CFrame.lookAt(aPosition, bPosition))
		b.model:PivotTo(CFrame.lookAt(bPosition, aPosition))
		a.root.Anchored = true
		b.root.Anchored = true
		local tokenA, tokenB = a.token, b.token

		task.spawn(function()
			local function fighting()
				return a.token == tokenA and b.token == tokenB and a.model.Parent and b.model.Parent and controller.Parent
			end
			while fighting() do
				local health = { [a] = 100, [b] = 100 }
				local attacker, defender = a, b
				while fighting() and health[a] > 0 and health[b] > 0 do
					task.wait(DUEL_HIT_SECONDS)
					if not fighting() then
						break
					end
					local move = math.random() < 0.3 and "kick" or "punch"
					trainingEvent:FireAllClients("punch", attacker.model, nil, math.random() < 0.5 and "Right" or "Left", 10, move)
					health[defender] -= math.random(10, 25)
					attacker, defender = defender, attacker
				end
				if not fighting() then
					break
				end
				-- Somebody won: the wins go to the controller either way
				local data = FighterStats.GetPlayerData(controller)
				data.arenaWins = (data.arenaWins or 0) + (Admins.IsOwner(controller) and DUEL_WINS_FOR_OWNER or 1)
				task.wait(1.5)
			end
		end)
	end
	notify(admin, #list .. " clones fighting in " .. pairCount .. (pairCount == 1 and " pair" or " pairs")
		.. ". Every fight is +" .. Catalog.FormatNumber(Admins.IsOwner(controller) and DUEL_WINS_FOR_OWNER or 1)
		.. " wins for " .. (controller == admin and "you" or controller.DisplayName) .. "!")
	refreshStatsWhileTraining(controller)
end

local function clonesTrain(owner, list, what, vip, treadmillTier)
	local ownerRoot = rootOf(owner)
	if not ownerRoot then
		return
	end
	local gymId
	if vip then
		-- The owner uses any VIP floor for free; anyone else needs this session's VIP access
		gymId = Admins.IsOwner(owner) and nearestGymId(ownerRoot.Position) or nearestVipGymId(owner, ownerRoot.Position)
		if not gymId then
			notify(owner, "You need VIP floor access first: win a VIP bid at a gym's VIP board.")
			return
		end
	else
		gymId = nearestGymId(ownerRoot.Position)
	end
	local gain = vip and WorldConfig.Training.VipMultiplier or 1
	assignClones(list, "train")

	local used = {} -- [station] = how many clones are on it
	for i, clone in ipairs(list) do
		local kind
		if what == "both" then
			kind = i % 2 == 1 and "punch" or "kick"
		elseif what == "stamina" then
			kind = "treadmill"
		else
			kind = what == "kick" and "kick" or "punch"
		end
		local stations = gymStations(gymId, kind, vip == true, treadmillTier)
		local station = stations[(i - 1) % math.max(#stations, 1) + 1]
		if station then
			used[station] = (used[station] or 0) + 1
			local slot = used[station]
			task.spawn(function()
				pcall(trainClone, owner, clone, kind, station, slot, gain)
			end)
		end
	end
	local where = treadmillTier and (" on the " .. FighterStats.TreadmillTiers[treadmillTier].name) or ""
	notify(owner, cloneCountText(#list) .. " training " .. what .. where .. " at " .. WorldConfig.Gyms.List[gymId].name
		.. (vip and "'s VIP floor (2x)" or "") .. ". Everything they train goes to you!")
	refreshStatsWhileTraining(owner)
end

-- Which treadmill words name: owner / hacker / admin / regular (also "original", "normal");
-- nil for "any" or nothing, which spreads the clones over every treadmill
local TREADMILL_WORDS = {
	owner = "owner", owners = "owner",
	hacker = "hacker", hackers = "hacker",
	admin = "admin", admins = "admin",
	regular = "regular", original = "regular", normal = "regular",
}
local function treadmillTierIn(words)
	for _, word in ipairs(words) do
		local tier = TREADMILL_WORDS[string.gsub(string.lower(word), "[^%a]", "")]
		if tier then
			return tier
		end
	end
	return nil
end

local function cloneCommand(admin, args)
	if not Admins.IsOwner(admin) then
		return
	end
	-- "/clone stop [count]": stops that many clones (all without a number); they stand still
	if string.lower(args[1] or "") == "stop" then
		local count = tonumber(args[2])
		local list = pickClones(admin, count and math.max(0, math.floor(count)) or nil, true, true)
		assignClones(list, "stay")
		notify(admin, count and ("Stopped " .. cloneCountText(#list) .. ".") or "All clones stopped.")
		return
	end
	-- A number is required: "/clone" on its own does nothing
	local requested = tonumber(args[1])
	if not requested or requested ~= requested then
		notify(admin, "Usage: /clone <number>, e.g. /clone 5 (or /clone stop [number])")
		return
	end
	local max = maxClonesFor(admin)
	local count = math.clamp(math.floor(requested), 1, max)
	count = math.min(count, max - #clonesOf(admin, true))
	if count <= 0 then
		notify(admin, "You already have " .. max .. " clones (the most). Use /clones remove to clear them.")
		return
	end
	for i = 1, count do
		task.spawn(spawnClone, admin, #clones + i)
	end
	notify(admin, "Made " .. cloneCountText(count) .. ". Give orders with /clones, and add a number to order just some of them.")
end

-- Orders a controller's clones. Normally the commander is the controller ("/clones dance" from Bob orders
-- Bob's clones); with `forcing` the owner orders someone else's clones (/force), and those clones then
-- ignore their controller until the owner releases them.
local function clonesCommand(admin, args, controller, forcing)
	controller = controller or admin
	if not (Admins.IsOwner(admin) or (controller == admin and #clonesOf(admin, true) > 0)) then
		return
	end
	-- A number at the end says how many clones get the order
	local count = nil
	if #args > 1 and tonumber(args[#args]) then
		count = math.max(0, math.floor(tonumber(args[#args])))
		args = { table.unpack(args, 1, #args - 1) }
	end
	local available = clonesOf(controller, forcing)
	if #available == 0 then
		if #clonesOf(controller, true) > 0 then
			notify(admin, "The owner has taken over your clones, so they only listen to the owner right now.")
		elseif controller == admin then
			notify(admin, Admins.IsOwner(admin) and "You don't have any clones. Make some with /clone <number>." or "You don't have any clones.")
		else
			notify(admin, controller.DisplayName .. " doesn't have any clones.")
		end
		return
	end
	local whose = controller == admin and "" or (controller.DisplayName .. "'s ")
	-- Forced clones listen only to the owner from now on
	local function take(list)
		if forcing then
			for _, clone in ipairs(list) do
				clone.forced = true
			end
		end
		return list
	end

	local order = string.lower(args[1] or "")
	local wholeOrder = string.gsub(string.lower(table.concat(args, "")), "[^%a]", "")
	if wholeOrder == "beatthegame" or order == "beat" then
		task.spawn(clonesBeatTheGame, controller, take(pickClones(controller, count, false, forcing)))
	elseif order == "train" then
		local what = string.lower(args[2] or "")
		if what == "power" or what == "punch" then
			what = "strength"
		end
		-- "/clones train wins": pairs of clones box each other for arena wins
		if what == "wins" or what == "win" then
			clonesDuel(controller, take(pickClones(controller, count, false, forcing)), admin)
			return
		end
		if what ~= "strength" and what ~= "kick" and what ~= "both" and what ~= "stamina" then
			notify(admin, "Usage: /clones train strength | kick | both | stamina | wins, add \"vip floor\" for the VIP floor")
			return
		end
		-- "/clones train strength vip floor": the VIP floor's bags (2x)
		local vip = string.find(string.lower(table.concat(args, " ", 3)), "vip") ~= nil
		-- "/clones train stamina hacker": just that kind of treadmill
		local treadmillTier = what == "stamina" and treadmillTierIn({ table.unpack(args, 3) }) or nil
		task.spawn(clonesTrain, controller, take(pickClones(controller, count, false, forcing)), what, vip, treadmillTier)
	elseif order == "remove" then
		local list = pickClones(controller, count, false, forcing)
		removeClones(list)
		notify(admin, "Removed " .. #list .. " of " .. whose .. "clones.")
	elseif order == "stop" then
		local list = take(pickClones(controller, count, true, forcing))
		assignClones(list, "stay")
		notify(admin, "Stopped " .. #list .. " of " .. whose .. "clones.")
	elseif order == "follow" or order == "stay" or order == "dance" or order == "copy" or order == "fly" then
		local list = take(pickClones(controller, count, false, forcing))
		assignClones(list, order)
		notify(admin, #list .. " of " .. whose .. "clones: " .. order .. ".")
	elseif order == "fight" or order == "kill" then
		local target = args[2] and findPlayerInServer(args[2])
		if not target then
			notify(admin, "Usage: /clones " .. order .. " <name> (a player in this server)")
			return
		end
		if target == controller then
			notify(admin, "Clones won't " .. order .. " the person they belong to.")
			return
		end
		if Admins.IsOwner(target) and not Admins.IsOwner(admin) then
			notify(admin, "Clones won't " .. order .. " the owner.")
			return
		end
		local list = take(pickClones(controller, count, false, forcing))
		assignClones(list, order, target)
		notify(admin, #list .. " of " .. whose .. "clones" .. (order == "kill" and " going to kill " or " going after ") .. target.DisplayName .. "!")
	else
		notify(admin, "Usage: /clones follow | stay | dance | copy | fly | fight <name> | kill <name> | train <strength/kick/both/stamina/wins> | beat the game | stop | remove, plus an optional number")
	end
end

-- /give <name> clones <n>: the owner makes clones of that player, which the player can order with /clones
function giveClonesTo(admin, target, count)
	local max = maxClonesFor(target)
	count = math.clamp(math.floor(count), 1, max)
	count = math.min(count, max - #clonesOf(target, true))
	if count <= 0 then
		notify(admin, target.DisplayName .. " already has " .. max .. " clones (the most).")
		return
	end
	for i = 1, count do
		task.spawn(spawnClone, target, #clones + i)
	end
	notify(admin, "Gave " .. target.DisplayName .. " " .. cloneCountText(count) .. ". Take over with /force " .. target.DisplayName .. " <order>.")
	if target ~= admin then
		notify(target, "You got " .. cloneCountText(count) .. "! Order them with /clones follow, dance, train strength, fight <name> and more.")
	end
end

-- /take <name> clones: the owner removes that player's clones
function takeClonesFrom(admin, target)
	local list = clonesOf(target, true)
	removeClones(list)
	notify(admin, "Removed " .. target.DisplayName .. "'s " .. cloneCountText(#list) .. ".")
	if target ~= admin and #list > 0 then
		notify(target, "Your clones were taken away.")
	end
end

-- /force <name> <order> [number]: the owner orders that player's clones, which then ignore the player
-- until "/force <name> release"
local function forceCommand(admin, args)
	if not Admins.IsOwner(admin) then
		return
	end
	local target = findPlayerInServer(args[1])
	if not target then
		notify(admin, "Couldn't find \"" .. args[1] .. "\" in this server.")
		return
	end
	local rest = { table.unpack(args, 2) }
	if string.lower(rest[1] or "") == "release" then
		local list = clonesOf(target, true)
		for _, clone in ipairs(list) do
			clone.forced = nil
		end
		notify(admin, target.DisplayName .. "'s clones listen to " .. target.DisplayName .. " again.")
		return
	end
	clonesCommand(admin, rest, target, true)
end

-- /every_clone <treadmill> treadmill: every clone runs on that kind of treadmill ("any" spreads them over
-- all of them). Anything else ("/every_clone dance") works like /clones for every clone.
local function everyCloneCommand(admin, args)
	if not Admins.IsOwner(admin) then
		return
	end
	local words = string.lower(table.concat(args, " "))
	local tier = treadmillTierIn(args)
	if tier or string.find(words, "treadmill") then
		local list = pickClones(admin, nil, false, true)
		if #list == 0 then
			notify(admin, "You don't have any clones. Make some with /clone <number>.")
			return
		end
		task.spawn(clonesTrain, admin, list, "stamina", false, tier)
		return
	end
	clonesCommand(admin, args)
end

-- /clones fly: the clones fly after their controller in a straight line, single file behind them and a
-- little above, facing the same way and following them anywhere (also up in the air). Each clone glides
-- toward its place every frame, so the line trails smoothly behind.
local FLY_SPACING = 5 -- studs between clones in the line
local FLY_HEIGHT = 2 -- above the controller
local FLY_SMOOTHING = 0.2 -- how quickly each clone catches up to its place (0-1 per frame)

RunService.Heartbeat:Connect(function()
	local flyers = {} -- [controller] = list
	for _, clone in ipairs(clones) do
		if clone.order == "fly" and clone.model.Parent then
			flyers[clone.controller] = flyers[clone.controller] or {}
			table.insert(flyers[clone.controller], clone)
		end
	end
	for controller, list in pairs(flyers) do
		local controllerRoot = rootOf(controller)
		if controllerRoot then
			-- Flat facing, so the line stays level even when the controller looks up or down
			local look = controllerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
			local facing = look.Magnitude > 0.01 and CFrame.lookAt(controllerRoot.Position, controllerRoot.Position + look) or controllerRoot.CFrame
			for i, clone in ipairs(list) do
				local place = facing * CFrame.new(0, FLY_HEIGHT, i * FLY_SPACING) -- +Z is behind
				clone.root.CFrame = clone.root.CFrame:Lerp(place, FLY_SMOOTHING)
			end
		end
	end
end)

-- Moves the clones a few times a second, each by its own order, around whoever controls it
local lastWalkSpeed = {} -- [controller] = their last walking speed while able to move

task.spawn(function()
	while true do
		task.wait(0.2)
		local list = liveClones()
		local now = os.clock()

		-- Group the clones by controller
		local groups = {} -- [controller] = { followers, copiers }
		for _, clone in ipairs(list) do
			local group = groups[clone.controller]
			if not group then
				group = { followers = {}, copiers = {} }
				groups[clone.controller] = group
			end
			if clone.order == "follow" then
				table.insert(group.followers, clone)
			elseif clone.order == "copy" then
				table.insert(group.copiers, clone)
			end
		end

		for controller, group in pairs(groups) do
			local controllerRoot = rootOf(controller)
			local controllerHumanoid = controllerRoot and controllerRoot.Parent:FindFirstChildOfClass("Humanoid")
			-- Clones walk at their controller's speed (kept while the controller is held still at 0)
			if controllerHumanoid and controllerHumanoid.WalkSpeed > 0 then
				lastWalkSpeed[controller] = controllerHumanoid.WalkSpeed
			end
			local speed = lastWalkSpeed[controller] or 16
			for _, clone in ipairs(list) do
				if clone.controller == controller and clone.humanoid.WalkSpeed ~= speed then
					clone.humanoid.WalkSpeed = speed
				end
			end

			if controllerRoot then
				for i, clone in ipairs(group.followers) do
					local spot = controllerRoot.Position + ringOffset(i)
					if (clone.root.Position - spot).Magnitude > 3 then
						clone.humanoid:MoveTo(spot)
					end
				end
				local state = controllerHumanoid and controllerHumanoid:GetState()
				local jumping = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
				for i, clone in ipairs(group.copiers) do
					-- Rows of five behind the controller, facing the same way, jumping when they jump
					local column = (i - 1) % 5 - 2
					local row = math.floor((i - 1) / 5) + 1
					clone.humanoid:MoveTo((controllerRoot.CFrame * CFrame.new(column * 4, 0, row * 5)).Position)
					if jumping then
						clone.humanoid.Jump = true
					end
				end
			end
		end

		for _, clone in ipairs(list) do
			if clone.order == "fight" or clone.order == "kill" then
				local targetRoot = rootOf(clone.target)
				local targetHumanoid = targetRoot and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
				if not targetHumanoid or targetHumanoid.Health <= 0 then
					assignClones({ clone }, "follow") -- target gone: back to the controller
				else
					clone.humanoid:MoveTo(targetRoot.Position)
					if (clone.root.Position - targetRoot.Position).Magnitude < 5 and now - clone.lastHit >= 1 then
						clone.lastHit = now
						-- Health is changed directly (not TakeDamage) so the spawn shield doesn't block it
						if clone.order == "kill" then
							targetHumanoid.Health = 0
						else
							targetHumanoid.Health -= CLONE_PUNCH_DAMAGE
						end
					end
				end
			end
		end
	end
end)

-- ==================== ADMIN PANEL ====================
-- The ADMIN panel (AdminPanelClient) sets the user's own stats to any number up to 1 nonillion (10^30).
-- The owner has it; the owner can give it with /give <name> admin panel (HasAdminPanel attribute, until
-- they leave). Called with no stat it only answers "may this player use the panel?". Speed and jump are kept as player
-- attributes so respawning (RebirthService) puts them back.

local ADMIN_PANEL_MAX = 1e30 -- 1 nonillion
-- Speed and jump move the character, and Roblox's physics freezes or flings characters far beyond this,
-- so those two are capped here (1,000 speed covers the whole map in under a second)
local ADMIN_PANEL_MOVE_MAX = FighterStats.MaxMoveValue

local adminPanelFunction = Instance.new("RemoteFunction")
adminPanelFunction.Name = "AdminPanel"
adminPanelFunction.Parent = eventsFolder

local function setHumanoid(player, property, value)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if property == "JumpPower" then
			humanoid.UseJumpPower = true
		end
		humanoid[property] = value
	end
end

-- stat -> how to set it, and the name shown back; moves = capped at ADMIN_PANEL_MOVE_MAX
local ADMIN_PANEL_STATS = {
	speed = { name = "Speed", moves = true, set = function(player, _, value)
		player:SetAttribute("AdminWalkSpeed", value)
		setHumanoid(player, "WalkSpeed", value)
	end },
	jump = { name = "Jump", moves = true, set = function(player, _, value)
		player:SetAttribute("AdminJumpPower", value)
		setHumanoid(player, "JumpPower", value)
	end },
	strength = { name = "Strength", set = function(_, data, value)
		data.strength = value
		data.bodyStage = FighterStats.GetStageFromStrength(value)
	end },
	kick = { name = "Kick", set = function(_, data, value)
		data.kick = value
	end },
	stamina = { name = "Stamina", set = function(_, data, value)
		data.maxStamina = value
		data.stamina = value
	end },
	rebirths = { name = "Rebirths", set = function(player, data, value)
		data.rebirths = math.clamp(math.floor(value), 0, FighterStats.MaxRebirths)
		-- The rebirth speed and jump boost follows, unless speed/jump were set here directly
		local boost = FighterStats.RebirthSpeedBoost(data.rebirths)
		if not player:GetAttribute("AdminWalkSpeed") then
			setHumanoid(player, "WalkSpeed", math.min(FighterStats.BaseWalkSpeed + boost, FighterStats.MaxMoveValue))
		end
		if not player:GetAttribute("AdminJumpPower") then
			setHumanoid(player, "JumpPower", math.min(FighterStats.BaseJumpPower + boost, FighterStats.MaxMoveValue))
		end
	end },
	money = { name = "Money", set = function(_, data, value)
		data.money = value
	end },
	luck = { name = "Luck", set = function(_, data, value)
		data.luck = math.max(1, math.floor(value))
	end },
	wins = { name = "Wins", set = function(_, data, value)
		data.arenaWins = math.floor(value)
	end },
	beatthegame = { name = "Beat the game", set = function(_, data, value)
		data.gameBeats = math.floor(value)
	end },
}

-- The owner, and anyone the owner gave the panel to with /give <name> admin panel
local function hasAdminPanel(player)
	return Admins.IsOwner(player) or player:GetAttribute("HasAdminPanel") == true
end

adminPanelFunction.OnServerInvoke = function(player, stat, value)
	if not hasAdminPanel(player) then
		return nil
	end
	if stat == nil then
		return true
	end
	local entry = type(stat) == "string" and ADMIN_PANEL_STATS[stat]
	if not entry or type(value) ~= "number" or value ~= value or value < 0 then
		return "Type a number of 0 or more."
	end
	local limit = entry.moves and ADMIN_PANEL_MOVE_MAX or ADMIN_PANEL_MAX
	local capped = value > limit
	value = math.min(value, limit)
	local data = FighterStats.GetPlayerData(player)
	entry.set(player, data, value)
	sendStats(player)
	if capped and entry.moves then
		return entry.name .. " set to " .. Catalog.FormatNumber(value) .. " (the fastest Roblox can handle)."
	end
	return entry.name .. " set to " .. Catalog.FormatNumber(value) .. "."
end

-- ==================== COMMAND TABLE ====================
-- minArgs: how many words must follow the command; usage: shown when they're missing

local COMMANDS = {
	ban = { run = ban, minArgs = 1, usage = "/ban <username> ,reason:<reason>" },
	unban = { run = unban, minArgs = 1, usage = "/unban <username>" },
	fly = { run = fly },
	unfly = { run = unfly },
	give = { run = give, minArgs = 2, usage = "/give <name> <item>, e.g. /give Bob owner treadmill" },
	take = { run = take, minArgs = 2, usage = "/take <name> commands" },
	reset = { run = reset },
	privateserver = { run = privateServer },
	clone = { run = cloneCommand, minArgs = 1, usage = "/clone <number>, e.g. /clone 5 (or /clone stop [number])" },
	clones = { run = clonesCommand, forCloneHolders = true }, -- also for players the owner gave clones to
	force = { run = forceCommand, minArgs = 2, usage = "/force <name> <order> [number], or /force <name> release" },
	everyclone = { run = everyCloneCommand, minArgs = 1, usage = "/every_clone owner treadmill (or hacker / admin / regular / any)" },
	private = { run = privateServer }, -- "/private server"
	luck = { run = luck, minArgs = 1, usage = "/luck <number> [name], e.g. /luck 64 (everyone) or /luck 64 Bob" },
}
for stat in pairs(INFINITE_STATS) do
	local entry = { run = makeInfinity(stat) }
	COMMANDS["infinity" .. stat] = entry
	COMMANDS["inifinity" .. stat] = entry -- common misspelling
end
COMMANDS.infinitybeatthegames = COMMANDS.infinitybeatthegame -- "/infinity-beat-the-games"

-- Commands can also be typed with dashes, e.g. "/infinity-wins": dashes are ignored
local DASHED_ALIASES = {
	infinitywins = "/infinity-wins",
	infinitybeatthegame = "/infinity-beat-the-game",
	infinitybeatthegames = "/infinity-beat-the-games",
	everyclone = "/every_clone",
}

-- message is the full chat text, e.g. "/give Bob owner treadmill" or "/fly"
local function runCommand(admin, message)
	local firstWord = string.lower(string.match(message, "^/([%a%-_]+)") or "")
	local holderCommand = COMMANDS[string.gsub(firstWord, "[%-_]", "")]
	local isCloneHolder = holderCommand and holderCommand.forCloneHolders and #clonesOf(admin, true) > 0
	if not Admins.IsAdmin(admin) and not isCloneHolder then
		return
	end
	local words = string.split(message, " ")
	local args = {}
	for i = 2, #words do
		if words[i] ~= "" then
			table.insert(args, words[i])
		end
	end
	local command = string.match(words[1] or "", "^/([%a%-_]+)$")
	local entry = command and COMMANDS[string.gsub(string.lower(command), "[%-_]", "")]
	if not entry then
		return
	end
	if #args < (entry.minArgs or 0) then
		notify(admin, "Usage: " .. entry.usage)
		return
	end
	task.spawn(entry.run, admin, args)
end

-- The VIP ADMIN panel's COMMANDS tab: the owner types (or picks) a command and presses RUN, and it runs
-- exactly as if typed in chat. Commands that live in other scripts (sky events, /disco, /nuke) are
-- passed on through the ServerStorage "OtherChatCommand" event, which those scripts listen to.
local otherChatCommand = Instance.new("BindableEvent")
otherChatCommand.Name = "OtherChatCommand"
otherChatCommand.Parent = game:GetService("ServerStorage")

local adminRunCommand = Instance.new("RemoteFunction")
adminRunCommand.Name = "AdminRunCommand"
adminRunCommand.Parent = eventsFolder
adminRunCommand.OnServerInvoke = function(player, message)
	if not Admins.IsOwner(player) or type(message) ~= "string" then
		return nil
	end
	message = string.gsub(string.sub(message, 1, 300), "^%s+", "")
	if string.sub(message, 1, 1) ~= "/" then
		message = "/" .. message
	end
	local word = string.lower(string.match(message, "^/([%a%-_]+)") or "")
	if word == "" then
		return "Type a command, like /fly."
	end
	if COMMANDS[(string.gsub(word, "[%-_]", ""))] then
		runCommand(player, message)
	else
		otherChatCommand:Fire(player, (string.gsub(word, "[%-_]", "")), message)
	end
	return "Ran " .. message
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local commandsFolder = Instance.new("Folder")
	commandsFolder.Name = "AdminCommands"
	commandsFolder.Parent = TextChatService
	for name in pairs(COMMANDS) do
		local command = Instance.new("TextChatCommand")
		command.Name = "Admin_" .. name
		command.PrimaryAlias = "/" .. name
		if DASHED_ALIASES[name] then
			command.SecondaryAlias = DASHED_ALIASES[name]
		end
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
			local command = string.match(string.lower(message), "^/([%a%-_]+)")
			if command and COMMANDS[string.gsub(command, "[%-_]", "")] then
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
		player:Kick(sessionBans[player.UserId])
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pendingBans[player] = nil
	flying[player] = nil
	removeClones(clonesOf(player, true)) -- their clones go with them
	Admins.Revoke(player.UserId) -- commands given with /give last until the player leaves
end)

-- ==================== OWNER TAG ====================
-- A gold "👑 OWNER" tag floats above the owner's head so everyone can see who the owner is. It's on the
-- HumanoidRootPart so it stays when the owner's look changes (skins, /reset).

local function addOwnerTag(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild("OwnerTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "OwnerTag"
	tag.Size = UDim2.new(0, 180, 0, 44)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.MaxDistance = 200
	tag.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "👑 OWNER"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeColor3 = Color3.fromRGB(60, 40, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = tag
end

local function watchOwner(player)
	if not Admins.IsOwner(player) then
		return
	end
	player.CharacterAdded:Connect(addOwnerTag)
	if player.Character then
		task.spawn(addOwnerTag, player.Character)
	end
end

Players.PlayerAdded:Connect(watchOwner)
for _, player in ipairs(Players:GetPlayers()) do
	watchOwner(player)
end
