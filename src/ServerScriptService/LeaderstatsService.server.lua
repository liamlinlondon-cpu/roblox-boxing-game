-- Columns in the player list (top right): Wins, then Money to its right. Roblox shows a player's
-- "leaderstats" values as columns in the order they're added. They're kept in sync with the player's
-- stats (FighterStats) about once a second, so every way of earning wins or money shows up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local COLUMNS = { -- left to right
	{ name = "Wins", stat = "arenaWins" },
	{ name = "Money", stat = "money" },
}

local function setup(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	for _, column in ipairs(COLUMNS) do
		if not leaderstats:FindFirstChild(column.name) then
			-- NumberValue so very big numbers (even infinite ones from owner commands) fit
			local value = Instance.new("NumberValue")
			value.Name = column.name
			value.Parent = leaderstats
		end
	end
end

Players.PlayerAdded:Connect(setup)
for _, player in ipairs(Players:GetPlayers()) do
	setup(player)
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local data = FighterStats.GetPlayerData(player)
				for _, column in ipairs(COLUMNS) do
					local value = leaderstats:FindFirstChild(column.name)
					local number = data[column.stat] or 0
					if value and value.Value ~= number then
						value.Value = number
					end
				end
			end
		end
	end
end)
