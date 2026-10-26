-- Hulk Wheel and messages to the owner.
--
-- HULK WHEEL: the first time a player turns Hulk (WorldConfig.HulkWheel.Strength), they get 5 spins of a
-- color wheel. Most of the wheel (magenta, purple, red, blue) wins nothing. Orange, yellow, pink, cyan and
-- green give that color's skin (green is a tiny sliver), and rainbow starts a Rainbow sky event for the
-- whole server. The server picks every result; HulkWheelClient only shows the wheel turning to it.
--
-- MESSAGES: any player can chat with the owner (e.g. to ask for a wheel reset). Chats are kept in a
-- DataStore, so the owner reads them from whatever server they're in (VIP ADMIN panel > MESSAGES), even
-- after the player left, and both sides see new messages straight away through MessagingService. Each
-- chat shows where the player is (public or private server); the owner can join public servers with a
-- button, and can reset a player's wheel (5 new spins) from anywhere. Studio needs "Enable Studio Access
-- to API Services"; the published game always works.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local Admins = require(script.Parent:WaitForChild("Admins"))
local startSkyEvent = script.Parent:WaitForChild("SkyEventService"):WaitForChild("StartSkyEvent")

local WHEEL = WorldConfig.HulkWheel
local MESSAGE_COOLDOWN = 5 -- seconds between messages from one player
local MAX_MESSAGE = 200
local MAX_CHATS = 100 -- chats kept in the owner's list
local MAX_LINES = 40 -- messages kept per chat
local CHAT_TOPIC = "OwnerChat"

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = eventsFolder:WaitForChild("Announcement")

local wheelFunction = Instance.new("RemoteFunction")
wheelFunction.Name = "HulkWheel"
wheelFunction.Parent = eventsFolder
-- Server -> client: "wheel" (spins changed), "chat" (new message from the owner), "inbox" (owner: new message)
local wheelNotice = Instance.new("RemoteEvent")
wheelNotice.Name = "HulkWheelNotice"
wheelNotice.Parent = eventsFolder

local publish -- defined with the live updates below

local chatStore = DataStoreService:GetDataStore("OwnerChats_v1") -- "index" = the owner's list, "chat_<userId>" = one chat
local resetStore = DataStoreService:GetDataStore("HulkWheelResets_v1") -- "u_<userId>" = a reset waiting for them

local TOTAL_CHANCE = 0
for _, slice in ipairs(WHEEL.Slices) do
	TOTAL_CHANCE += slice.chance
end

local function wheelState(player)
	local data = FighterStats.GetPlayerData(player)
	return {
		unlocked = data.hulkSpinsGiven == true,
		spins = data.hulkSpins or 0,
	}
end

-- ==================== TURNING HULK ====================
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = FighterStats.GetPlayerData(player)
			if not data.hulkSpinsGiven and data.strength >= WHEEL.Strength then
				data.hulkSpinsGiven = true
				data.hulkSpins = (data.hulkSpins or 0) + WHEEL.Spins
				wheelNotice:FireClient(player, "wheel", wheelState(player), true)
				announcementEvent:FireClient(player, "💚 You turned HULK! You got " .. WHEEL.Spins .. " spins on the Hulk Wheel!")
			end
		end
	end
end)

-- ==================== SPINNING ====================
local function pickSlice()
	local roll = Random.new():NextNumber() * TOTAL_CHANCE
	for index, slice in ipairs(WHEEL.Slices) do
		roll -= slice.chance
		if roll < 0 then
			return index, slice
		end
	end
	return 1, WHEEL.Slices[1]
end

local spinning = {} -- one spin at a time per player
local SPIN_SECONDS = 4 -- about as long as the wheel takes to stop on screen

local function spin(player)
	local data = FighterStats.GetPlayerData(player)
	if spinning[player] or (data.hulkSpins or 0) <= 0 then
		return nil
	end
	spinning[player] = true
	task.delay(SPIN_SECONDS, function()
		spinning[player] = nil
	end)
	data.hulkSpins -= 1

	local index, slice = pickSlice()
	local sky = Catalog.SkyColorById[slice.color]
	local message
	if slice.wasted then
		message = sky.name .. "... nothing this time."
	elseif slice.event then
		message = "🌈 RAINBOW! A Rainbow sky event is starting!"
		task.delay(SPIN_SECONDS, function()
			startSkyEvent:Invoke(slice.color)
			announcementEvent:FireAllClients("🌈 " .. player.DisplayName .. " spun RAINBOW on the Hulk Wheel! Rainbow sky event!")
		end)
	elseif data.ownedSkins[slice.color] then
		message = "You won the " .. sky.name .. " skin! (You already had it.)"
	else
		data.ownedSkins[slice.color] = true
		message = "🎉 You won the " .. sky.name .. " skin! Wear it from the Color Shop. " .. Catalog.SkinPerkText(sky)
		if sky.ownerOnly then
			task.delay(SPIN_SECONDS, function()
				announcementEvent:FireAllClients("💚 " .. player.DisplayName .. " won the super rare " .. string.upper(sky.name) .. " skin on the Hulk Wheel!")
			end)
		end
	end
	return { slice = index, message = message, won = not slice.wasted, spins = data.hulkSpins }
