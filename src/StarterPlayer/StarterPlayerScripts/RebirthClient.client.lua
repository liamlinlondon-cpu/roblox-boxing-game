-- The round ♻ rebirth button (grey with a red ring) on the right, above the nav buttons. Pressing it
-- opens the rebirth panel: the next rebirth's strength, kick and stamina, how far the player is, and a
-- REBIRTH button once they have it all. RebirthService does the checking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- ==================== THE ♻ BUTTON ====================
local button = Instance.new("TextButton")
button.Name = "RebirthButton"
button.AnchorPoint = Vector2.new(1, 0.5)
button.Size = UDim2.new(0, 64, 0, 64)
button.Position = UDim2.new(1, -30, 0.5, -170) -- just above the nav column on the right
button.BackgroundColor3 = GREY
button.Text = "♻"
button.TextColor3 = RED
button.Font = Enum.Font.GothamBlack
button.TextScaled = true
button.Parent = screenGui

local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = button

local ring = Instance.new("UIStroke")
ring.Color = RED
ring.Thickness = 4
ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ring.Parent = button

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
