-- Who may use admin chat commands (sky events, /ban, /unban): only WorldConfig.OwnerUserId, plus any
-- user IDs in WorldConfig.AdminUserIds. There is no Studio exception, so other accounts and Studio test
-- players get nothing when they type the commands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local Admins = {}

-- These accounts can use the commands and can't be banned
function Admins.IsAdminUserId(userId)
	return userId == WorldConfig.OwnerUserId or table.find(WorldConfig.AdminUserIds, userId) ~= nil
end

function Admins.IsAdmin(player)
	return Admins.IsAdminUserId(player.UserId)
end

return Admins