end

-- ==================== MESSAGES ====================
local lastMessage = {}

local function filtered(text, fromUserId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end

-- Where this server is, so the owner knows where to find the player
local function whereAmI()
	if game.PrivateServerOwnerId ~= 0 then
		local ok, ownerName = pcall(Players.GetNameFromUserIdAsync, Players, game.PrivateServerOwnerId)
		return { jobId = game.JobId, private = true, privateOwner = ok and ownerName or nil }
	end
	return { jobId = game.JobId, private = game.PrivateServerId ~= "" }
end


local function readChat(userId)
	local ok, chat = pcall(chatStore.GetAsync, chatStore, "chat_" .. userId)
	if not ok then
		return nil
	end
	return chat or { lines = {} }
end

-- Adds a line to one chat and moves it to the top of the owner's list
local function addLine(userId, fromOwner, text, who)
	local ok = pcall(chatStore.UpdateAsync, chatStore, "chat_" .. userId, function(chat)
		chat = chat or { lines = {} }
		table.insert(chat.lines, { owner = fromOwner, text = text, time = os.time() })
		while #chat.lines > MAX_LINES do
			table.remove(chat.lines, 1)
		end
		if fromOwner then
			chat.playerUnread = true
		else
			chat.where = whereAmI()
		end
		return chat
	end)
	if not ok then
		return false
	end
	pcall(chatStore.UpdateAsync, chatStore, "index", function(list)
		list = list or {}
		local entry = nil
		for i, item in ipairs(list) do
			if item.userId == userId then
				entry = table.remove(list, i)
				break
			end
		end
		entry = entry or { userId = userId }
		if who then
			entry.name, entry.username = who.DisplayName, who.Name
		end
		entry.preview = (fromOwner and "You: " or "") .. text
		entry.time = os.time()
		entry.unread = not fromOwner
		table.insert(list, 1, entry)
		while #list > MAX_CHATS do
			table.remove(list)
		end
		return list
	end)
	return true
end

local function sendToOwner(player, text)
	if Admins.IsOwner(player) then
		return "You're the owner! Read your messages in the VIP ADMIN panel."
	end
	if lastMessage[player] and os.clock() - lastMessage[player] < MESSAGE_COOLDOWN then
		return "Slow down a little before sending another message."
	end
	text = type(text) == "string" and string.sub(text, 1, MAX_MESSAGE) or ""
	if not string.find(text, "%S") then
		return "Type a message first."
	end
	local clean = filtered(text, player.UserId)
	if not clean then
		return "Couldn't send your message right now. Try again later."
	end
	lastMessage[player] = os.clock()
	if not addLine(player.UserId, false, clean, player) then
		return "Couldn't send your message right now. Try again later."
	end
	publish({ to = "owner", userId = player.UserId })
	return true
end

local function ownerReply(owner, userId, text)
	text = type(text) == "string" and string.sub(text, 1, MAX_MESSAGE) or ""
	if not string.find(text, "%S") then
		return "Type a message first."
	end
	local clean = filtered(text, owner.UserId)
	if not clean or not addLine(userId, true, clean, nil) then
		return "Couldn't send right now. Try again."
	end
	publish({ to = "player", userId = userId })
	return true
end

-- The player's own chat (marks the owner's answers as read)
local function playerChat(player)
	local chat = readChat(player.UserId)
	if chat and chat.playerUnread then
		pcall(chatStore.UpdateAsync, chatStore, "chat_" .. player.UserId, function(saved)
			if saved then
				saved.playerUnread = false
			end
			return saved
		end)
	end
	return chat and chat.lines or nil
end

-- One chat for the owner (marks it as read in the list)
local function ownerChat(userId)
	local chat = readChat(userId)
	pcall(chatStore.UpdateAsync, chatStore, "index", function(list)
		for _, item in ipairs(list or {}) do
			if item.userId == userId and item.unread then
				item.unread = false
				return list
			end
		end
		return nil
	end)
	return chat
end

local function closeChat(userId)
	pcall(chatStore.RemoveAsync, chatStore, "chat_" .. userId)
	pcall(chatStore.UpdateAsync, chatStore, "index", function(list)
		list = list or {}
		for i, item in ipairs(list) do
			if item.userId == userId then
				table.remove(list, i)
				return list
			end
		end
		return nil
	end)
	return true
end

