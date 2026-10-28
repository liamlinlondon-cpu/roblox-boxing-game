-- The round rebirth button (green with a blue edge, and a silver and a red arrow going round in a circle) on the right, above the nav buttons. Pressing it
-- opens the rebirth panel: the next rebirth's strength, kick and stamina, how far the player is, and a
-- REBIRTH button once they have it all. RebirthService does the checking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local rebirthFunction = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Rebirth")

local player = Players.LocalPlayer

local RED = Color3.fromRGB(220, 40, 40)
local GREY = Color3.fromRGB(70, 70, 75)
local GREEN = Color3.fromRGB(60, 200, 90)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RebirthGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ==================== THE REBIRTH BUTTON ====================
-- Like the rebirth buttons in other Roblox games: a shiny green rounded square with a thick blue edge,
-- two arrows chasing each other round in a circle (one silver, one red), and REBIRTH written underneath.
-- It grows a little when the mouse is over it and squishes when pressed.
local BUTTON_GREEN = Color3.fromRGB(40, 190, 70)
local BLUE = Color3.fromRGB(30, 110, 255)
local SILVER = Color3.fromRGB(220, 223, 230)

local button = Instance.new("TextButton")
button.Name = "RebirthButton"
button.AnchorPoint = Vector2.new(1, 0.5)
button.Size = UDim2.new(0, 68, 0, 68)
button.Position = UDim2.new(1, -28, 0.5, -170) -- just above the nav column on the right
button.BackgroundColor3 = BUTTON_GREEN
button.Text = ""
button.AutoButtonColor = false
button.Parent = screenGui

local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.25, 0)
round.Parent = button

-- Shiny: lighter at the top, darker at the bottom
local shine = Instance.new("UIGradient")
shine.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 215, 215)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 140)),
})
shine.Rotation = 90
shine.Parent = button

local ring = Instance.new("UIStroke")
ring.Color = BLUE
ring.Thickness = 4
ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ring.Parent = button

-- The two arrows: each is a curve of little pieces around a circle in the upper part of the button
-- (angles clockwise from the top), with an arrowhead at its end pointing the way it goes round
local ARROW_CENTER = Vector2.new(0.5, 0.4) -- of the button's size
local ARROW_RADIUS = 0.22
local function onCircle(angle)
	local radians = math.rad(angle)
	return UDim2.fromScale(ARROW_CENTER.X + ARROW_RADIUS * math.sin(radians), ARROW_CENTER.Y - ARROW_RADIUS * math.cos(radians))
end
local function arrow(fromAngle, toAngle, color)
	for angle = fromAngle, toAngle, 8 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromScale(0.09, 0.08)
		piece.Position = onCircle(angle)
		piece.Rotation = angle
		piece.BackgroundColor3 = color
		piece.BorderSizePixel = 0
		piece.Parent = button
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(30, 30, 30)
		edge.Thickness = 1
		edge.Transparency = 0.5
		edge.Parent = piece
	end
	local head = Instance.new("TextLabel")
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Size = UDim2.fromScale(0.26, 0.26)
	local tip = toAngle + 7
	head.Position = onCircle(tip)
	head.Rotation = tip
	head.BackgroundTransparency = 1
	head.Text = "▶"
	head.TextColor3 = color
	head.TextStrokeTransparency = 0.4
	head.TextScaled = true
	head.Font = Enum.Font.GothamBlack
	head.Parent = button
end
arrow(25, 140, SILVER)
arrow(205, 320, RED)

local word = Instance.new("TextLabel")
word.AnchorPoint = Vector2.new(0.5, 0)
word.Size = UDim2.fromScale(1.15, 0.3)
word.Position = UDim2.fromScale(0.5, 0.68)
word.BackgroundTransparency = 1
word.Text = "REBIRTH"
word.TextColor3 = Color3.new(1, 1, 1)
word.TextStrokeColor3 = Color3.new(0, 0, 0)
word.TextStrokeTransparency = 0
word.TextScaled = true
word.Font = Enum.Font.FredokaOne
word.Parent = button

