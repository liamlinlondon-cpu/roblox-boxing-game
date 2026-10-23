-- Who may use admin chat commands (sky events, /ban, /unban): the game's owner (or the owning group's
-- owner), anyone testing in Studio, plus the user IDs in WorldConfig.AdminUserIds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local Admins = {}

-- True for the game's owner and listed admins (no Studio exception): these accounts can't be banned
function Admins.IsAdminUserId(userId)
	if table.find(WorldConfig.AdminUserIds, userId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and userId == game.CreatorId
end

function Admins.IsAdmin(player)
	if RunService:IsStudio() or Admins.IsAdminUserId(player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return false
end

return Admins
