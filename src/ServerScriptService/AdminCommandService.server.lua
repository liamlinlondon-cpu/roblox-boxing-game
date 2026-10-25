-- Admin chat commands (only admins can use them, see Admins; ChatCommandFilter keeps them out of chat):
--   /ban <username>             bans the player from the game (all servers) and kicks them if they're here
--   /unban <username>           lifts the ban
--   /fly, /unfly                toggles flying (FlyClient moves the character) / lands
--   /give <name> <item>         gives a player in the server an item, e.g. /give Bob owner treadmill;
--                               "/give <name> commands" gives them the commands (owner only)
--   /take <name> commands       removes commands given with /give (owner only)
--   /reset [name]               resets a player (or yourself) to a new player's start
--   /privateserver              teleports the owner to their own private server (owner only)
--   /clone <count>, /clones ... makes copies of the owner and gives them orders (owner only)
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
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

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

local announcementEvent = eventsFolder:WaitForChild("Announcement")

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
		arenaWins = data.arenaWins,
		gameBeats = data.gameBeats,
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
	-- The owner's commands, until the player leaves the server. Only the owner can give these.
	commands = {
		name = "owner commands",
		ownerOnly = true,
		note = " They keep them until they leave this server (/take <name> commands removes them).",
		give = function(_, target)
			Admins.Grant(target.UserId)
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
	if key ~= "commands" then
		notify(admin, "Usage: /take <name> commands")
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
			return "Unknown stat \"" .. statText .. "\". Try strength, kick, money, stamina, beat the game or wins."
		end
		return target.DisplayName .. "  ·  " .. statLine(data, stat)
	end

	local lines = { target.DisplayName }
	for _, stat in ipairs({ "strength", "kick", "money", "stamina", "gameBeats", "arenaWins" }) do
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
-- /clone <count> makes copies of the owner (their avatar's look, up to MAX_CLONES), and
-- /clones follow | stay | dance | copy | fight <name> | beat the game | remove tells them what to do.
-- Owner only.

local MAX_CLONES = 10
local CLONE_PUNCH_DAMAGE = 5 -- per second while a fighting clone is next to its target
-- Roblox's own default animations (usable in any game)
local CLONE_ANIMATIONS = {
	walk = { [Enum.HumanoidRigType.R15] = "rbxassetid://507777826", [Enum.HumanoidRigType.R6] = "rbxassetid://180426354" },
	dance = { [Enum.HumanoidRigType.R15] = "rbxassetid://507771019", [Enum.HumanoidRigType.R6] = "rbxassetid://182435998" },
}

local clonesFolder = Instance.new("Folder")
clonesFolder.Name = "OwnerClones"
clonesFolder.Parent = workspace

local clones = {} -- { model, humanoid, root, walkTrack, danceTrack, lastHit }
local cloneOwner = nil -- the player whose clones these are
local cloneMode = { name = "follow", target = nil }

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

local function removeClones()
	for _, clone in ipairs(clones) do
		clone.model:Destroy()
	end
	table.clear(clones)
end

local function spawnClone(owner, index)
	local ownerRoot = rootOf(owner)
	if not ownerRoot then
		return
	end
	local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, owner.UserId)
	if not ok or not model then
		notify(owner, "Couldn't make a clone: " .. tostring(model))
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return
	end
	model.Name = owner.Name .. "Clone" .. index
	humanoid.DisplayName = owner.DisplayName .. "'s clone"
	local angle = index / MAX_CLONES * math.pi * 2
	model:PivotTo(ownerRoot.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6))
	model.Parent = clonesFolder
	pcall(root.SetNetworkOwner, root, nil) -- the server moves them

	local clone = { model = model, humanoid = humanoid, root = root, lastHit = 0 }
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

local function setCloneMode(name, target)
	cloneMode.name, cloneMode.target = name, target
	for _, clone in ipairs(liveClones()) do
		if name == "dance" then
			clone.humanoid:MoveTo(clone.root.Position)
			if not clone.danceTrack then
				clone.danceTrack = loadTrack(clone.humanoid, "dance")
				clone.danceTrack:Play(0.2)
			end
		elseif clone.danceTrack then
			clone.danceTrack:Stop(0.2)
			clone.danceTrack = nil
		end
		if name == "stay" then
			clone.humanoid:MoveTo(clone.root.Position)
		end
	end