-- Bounce: bigger when hovered, squished when pressed
local bounce = Instance.new("UIScale")
bounce.Parent = button
local function bounceTo(size)
	TweenService:Create(bounce, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size }):Play()
end
button.MouseEnter:Connect(function()
	bounceTo(1.1)
end)
button.MouseLeave:Connect(function()
	bounceTo(1)
end)
button.MouseButton1Down:Connect(function()
	bounceTo(0.9)
end)
button.MouseButton1Up:Connect(function()
	bounceTo(1.1)
end)

-- ==================== THE PANEL ====================
local panel = Instance.new("Frame")
panel.Name = "RebirthPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, 360, 0, 300)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
panel.BorderSizePixel = 3
panel.BorderColor3 = RED
panel.Visible = false
panel.Parent = screenGui

local function label(text, size, position, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.Parent = panel
	return l
end

local title = label("♻ REBIRTH", UDim2.new(1, -60, 0, 40), UDim2.new(0, 12, 0, 8), RED, Enum.Font.GothamBlack)
title.TextXAlignment = Enum.TextXAlignment.Left
local subtitle = label("", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 52), Color3.fromRGB(200, 200, 200))
local rows = {}
for i = 1, 3 do
	local row = label("", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 84 + (i - 1) * 32))
	row.TextXAlignment = Enum.TextXAlignment.Left
	rows[i] = row
end
local note = label("Rebirthing resets your strength, kick, stamina, wins and beat the game (you keep your money), and gives +1x training for good.",
	UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, 184), Color3.fromRGB(170, 170, 170), Enum.Font.Gotham)
note.TextWrapped = true

local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(1, -24, 0, 44)
rebirthButton.Position = UDim2.new(0, 12, 1, -56)
rebirthButton.Font = Enum.Font.GothamBlack
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.new(1, 1, 1)
rebirthButton.Text = "REBIRTH"
rebirthButton.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 36, 0, 36)
closeButton.Position = UDim2.new(1, -44, 0, 8)
closeButton.BackgroundColor3 = GREY
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.Parent = panel

local canRebirth = false

local function show(info, message)
	if info.rebirths >= info.max then
		subtitle.Text = string.format("MAX REBIRTHS (%d/%d) · training %dx", info.rebirths, info.max, info.multiplier)
		for _, row in ipairs(rows) do
			row.Text = ""
		end
		canRebirth = false
	else
		subtitle.Text = string.format("Rebirth %d of %d · training now %dx", info.rebirths + 1, info.max, info.multiplier)
		local need = info.nextRequirement
		local checks = {
			{ "Strength", info.strength, need.strength },
			{ "Kick", info.kick, need.kick },
			{ "Stamina", info.stamina, need.stamina },
		}
		canRebirth = true
		for i, check in ipairs(checks) do
			local done = check[2] >= check[3]
			canRebirth = canRebirth and done
			rows[i].Text = string.format("%s %s: %s / %s", done and "✅" or "❌", check[1], Catalog.FormatNumber(check[2]), Catalog.FormatNumber(check[3]))
			rows[i].TextColor3 = done and GREEN or Color3.fromRGB(255, 120, 120)
		end
	end
	rebirthButton.BackgroundColor3 = canRebirth and RED or GREY
	rebirthButton.AutoButtonColor = canRebirth
	local boostText = info.rebirths >= info.max and ("You have +" .. Catalog.FormatNumber(info.speedBoost) .. " speed and jump (up to 1000).")
		or ("Next rebirth: +" .. Catalog.FormatNumber(info.nextSpeedBoost) .. " speed and jump (up to 1000), and +1x training. Resets strength, kick, stamina, wins and beat the game (you keep your money).")
	note.Text = message or boostText
end

local function refresh(message)
	local ok, result = pcall(rebirthFunction.InvokeServer, rebirthFunction)
	if ok and result then
		show(result.info, message)
	end
end

button.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end)

closeButton.Activated:Connect(function()
	panel.Visible = false
end)

rebirthButton.Activated:Connect(function()
	if not canRebirth then
		return
	end
	local ok, result = pcall(rebirthFunction.InvokeServer, rebirthFunction, "rebirth")
	if ok and result then
		show(result.info, result.message)
	end
end)
