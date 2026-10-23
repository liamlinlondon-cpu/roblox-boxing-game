-- Admin chat commands:
--   /ban <username>    bans the player from the game (all servers) and kicks them if they're here
--   /unban <username>  lifts the ban
-- Only admins can use them (see Admins). The username can be a player in this server (name or display
-- name, start of it is enough) or any Roblox username. Results are shown to the admin in chat.
--
-- Bans use Roblox's ban system (Players:BanAsync), which works in live servers. In Studio, where it
-- isn't available, the player is kicked and banned from this test session only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Admins = require(script.Parent:WaitForChild("Admins"))

local noticeEvent = Instance.new("RemoteEvent")
noticeEvent.Name = "AdminNotice"
noticeEvent.Parent = ReplicatedStorage:WaitForChild("Events")

local BAN_MESSAGE = "You have been banned from this game."
local sessionBans = {} -- [userId] = true: fallback when Players:BanAsync isn't available (Studio)

local function notify(admin, text)
	noticeEvent:FireClient(admin, text)
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

local function ban(admin, query)
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

local function unban(admin, query)
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

local COMMANDS = { ban = ban, unban = unban }

-- message is the full chat text, e.g. "/ban SomeUser"
local function runCommand(admin, message)
	if not Admins.IsAdmin(admin) then
		return
	end
	local command, query = string.match(message, "^/(%a+)%s+(%S+)")
	local handler = command and COMMANDS[string.lower(command)]
	if not handler then
		notify(admin, "Usage: /ban <username>  or  /unban <username>")
		return
	end
	task.spawn(handler, admin, query)
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
