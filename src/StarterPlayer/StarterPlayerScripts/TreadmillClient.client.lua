-- Treadmill run panel: lap progress, AUTO RUN toggle and STOP. FlowService runs the laps and pays the stamina.
-- Locked treadmills show an unlock panel instead; payment (money or Robux) goes through StoreService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local treadmillEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreadmillControl")
local storeEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("StoreAction")

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 215, 0)
local ON_COLOR = Color3.fromRGB(40, 140, 70)
local OFF_COLOR = Color3.fromRGB(90, 90, 90)

local autoRun = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TreadmillGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "TreadmillPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Size = UDim2.new(0.34, 0, 0.2, 0)
panel.Position = UDim2.new(0.5, 0, 1, -16)
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 2
panel.BorderColor3 = GOLD
panel.Visible = false
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 150)
sizeConstraint.MaxSize = Vector2.new(520, 220)
sizeConstraint.Parent = panel

local function makeLabel(size, position, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = panel
	return label
end

local function makeButton(text, size, position, color)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 2
	button.BorderColor3 = GOLD
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = panel
	return button
end

local title = makeLabel(UDim2.new(0.94, 0, 0.18, 0), UDim2.new(0.03, 0, 0.05, 0), GOLD)
local statusLabel = makeLabel(UDim2.new(0.94, 0, 0.15, 0), UDim2.new(0.03, 0, 0.27, 0), Color3.fromRGB(200, 200, 200))

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(0.94, 0, 0.1, 0)
barBack.Position = UDim2.new(0.03, 0, 0.47, 0)
barBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
barBack.BorderSizePixel = 0
barBack.Parent = panel

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = ON_COLOR
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local autoButton = makeButton("", UDim2.new(0.45, 0, 0.26, 0), UDim2.new(0.03, 0, 0.67, 0), OFF_COLOR)
local stopButton = makeButton("STOP", UDim2.new(0.45, 0, 0.26, 0), UDim2.new(0.52, 0, 0.67, 0), Color3.fromRGB(150, 40, 40))

local barTween = nil

local function refreshAuto()
	autoButton.Text = autoRun and "AUTO RUN: ON" or "AUTO RUN: OFF"
	autoButton.BackgroundColor3 = autoRun and ON_COLOR or OFF_COLOR
end

autoButton.Activated:Connect(function()
	autoRun = not autoRun
	refreshAuto()
	treadmillEvent:FireServer("auto", autoRun)
end)

stopButton.Activated:Connect(function()
	treadmillEvent:FireServer("stop")
end)

-- ==================== UNLOCK PANEL ====================
local unlockPanel = panel:Clone()
unlockPanel.Name = "TreadmillUnlockPanel"
unlockPanel:ClearAllChildren()
unlockPanel.Parent = screenGui
sizeConstraint:Clone().Parent = unlockPanel

local function addTo(parent, instance)
	instance.Parent = parent
	return instance
end

local unlockTitle = addTo(unlockPanel, makeLabel(UDim2.new(0.94, 0, 0.18, 0), UDim2.new(0.03, 0, 0.05, 0), GOLD))
local unlockStatus = addTo(unlockPanel, makeLabel(UDim2.new(0.94, 0, 0.2, 0), UDim2.new(0.03, 0, 0.3, 0), Color3.fromRGB(200, 200, 200)))
unlockStatus.TextWrapped = true
local payMoneyButton = addTo(unlockPanel, makeButton("", UDim2.new(0.35, 0, 0.3, 0), UDim2.new(0.03, 0, 0.62, 0), ON_COLOR))
local payRobuxButton = addTo(unlockPanel, makeButton("", UDim2.new(0.35, 0, 0.3, 0), UDim2.new(0.4, 0, 0.62, 0), Color3.fromRGB(75, 110, 180)))
local cancelButton = addTo(unlockPanel, makeButton("CANCEL", UDim2.new(0.2, 0, 0.3, 0), UDim2.new(0.77, 0, 0.62, 0), OFF_COLOR))

local pendingUnlock = nil -- { itemId, name, money, robux, playerMoney }

local function refreshUnlock()
	if not pendingUnlock then
		return
	end
	local canAfford = pendingUnlock.playerMoney >= pendingUnlock.money
	unlockTitle.Text = string.upper(pendingUnlock.name) .. " IS LOCKED"
	unlockStatus.Text = string.format("Unlock it once to run on it forever. You have %s money.", Catalog.FormatNumber(pendingUnlock.playerMoney))
	payMoneyButton.Text = "PAY " .. Catalog.FormatNumber(pendingUnlock.money) .. " MONEY"
	payMoneyButton.BackgroundColor3 = canAfford and ON_COLOR or OFF_COLOR
	payRobuxButton.Text = "PAY " .. Catalog.FormatNumber(pendingUnlock.robux) .. " R$"
end

payMoneyButton.Activated:Connect(function()
	if pendingUnlock then
		storeEvent:FireServer("buy", pendingUnlock.itemId, "money")
	end
end)

payRobuxButton.Activated:Connect(function()
	if pendingUnlock then
		storeEvent:FireServer("buy", pendingUnlock.itemId, "robux")
	end
end)

cancelButton.Activated:Connect(function()
	pendingUnlock = nil
	unlockPanel.Visible = false
end)

storeEvent.OnClientEvent:Connect(function(action, text, success, state)
	if action ~= "notice" or not pendingUnlock or not unlockPanel.Visible then
		return
	end
	if state then
		pendingUnlock.playerMoney = state.money
	end
	refreshUnlock()
	unlockStatus.Text = text
	if success then
		unlockStatus.Text = text .. " Hold E on the treadmill to run."
		local unlocked = pendingUnlock
		task.delay(2.5, function()
			if pendingUnlock == unlocked then
				pendingUnlock = nil
				unlockPanel.Visible = false
			end
		end)
	end
end)

treadmillEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "locked" then
		pendingUnlock = info
		refreshUnlock()
		unlockPanel.Visible = true
	elseif kind == "start" then
		unlockPanel.Visible = false
		autoRun = info.auto
		title.Text = string.upper(info.tierName)
		statusLabel.Text = autoRun and "Auto-running: laps repeat until you press STOP." or "Running one lap. Turn AUTO RUN on to keep going."
		refreshAuto()
		panel.Visible = true
	elseif kind == "lapStart" then
		if barTween then
			barTween:Cancel()
		end
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barTween = TweenService:Create(barFill, TweenInfo.new(info, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) })
		barTween:Play()
	elseif kind == "lap" then
		statusLabel.Text = string.format(
			"Lap %d done: +%s stamina. Max stamina %s",
			info.laps,
			Catalog.FormatNumber(info.gain),
			Catalog.FormatNumber(info.maxStamina)
		)
	elseif kind == "stop" then
		if barTween then
			barTween:Cancel()
			barTween = nil
		end
		panel.Visible = false
	end
end)

refreshAuto()