end

-- /clones beat the game: each clone flies high over the wall and the course, dives into the red portal,
-- comes out in the red button room, walks up and presses the button (each press adds one to the owner's
-- beat the game count). Then they all come back.
local CLONE_FLY_HEIGHT = 90 -- above the walls, buildings and antennas
local CLONE_FLY_SPEED = 90 -- studs per second

local function flyCloneTo(root, position)
	local distance = (position - root.Position).Magnitude
	local flat = (position - root.Position) * Vector3.new(1, 0, 1)
	local facing = flat.Magnitude > 0.1 and CFrame.lookAt(position, position + flat) or CFrame.new(position)
	local tween = TweenService:Create(root, TweenInfo.new(math.max(0.4, distance / CLONE_FLY_SPEED), Enum.EasingStyle.Linear), { CFrame = facing })
	tween:Play()
	tween.Completed:Wait()
end

local function clonesBeatTheGame(owner)
	local portal = CollectionService:GetTagged("BeatGamePortal")[1]
	local arrival = CollectionService:GetTagged("BeatGameArrival")[1]
	local prompt = CollectionService:GetTagged("BeatGameButton")[1]
	local button = prompt and prompt.Parent
	if not portal or not arrival or not button then
		notify(owner, "The beat-the-game course isn't there.")
		return
	end

	local list = { table.unpack(liveClones()) }
	if #list == 0 then
		notify(owner, "You don't have any clones. Make some with /clone.")
		return
	end
	setCloneMode("busy") -- the movement loop leaves them alone
	notify(owner, "Your clones are flying off to beat the game!")

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
				-- Each clone's press counts as a beat the game for the owner
				local ownerData = FighterStats.GetPlayerData(owner)
				ownerData.gameBeats = (ownerData.gameBeats or 0) + 1
				sendStats(owner)
				notify(owner, humanoid.DisplayName .. " " .. i .. " pressed the red button! +1 beat the game for you.")
			end)
			pending -= 1
		end)
	end

	-- Wait for every clone (at most 30 seconds), then always bring them all back
	local giveUpAt = os.clock() + 30
	while pending > 0 and os.clock() < giveUpAt do
		task.wait(0.25)
	end
	notify(owner, "All your clones beat the game!")
	announcementEvent:FireAllClients("👑 " .. owner.DisplayName .. "'s clones beat the game!")
	task.wait(3)

	local ownerRoot = rootOf(owner)
	if ownerRoot then
		for j, clone in ipairs(liveClones()) do
			clone.root.Anchored = false
			local angle = j / MAX_CLONES * math.pi * 2
			clone.model:PivotTo(ownerRoot.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6))
			clone.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		-- Replace any clone that was lost on the way, so the owner gets the same number back
		local missing = math.min(#list, MAX_CLONES) - #liveClones()
		for k = 1, missing do
			task.spawn(spawnClone, owner, #clones + k)
		end
	end
	setCloneMode("follow")
end

local function cloneCommand(admin, args)
	if not Admins.IsOwner(admin) then
		return
	end
	-- A number is required: "/clone" on its own does nothing
	local requested = tonumber(args[1])
	if not requested or requested ~= requested then
		notify(admin, "Usage: /clone <number>, e.g. /clone 5")
		return
	end
	local count = math.clamp(math.floor(requested), 1, MAX_CLONES)
	count = math.min(count, MAX_CLONES - #liveClones())
	if count <= 0 then
		notify(admin, "You already have " .. MAX_CLONES .. " clones (the most). Use /clones remove to clear them.")
		return
	end
	if cloneOwner ~= admin then
		removeClones()
		cloneOwner = admin
	end
	for i = 1, count do
		task.spawn(spawnClone, admin, #clones + i)
	end
	notify(admin, "Made " .. count .. (count == 1 and " clone" or " clones") .. ". Try /clones follow, stay, dance, copy, fight <name> or remove.")
end

local function clonesCommand(admin, args)
	if not Admins.IsOwner(admin) then
		return
	end
	local order = string.lower(args[1] or "")
	local wholeOrder = string.gsub(string.lower(table.concat(args, "")), "[^%a]", "")
	if wholeOrder == "beatthegame" or order == "beat" then
		task.spawn(clonesBeatTheGame, admin)
	elseif order == "remove" then
		removeClones()
		notify(admin, "Clones removed.")
	elseif order == "follow" or order == "stay" or order == "dance" or order == "copy" then
		setCloneMode(order)
		notify(admin, "Clones: " .. order .. ".")
	elseif order == "fight" then
		local target = args[2] and findPlayerInServer(args[2])
		if not target then
			notify(admin, "Usage: /clones fight <name> (a player in this server)")
			return
		end
		setCloneMode("fight", target)
		notify(admin, "Clones are going after " .. target.DisplayName .. "!")
	else
		notify(admin, "Usage: /clones follow | stay | dance | copy | fight <name> | beat the game | remove")
	end
end

-- Moves the clones a few times a second, depending on the current order
task.spawn(function()
	while true do
		task.wait(0.2)
		local list = liveClones()
		local ownerRoot = rootOf(cloneOwner)
		local ownerHumanoid = ownerRoot and ownerRoot.Parent:FindFirstChildOfClass("Humanoid")
		local now = os.clock()
		for i, clone in ipairs(list) do
			if cloneMode.name == "follow" and ownerRoot then
				-- A loose ring around the owner
				local angle = i / #list * math.pi * 2
				local spot = ownerRoot.Position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
				if (clone.root.Position - spot).Magnitude > 3 then
					clone.humanoid:MoveTo(spot)
				end
			elseif cloneMode.name == "copy" and ownerRoot then
				-- Rows of five behind the owner, facing the same way, jumping when the owner jumps
				local column = (i - 1) % 5 - 2
				local row = math.floor((i - 1) / 5) + 1
				clone.humanoid:MoveTo((ownerRoot.CFrame * CFrame.new(column * 4, 0, row * 5)).Position)
				local state = ownerHumanoid and ownerHumanoid:GetState()
				if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
					clone.humanoid.Jump = true
				end
			elseif cloneMode.name == "fight" then
				local targetRoot = rootOf(cloneMode.target)
				local targetHumanoid = targetRoot and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
				if not targetHumanoid or targetHumanoid.Health <= 0 then
					setCloneMode("follow")
					break
				end
				clone.humanoid:MoveTo(targetRoot.Position)
				if (clone.root.Position - targetRoot.Position).Magnitude < 5 and now - clone.lastHit >= 1 then
					clone.lastHit = now
					targetHumanoid:TakeDamage(CLONE_PUNCH_DAMAGE)
				end
			end
		end
	end
end)

-- ==================== COMMAND TABLE ====================
-- minArgs: how many words must follow the command; usage: shown when they're missing

local COMMANDS = {
	ban = { run = ban, minArgs = 1, usage = "/ban <username>" },
	unban = { run = unban, minArgs = 1, usage = "/unban <username>" },
	fly = { run = fly },
	unfly = { run = unfly },
	give = { run = give, minArgs = 2, usage = "/give <name> <item>, e.g. /give Bob owner treadmill" },
	take = { run = take, minArgs = 2, usage = "/take <name> commands" },
	reset = { run = reset },
	privateserver = { run = privateServer },
	clone = { run = cloneCommand, minArgs = 1, usage = "/clone <number>, e.g. /clone 5" },
	clones = { run = clonesCommand },
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
}

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
	local command = string.match(words[1] or "", "^/([%a%-]+)$")
	local entry = command and COMMANDS[string.gsub(string.lower(command), "%-", "")]
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
			local command = string.match(string.lower(message), "^/([%a%-]+)")
			if command and COMMANDS[string.gsub(command, "%-", "")] then
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
	if player == cloneOwner then
		removeClones()
		cloneOwner = nil
	end
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
