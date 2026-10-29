-- The money goal (MoneyGoalService): "💰 Get 4,473 strength → $800" with a bar that fills as the stat goes
-- up, sitting just above the stats panel on the left (GameScreenManager's HomeFrame) and hidden when that
-- panel is (during a fight). Finishing it pays the money and shows the next goal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local goalEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MoneyGoal")
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 40)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoneyGoalGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local BOX_HEIGHT = 50
local box = Instance.new("Frame")
box.Size = UDim2.new(0, 260, 0, BOX_HEIGHT)
box.Position = UDim2.new(0, 12, 0.5, -280) -- until the stats panel is found
box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
box.BackgroundTransparency = 0.15
box.Visible = false
box.Parent = screenGui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 10)
round.Parent = box
local ring = Instance.new("UIStroke")
ring.Color = GOLD
ring.Thickness = 2
ring.Parent = box

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -16, 0, 26)
label.Position = UDim2.new(0, 8, 0, 3)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = box

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, -16, 0, 12)
barBack.Position = UDim2.new(0, 8, 0, 32)
barBack.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
barBack.Parent = box
local barRound = Instance.new("UICorner")
barRound.CornerRadius = UDim.new(0.5, 0)
barRound.Parent = barBack
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GOLD
barFill.Parent = barBack
barRound:Clone().Parent = barFill
local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.TextColor3 = Color3.new(1, 1, 1)
barText.TextStrokeTransparency = 0.3
barText.Font = Enum.Font.GothamBold
barText.TextScaled = true
barText.ZIndex = 2
barText.Parent = barBack

-- Follow the stats panel: same width, just above it, shown only when it is
local hasGoal = false
local statsPanel = nil
local function follow()
	if statsPanel then
		local position, size = statsPanel.AbsolutePosition, statsPanel.AbsoluteSize
		box.Size = UDim2.new(0, size.X, 0, BOX_HEIGHT)
		box.Position = UDim2.new(0, position.X, 0, position.Y - BOX_HEIGHT - 8)
	end
	box.Visible = hasGoal and (statsPanel == nil or statsPanel.Visible)
end
task.spawn(function()
	local gameScreen = player:WaitForChild("PlayerGui"):WaitForChild("GameScreenGui", 30)
	statsPanel = gameScreen and gameScreen:WaitForChild("HomeFrame", 30)
	if statsPanel then
		for _, property in ipairs({ "AbsolutePosition", "AbsoluteSize", "Visible" }) do
			statsPanel:GetPropertyChangedSignal(property):Connect(follow)
		end
	end
	follow()
end)

goalEvent.OnClientEvent:Connect(function(goal)
	if type(goal) ~= "table" then
		return
	end
	hasGoal = true
	follow()
	label.Text = string.format("💰 Get %s %s → $%s", Catalog.FormatWithCommas(goal.target), goal.stat, Catalog.FormatWithCommas(goal.reward))
	barText.Text = Catalog.FormatWithCommas(goal.progress) .. " / " .. Catalog.FormatWithCommas(goal.target)
	local fraction = goal.target > 0 and math.clamp(goal.progress / goal.target, 0, 1) or 0
	TweenService:Create(barFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(fraction, 1) }):Play()
end)
