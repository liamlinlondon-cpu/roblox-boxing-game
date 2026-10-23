-- Sky event banner under the stat bars: announces the event color and counts down to its end.
-- SkyEventService publishes the event as ReplicatedStorage attributes (SkyEventColor, SkyEventEndsAt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkyEventGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Sits just below the 90px stat bars panel (StatBarsClient)
local banner = Instance.new("TextLabel")
banner.Name = "SkyEventBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.new(0.4, 0, 0, 30)
banner.Position = UDim2.new(0.5, 0, 0, 106)
banner.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
banner.BackgroundTransparency = 0.2
banner.BorderSizePixel = 2
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextStrokeTransparency = 0.3
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Visible = false
banner.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(280, 30)
sizeConstraint.MaxSize = Vector2.new(460, 30)
sizeConstraint.Parent = banner

local function refresh()
	local colorId = ReplicatedStorage:GetAttribute("SkyEventColor")
	local sky = colorId and Catalog.SkyColorById[colorId]
	if not sky then
		banner.Visible = false
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("SkyEventEndsAt") or Workspace:GetServerTimeNow()
	local secondsLeft = math.max(0, math.floor(endsAt - Workspace:GetServerTimeNow()))
	banner.Text = string.format(
		"%s SKY EVENT! %s Skin at the Color Shop · %d:%02d",
		string.upper(sky.name),
		sky.name,
		secondsLeft // 60,
		secondsLeft % 60
	)
	-- The rainbow banner shifts color on every countdown tick
	local color = sky.rainbow and Color3.fromHSV((os.clock() * 0.15) % 1, 0.85, 1) or sky.color
	banner.BorderColor3 = color
	banner.BackgroundColor3 = Color3.fromRGB(24, 24, 24):Lerp(color, 0.35)
	banner.Visible = true
end

ReplicatedStorage:GetAttributeChangedSignal("SkyEventColor"):Connect(refresh)
refresh()

-- Tick the countdown while an event is running
task.spawn(function()
	while true do
		task.wait(1)
		if banner.Visible then
			refresh()
		end
	end
end)