-- ==================== RESETTING SOMEONE'S WHEEL ====================
local function applyReset(player)
	local data = FighterStats.GetPlayerData(player)
	data.hulkSpinsGiven = true
	data.hulkSpins = (data.hulkSpins or 0) + WHEEL.Spins
	wheelNotice:FireClient(player, "wheel", wheelState(player), true)
	announcementEvent:FireClient(player, "🎡 The owner reset your Hulk Wheel! You got " .. WHEEL.Spins .. " new spins!")
end

-- A reset saved for a player who wasn't in this server; RemoveAsync hands it back exactly once
local function collectReset(player)
	local ok, waiting = pcall(resetStore.RemoveAsync, resetStore, "u_" .. player.UserId)
	if ok and waiting then
		applyReset(player)
	end
end

local function resetWheel(userId)
	local here = Players:GetPlayerByUserId(userId)
	if here then
		applyReset(here)
		return "Reset! They got " .. WHEEL.Spins .. " new spins."
	end
	if not pcall(resetStore.SetAsync, resetStore, "u_" .. userId, true) then
		return "Couldn't reset right now. Try again."
	end
	publish({ to = "reset", userId = userId })
	return "Reset! They get " .. WHEEL.Spins .. " new spins (now if they're playing, or when they join)."
end

local function joinPlayer(owner, userId)
	local chat = readChat(userId)
	local where = chat and chat.where
	if not where or not where.jobId or where.jobId == "" then
		return "Don't know where they are. Ask them to send a message from the game."
	end
	if where.jobId == game.JobId then
		return "They're in this server with you!"
	end
	local ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, where.jobId, owner)
	if not ok then
		return "Couldn't join. Their server may have closed."
	end
	return where.private and "Trying to join their private server (it only works if they let you in)..." or "Joining their server..."
end

-- ==================== LIVE UPDATES BETWEEN SERVERS ====================
local function ownersHere()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Admins.IsOwner(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function onChatNews(info)
	if type(info) ~= "table" then
		return
	end
	if info.to == "owner" then
		for _, owner in ipairs(ownersHere()) do
			wheelNotice:FireClient(owner, "inbox", info.userId)
		end
	elseif info.to == "player" then
		local player = Players:GetPlayerByUserId(tonumber(info.userId) or 0)
		if player then
			wheelNotice:FireClient(player, "chat")
		end
	elseif info.to == "reset" then
		local player = Players:GetPlayerByUserId(tonumber(info.userId) or 0)
		if player then
			collectReset(player)
		end
	end
end

-- Tells this server straight away, and every other server through MessagingService
function publish(info)
	onChatNews(info)
	task.spawn(pcall, MessagingService.PublishAsync, MessagingService, CHAT_TOPIC, info)
end

pcall(function()
	MessagingService:SubscribeAsync(CHAT_TOPIC, function(message)
		onChatNews(message.Data)
	end)
end)

-- Things that happened while the player was away
script.Parent:WaitForChild("PlayerDataService"):WaitForChild("DataLoaded").Event:Connect(function(player)
	wheelNotice:FireClient(player, "wheel", wheelState(player))
	task.wait(5)
	if not player.Parent then
		return
	end
	collectReset(player)
	local chat = readChat(player.UserId)
	if chat and chat.playerUnread then
		wheelNotice:FireClient(player, "chat")
	end
	if Admins.IsOwner(player) then
		local ok, list = pcall(chatStore.GetAsync, chatStore, "index")
		for _, item in ipairs(ok and list or {}) do
			if item.unread then
				wheelNotice:FireClient(player, "inbox", item.userId)
				break
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	spinning[player] = nil
	lastMessage[player] = nil
end)

-- ==================== REMOTE ====================
local OWNER_ACTIONS = {
	inbox = function()
		local ok, list = pcall(chatStore.GetAsync, chatStore, "index")
		return ok and (list or {}) or nil
	end,
	open = function(_, userId)
		return ownerChat(userId)
	end,
	reply = function(owner, userId, text)
		return ownerReply(owner, userId, text)
	end,
	reset = function(_, userId)
		return resetWheel(userId)
	end,
	join = function(owner, userId)
		return joinPlayer(owner, userId)
	end,
	close = function(_, userId)
		return closeChat(userId)
	end,
}

wheelFunction.OnServerInvoke = function(player, action, a, b)
	if action == "state" then
		return wheelState(player)
	elseif action == "spin" then
		return spin(player)
	elseif action == "chat" then
		return playerChat(player)
	elseif action == "send" then
		return sendToOwner(player, a)
	elseif OWNER_ACTIONS[action] and Admins.IsOwner(player) then
		if action ~= "inbox" and type(a) ~= "number" then
			return nil
		end
		return OWNER_ACTIONS[action](player, a, b)
	end
	return nil
end
