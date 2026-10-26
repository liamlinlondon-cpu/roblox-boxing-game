-- Draws the global leaderboards (LeaderboardService) on the boards between the gyms. Each board is a
-- SurfaceGui in this player's PlayerGui, which is what lets its list scroll with the mouse wheel (or a
-- finger) while pointing at it. Money shows as $123,456,789.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))

local player = Players.LocalPlayer
local folder = Workspace:WaitForChild("Leaderboards")

local ROW_HEIGHT = 44 -- pixels; a board is 12 x 15 studs at 40 pixels per stud

local function formatValue(value, format, max)
	local text = Catalog.FormatWithCommas(value)
	if value >= max then
		text ..= "+"
	end
	if format == "money" then
		return "$" .. text
	elseif format == "robux" then
		return "R$ " .. text
	end
	return text
end

local boards = {} -- [index] = { title, list }

local function buildBoard(panel)
	local index = panel:GetAttribute("BoardIndex")
	if not index or boards[index] then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard" .. index
	gui.Adornee = panel
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 64)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Text = "Loading..."
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = gui

	-- The scrollable list of players
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -90)
	list.Position = UDim2.new(0, 10, 0, 80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	boards[index] = { title = title, list = list }
end

local function render()
	local json = ReplicatedStorage:GetAttribute("LeaderboardData")
	if not json then
		return
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		return
	end
	for index, entry in ipairs(data) do
		local board = boards[index]
		if board then
			local color = Color3.fromRGB(entry.color[1], entry.color[2], entry.color[3])
			board.title.Text = entry.title
			board.title.TextColor3 = color
			for _, child in ipairs(board.list:GetChildren()) do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local lines = {}
			if entry.message then
				table.insert(lines, { text = entry.message, color = Color3.fromRGB(200, 200, 200) })
			end
			for rank, row in ipairs(entry.rows) do
				table.insert(lines, {
					text = string.format("#%d  %s  —  %s", rank, row.name, formatValue(row.value, entry.format, entry.max)),
					color = rank == 1 and color or Color3.new(1, 1, 1),
				})
			end
			for order, line in ipairs(lines) do
				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, -14, 0, ROW_HEIGHT)
				label.LayoutOrder = order
				label.BackgroundTransparency = 1
				label.Text = line.text
				label.TextColor3 = line.color
				label.Font = Enum.Font.GothamBold
				label.TextScaled = true
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = board.list
			end
		end
	end
end

for _, child in ipairs(folder:GetChildren()) do
	if child:IsA("BasePart") then
		buildBoard(child)
	end
end
folder.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		task.defer(function()
			buildBoard(child)
			render()
		end)
	end
end)

render()
ReplicatedStorage:GetAttributeChangedSignal("LeaderboardData"):Connect(render)
