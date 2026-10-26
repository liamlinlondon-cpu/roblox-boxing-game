-- Global leaderboards: three boards between two gyms showing the top 10 players across ALL servers for
-- Most Wins, Most Money and Most Robux Spent. Each server writes its players' numbers to an
-- OrderedDataStore once a minute and reads the top 10 back to show on the boards.
--
-- Studio: needs Game Settings > Security > "Enable Studio Access to API Services"; without it the boards
-- say so. The published game always works.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local UPDATE_SECONDS = 60
local TOP_COUNT = 10
-- OrderedDataStores hold whole numbers up to about 9.2 quintillion; bigger (or infinite) values are
-- stored as this
local MAX_STORED = 9e18

local BOARDS = { -- left to right as you face them
	{ title = "🏆 MOST WINS", stat = "arenaWins", store = "LeaderboardWins_v1", color = Color3.fromRGB(255, 200, 40) },
	{ title = "💰 MOST MONEY", stat = "money", store = "LeaderboardMoney_v1", color = Color3.fromRGB(80, 210, 100) },
	{ title = "💎 MOST ROBUX SPENT", stat = "robuxSpent", store = "LeaderboardRobux_v1", color = Color3.fromRGB(120, 190, 255) },
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

for i, board in ipairs(BOARDS) do
	local base = facing * CFrame.new((i - 2) * WorldConfig.Leaderboards.Spacing, 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		part("Post", Vector3.new(0.6, 18, 0.6), base * CFrame.new(side * 5.7, 9, 0.4), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	end
	local panel = part("Board", Vector3.new(12, 15, 0.5), base * CFrame.new(0, 10, 0), Color3.fromRGB(18, 18, 24))

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0.12, 0)
	title.Position = UDim2.new(0, 10, 0.02, 0)
	title.BackgroundTransparency = 1
	title.Text = board.title
	title.TextColor3 = board.color
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = gui

	board.rows = {}
	for row = 1, TOP_COUNT do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -30, 0.075, 0)
		label.Position = UDim2.new(0, 15, 0.16 + (row - 1) * 0.08, 0)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextColor3 = row == 1 and board.color or Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = gui
		board.rows[row] = label
	end
	board.rows[1].Text = "Loading..."
end

-- ==================== SAVING AND SHOWING ====================

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

-- Write every player's numbers in this server
local function savePlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = FighterStats.GetPlayerData(player)
		for _, board in ipairs(BOARDS) do
			pcall(function()
				board.ordered:SetAsync("u_" .. player.UserId, storedValue(data[board.stat]))
			end)
		end
	end
end

-- Read the top 10 for every board and show them
local function refreshBoards()
	for _, board in ipairs(BOARDS) do
		local ok, page = pcall(function()
			return board.ordered:GetSortedAsync(false, TOP_COUNT):GetCurrentPage()
		end)
		for row = 1, TOP_COUNT do
			board.rows[row].Text = ""
		end
		if not ok then
			board.rows[1].Text = "Leaderboard can't load right now"
		elseif #page == 0 then
			board.rows[1].Text = "No one yet. Be the first!"
		else
			for row, entry in ipairs(page) do
				local userId = tonumber(string.match(entry.key, "^u_(%d+)$"))
				local name = userId and nameOf(userId) or entry.key
				local amount = entry.value >= MAX_STORED and (Catalog.FormatNumber(MAX_STORED) .. "+") or Catalog.FormatNumber(entry.value)
				board.rows[row].Text = string.format("#%d  %s  —  %s", row, name, amount)
			end
		end
	end
end

-- Players leaving get one last save so their numbers are up to date
Players.PlayerRemoving:Connect(function(player)
	local data = FighterStats.GetPlayerData(player)
	for _, board in ipairs(BOARDS) do
		pcall(function()
			board.ordered:SetAsync("u_" .. player.UserId, storedValue(data[board.stat]))
		end)
	end
end)

task.spawn(function()
	task.wait(10) -- let saved progress load first
	while true do
		savePlayers()
		refreshBoards()
		task.wait(UPDATE_SECONDS)
	end
end)
