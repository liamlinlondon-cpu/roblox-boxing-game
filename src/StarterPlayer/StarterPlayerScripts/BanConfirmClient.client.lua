-- The check before a ban: after "/ban Bob, reason" the admin sees who's about to be banned and why,
-- and the ban only happens if they press YES, BAN (AdminCommandService). NO (or closing) cancels it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local banConfirm = ReplicatedStorage:WaitForChild("Events"):WaitForChild("BanConfirm")
local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BanConfirmGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
end

local box = Instance.new("Frame")
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.5, 0.5)
box.Size = UDim2.new(0, 380, 0, 220)
box.BackgroundColor3 = Color3.fromRGB(25, 20, 22)
box.Parent = screenGui
corner(box, UDim.new(0, 12))
local ring = Instance.new("UIStroke")
ring.Color = Color3.fromRGB(230, 50, 50)
ring.Thickness = 3
ring.Parent = box

local function label(text, size, position, color, font, scaled)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextColor3 = color
	l.Font = font
	l.TextScaled = scaled ~= false
	l.TextWrapped = true
	l.Parent = box
	return l
end

local title = label("", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 0, 12), Color3.fromRGB(255, 90, 90), Enum.Font.GothamBlack)
local reasonLabel = label("", UDim2.new(1, -24, 0, 80), UDim2.new(0, 12, 0, 58), Color3.new(1, 1, 1), Enum.Font.Gotham, false)
reasonLabel.TextSize = 18
reasonLabel.TextYAlignment = Enum.TextYAlignment.Top

local function button(text, color, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -18, 0, 48)
	b.Position = UDim2.new(x, x == 0 and 12 or 6, 1, -60)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.Parent = box
	corner(b)
	return b
end
local yesButton = button("✅ YES, BAN", Color3.fromRGB(190, 40, 40), 0)
local noButton = button("❌ NO", Color3.fromRGB(70, 70, 80), 0.5)

local function answer(yes)
	if screenGui.Enabled then
		screenGui.Enabled = false
		banConfirm:FireServer(yes)
	end
end
yesButton.Activated:Connect(function()
	answer(true)
end)
noButton.Activated:Connect(function()
	answer(false)
end)

banConfirm.OnClientEvent:Connect(function(name, reason)
	title.Text = "🔨 Ban " .. tostring(name) .. "?"
	if type(reason) == "string" and string.find(reason, "%S") then
		reasonLabel.Text = "Reason: " .. reason .. "\n\nIs this the real reason? They'll see it when they're banned."
	else
		reasonLabel.Text = "No reason given.\n\nType /ban " .. tostring(name) .. " ,reason:<reason> to add one."
	end
	screenGui.Enabled = true
end)
