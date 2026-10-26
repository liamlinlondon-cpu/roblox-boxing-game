-- Global leaderboards: three boards between two gyms showing the top 50 players across ALL servers for
-- Most Wins, Most Money and Most Robux Spent. Each server writes its players' numbers to an
-- OrderedDataStore once a minute and reads the top 50 back. The rankings are published as the
-- "LeaderboardData" attribute on ReplicatedStorage; each player's LeaderboardClient draws them on the
-- boards with a list you can scroll with the mouse wheel.
--
-- Studio: needs Game Settings > Security > "Enable Studio Access to API Services"; without it the boards
-- say so. The published game always works.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local UPDATE_SECONDS = 60
local TOP_COUNT = 50
-- OrderedDataStores hold whole numbers up to about 9.2 quintillion; bigger (or infinite) values are
-- stored as this
local MAX_STORED = 9e18

local BOARDS = { -- left to right as you face them; format tells LeaderboardClient how to show numbers
	{ title = "🏆 MOST WINS", stat = "arenaWins", store = "LeaderboardWins_v1", color = { 255, 200, 40 }, format = "number" },
	{ title = "💰 MOST MONEY", stat = "money", store = "LeaderboardMoney_v1", color = { 80, 210, 100 }, format = "money" },
	{ title = "💎 MOST ROBUX SPENT", stat = "robuxSpent", store = "LeaderboardRobux_v1", color = { 120, 190, 255 }, format = "robux" },
}

for _, board in ipairs(BOARDS) do
	board.ordered = DataStoreService:GetOrderedDataStore(board.store)
end

-- ==================== THE BOARDS ====================

local folder = Instance.new("Folder")
folder.Name = "Leaderboards"
folder.Parent = Workspace

local function part(name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local center = WorldConfig.Arena.Center
local middle = center + WorldConfig.Leaderboards.Position
local facing = CFrame.lookAt(middle, Vector3.new(center.X, middle.Y, center.Z)) -- face the ring

for i = 1, #BOARDS do
	local base = facing * CFrame.new((i - 2) * WorldConfig.Leaderboards.Spacing, 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		part("Post", Vector3.new(0.6, 18, 0.6), base * CFrame.new(side * 5.7, 9, 0.4), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	end
	local panel = part("Board" .. i, Vector3.new(12, 15, 0.5), base * CFrame.new(0, 10, 0), Color3.fromRGB(18, 18, 24))
	panel:SetAttribute("BoardIndex", i)
end

-- ==================== SAVING AND PUBLISHING ====================

local nameCache = {}
local function nameOf(userId)
	if not nameCache[userId] then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			nameCache[userId] = player.DisplayName
		else
			local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			nameCache[userId] = ok and name or ("Player " .. userId)
		end
	end
	return nameCache[userId]
end

local function storedValue(value)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_STORED)
end

local function savePlayer(player)
	local data = FighterStats.GetPlayerData(player)
	for _, board in ipairs(BOARDS) do
		pcall(function()
			board.ordered:SetAsync("u_" .. player.UserId, storedValue(data[board.stat]))
		end)
	end
end

-- Reads the top players for every board and publishes them for LeaderboardClient
local function publishBoards()
	local published = {}
	for i, board in ipairs(BOARDS) do
		local entry = { title = board.title, color = board.color, format = board.format, max = MAX_STORED, rows = {} }
		local ok, page = pcall(function()
			return board.ordered:GetSortedAsync(false, TOP_COUNT):GetCurrentPage()
		end)
		if not ok then
			entry.message = "Leaderboard can't load right now"
		elseif #page == 0 then
			entry.message = "No one yet. Be the first!"
		else
			for _, item in ipairs(page) do
				local userId = tonumber(string.match(item.key, "^u_(%d+)$"))
				table.insert(entry.rows, { name = userId and nameOf(userId) or item.key, value = item.value })
			end
		end
		published[i] = entry
	end
	ReplicatedStorage:SetAttribute("LeaderboardData", HttpService:JSONEncode(published))
end

-- Players leaving get one last save so their numbers are up to date
Players.PlayerRemoving:Connect(savePlayer)

task.spawn(function()
	task.wait(10) -- let saved progress load first
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
		publishBoards()
		task.wait(UPDATE_SECONDS)
	end
end)
