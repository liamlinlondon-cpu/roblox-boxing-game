-- Owner announcements, shown to everyone in a gold banner at the top of the screen, just right of the
-- stat bars, e.g. "👑 Liantw1 started a RED SKY event!" or "👑 Liantw1 gave everyone 64x luck!".
-- Sent by SkyEventService and AdminCommandService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local announcementEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Announcement")

local player = Players.LocalPlayer

local SHOW_SECONDS = 6
local GOLD = Color3.fromRGB(255, 215, 0)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AnnouncementGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = player:WaitForChild("PlayerGui")

-- The stat bars are centered and at most 460 wide, so this starts just past their right edge
local banner = Instance.new("TextLabel")
banner.Name = "Announcement"
banner.Size = UDim2.new(0.24, 0, 0, 56)
banner.Position = UDim2.new(0.5, 240, 0, 8)
banner.BackgroundColor3 = Color3.fromRGB(30, 24, 8)
banner.BorderSizePixel = 2
banner.BorderColor3 = GOLD
banner.TextColor3 = GOLD
banner.TextStrokeTransparency = 0.4
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextWrapped = true
banner.Visible = false
banner.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(200, 56)
sizeConstraint.MaxSize = Vector2.new(330, 56)
sizeConstraint.Parent = banner

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = banner

local showToken = 0

announcementEvent.OnClientEvent:Connect(function(text)
	showToken += 1
	local token = showToken
	banner.Text = text
	banner.BackgroundTransparency = 0.1
	banner.TextTransparency = 0
	banner.Visible = true
	task.delay(SHOW_SECONDS, function()
		if showToken ~= token then
			return
		end
		local fade = TweenInfo.new(0.6)
		TweenService:Create(banner, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			if showToken == token then
				banner.Visible = false
			end
		end)
	end)
end)
