-- Who may use admin chat commands (sky events, /ban, /fly, /give, ...): WorldConfig.OwnerUserId, the
-- user IDs in WorldConfig.AdminUserIds, and players the owner gave commands to with "/give <name> commands"
-- (those last until the player leaves the server). There is no Studio exception, so everyone else,
-- including Studio test players, gets nothing when they type the commands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local Admins = {}

local grantedUserIds = {} -- [userId] = true: given commands by the owner in this server

-- Only the owner can give or take commands
function Admins.IsOwner(player)
	return player.UserId == WorldConfig.OwnerUserId
end

-- These accounts can use the commands and can't be banned
function Admins.IsAdminUserId(userId)
	return userId == WorldConfig.OwnerUserId
		or table.find(WorldConfig.AdminUserIds, userId) ~= nil
		or grantedUserIds[userId] == true
end

function Admins.IsAdmin(player)
	return Admins.IsAdminUserId(player.UserId)
end

-- The VIP ADMIN panel: the owner, and players the owner gave it to with "/give <name> vip admin" (the
-- "HasVipAdminPanel" attribute, until they leave). They can start events (sky, disco, nuke), set their
-- own stats and teleport anywhere; its COMMANDS and MESSAGES tabs stay the owner's.
function Admins.HasVipPanel(player)
	return Admins.IsOwner(player) or player:GetAttribute("HasVipAdminPanel") == true
end

function Admins.Grant(userId)
	grantedUserIds[userId] = true
end

function Admins.Revoke(userId)
	grantedUserIds[userId] = nil
end

return Admins
