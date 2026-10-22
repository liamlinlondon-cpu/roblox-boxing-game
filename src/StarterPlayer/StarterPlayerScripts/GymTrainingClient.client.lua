-- Punching bag training panel and punch visuals. The server (FlowService) runs the punches and awards power;
-- this script shows the options, plays the arm/bag animations and pops up the gains.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))
local trainingEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("GymTraining")

local player = Players.LocalPlayer
local TRAINING = WorldConfig.Training

local GOLD = Color3.fromRGB(255, 215, 0)
local BUTTON_COLOR = Color3.fromRGB(75, 110, 180)
local SELECTED_COLOR = Color3.fromRGB(190, 150, 20)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 70)

local selectedCount = TRAINING.PunchCounts[1]
local selectedWeight = 1
local autoTrain = false
local running = false
local strength = 0
local isVip = false

-- ==================== PUNCH ANIMATION ====================
-- Procedural: swings the shoulder joint forward and back, so no animation asset upload is needed.
-- The joint's C0 can't be tweened on current rigs, so the punch is layered onto the joint's Transform
-- every frame in PreSimulation, which runs after the Animator has applied the idle/walk animation.

local PUNCH_OUT = 0.08
local PUNCH_BACK = 0.18

local activePunches = {} -- [joint] = { rotation, startTime }
local restBagCFrame = setmetatable({}, { __mode = "k" })

RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for joint, punch in pairs(activePunches) do
		local elapsed = now - punch.startTime
		if not joint.Parent or elapsed >= PUNCH_OUT + PUNCH_BACK then
			activePunches[joint] = nil
		else
			local alpha = elapsed < PUNCH_OUT and elapsed / PUNCH_OUT or 1 - (elapsed - PUNCH_OUT) / PUNCH_BACK
			joint.Transform = joint.Transform * CFrame.new():Lerp(punch.rotation, alpha)
		end
	end
end)

local function getShoulder(character, side)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local upperArm = character:FindFirstChild(side .. "UpperArm")
		return upperArm and upperArm:FindFirstChild(side .. "Shoulder"), CFrame.Angles(math.rad(90), 0, 0)
	end
	local torso = character:FindFirstChild("Torso")
	local angle = side == "Right" and 90 or -90
	return torso and torso:FindFirstChild(side .. " Shoulder"), CFrame.Angles(0, 0, math.rad(angle))
end

local function animatePunch(character, side)
	local joint, punchRotation = getShoulder(character, side)
	if joint then
		activePunches[joint] = { rotation = punchRotation, startTime = os.clock() }
	end
end

local function swingBag(bag, character, lbs)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	restBagCFrame[bag] = restBagCFrame[bag] or bag.CFrame
	local rest = restBagCFrame[bag]

	local push = ((rest.Position - root.Position) * Vector3.new(1, 0, 1)).Unit * (0.25 + lbs / 150)
	local hit = TweenService:Create(bag, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rest + push })
	hit:Play()
	hit.Completed:Once(function()
		TweenService:Create(bag, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest }):Play()
	end)
end

local function popGain(part, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "+" .. amount .. " POWER"
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.8, function()
		billboard:Destroy()
	end)
end

-- ==================== PANEL ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GymTrainingGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5 -- draw above the other HUD panels
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "TrainingPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Size = UDim2.new(0.42, 0, 0.3, 0)
panel.Position = UDim2.new(0.5, 0, 1, -110) -- raised so the buttons clear the bottom-of-screen controls
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 2
panel.BorderColor3 = GOLD
panel.Visible = false
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(360, 230)
sizeConstraint.MaxSize = Vector2.new(620, 330)
sizeConstraint.Parent = panel

local function makeLabel(text, size, position, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel
	return label
end

local function makeButton(parent, text, size, position, color)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color or BUTTON_COLOR
	button.BorderSizePixel = 2
	button.BorderColor3 = GOLD
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = parent
	return button
end

local function makeRow(y)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(0.72, 0, 0.17, 0)
	row.Position = UDim2.new(0.25, 0, y, 0)
	row.BackgroundTransparency = 1
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row
	return row
end

local title = makeLabel("PUNCHING BAG", UDim2.new(0.6, 0, 0.13, 0), UDim2.new(0.03, 0, 0.03, 0), GOLD)
local strengthLabel = makeLabel("", UDim2.new(0.34, 0, 0.1, 0), UDim2.new(0.63, 0, 0.05, 0))
strengthLabel.TextXAlignment = Enum.TextXAlignment.Right

makeLabel("Punches", UDim2.new(0.2, 0, 0.12, 0), UDim2.new(0.03, 0, 0.22, 0))
local countRow = makeRow(0.2)
makeLabel("Power", UDim2.new(0.2, 0, 0.12, 0), UDim2.new(0.03, 0, 0.42, 0))
local weightRow = makeRow(0.4)

local MANUAL_HINT = "Click or press 0 to punch, or turn AUTO on."

local progressLabel = makeLabel(MANUAL_HINT, UDim2.new(0.94, 0, 0.1, 0), UDim2.new(0.03, 0, 0.6, 0), Color3.fromRGB(200, 200, 200))

local autoButton = makeButton(panel, "AUTO: OFF", UDim2.new(0.28, 0, 0.18, 0), UDim2.new(0.03, 0, 0.77, 0), Color3.fromRGB(90, 90, 90))
local punchButton = makeButton(panel, "PUNCH", UDim2.new(0.36, 0, 0.18, 0), UDim2.new(0.33, 0, 0.77, 0), Color3.fromRGB(40, 140, 70))
local leaveButton = makeButton(panel, "LEAVE", UDim2.new(0.28, 0, 0.18, 0), UDim2.new(0.69, 0, 0.77, 0), Color3.fromRGB(150, 40, 40))

local countButtons = {}
for index, count in ipairs(TRAINING.PunchCounts) do
	local button = makeButton(countRow, tostring(count), UDim2.new((1 - 0.02 * (#TRAINING.PunchCounts - 1)) / #TRAINING.PunchCounts, 0, 1, 0), UDim2.new())
	button.LayoutOrder = index
	countButtons[count] = button
end

local weightButtons = {}
for index in ipairs(TRAINING.Weights) do
	local button = makeButton(weightRow, "", UDim2.new((1 - 0.02 * (#TRAINING.Weights - 1)) / #TRAINING.Weights, 0, 1, 0), UDim2.new())
	button.LayoutOrder = index
	weightButtons[index] = button
end

local function gainPerPunch(weight)
	return weight.power * (isVip and TRAINING.VipMultiplier or 1)
end

local function refresh()
	title.Text = isVip and "VIP PUNCHING BAG" or "PUNCHING BAG"
	strengthLabel.Text = "Strength: " .. strength

	for count, button in pairs(countButtons) do
		button.BackgroundColor3 = count == selectedCount and SELECTED_COLOR or BUTTON_COLOR
		button.AutoButtonColor = not running
	end

	for index, weight in ipairs(TRAINING.Weights) do
		local button = weightButtons[index]
		if strength < weight.requiredStrength then
			button.Text = weight.lbs .. " lbs\n🔒 " .. weight.requiredStrength .. " STR"
			button.BackgroundColor3 = LOCKED_COLOR
		else
			button.Text = weight.lbs .. " lbs\n+" .. gainPerPunch(weight) .. "/punch"
			button.BackgroundColor3 = index == selectedWeight and SELECTED_COLOR or BUTTON_COLOR
		end
	end

	autoButton.Text = autoTrain and "AUTO: ON" or "AUTO: OFF"
	autoButton.BackgroundColor3 = autoTrain and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(90, 90, 90)
	punchButton.Text = autoTrain and "AUTO PUNCHING" or "PUNCH (0)"
	punchButton.BackgroundColor3 = autoTrain and LOCKED_COLOR or Color3.fromRGB(40, 140, 70)
	punchButton.AutoButtonColor = not autoTrain
end

-- Manual mode: one punch per press. The server limits how fast punches land.
local function throwPunch()
	if panel.Visible and not autoTrain then
		trainingEvent:FireServer("punch", selectedCount, selectedWeight)
	end
end

local function setAuto(enabled)
	autoTrain = enabled
	if enabled then
		running = true
		progressLabel.Text = "Auto-training..."
		trainingEvent:FireServer("start", selectedCount, selectedWeight, true)
	else
		if running then
			trainingEvent:FireServer("stop")
		end
		running = false
		progressLabel.Text = MANUAL_HINT
	end
	refresh()
end

for count, button in pairs(countButtons) do
	button.Activated:Connect(function()
		if not running then
			selectedCount = count
			refresh()
		end
	end)
end

for index, button in ipairs(weightButtons) do
	button.Activated:Connect(function()
		if not running and strength >= TRAINING.Weights[index].requiredStrength then
			selectedWeight = index
			refresh()
		end
	end)
end

autoButton.Activated:Connect(function()
	setAuto(not autoTrain)
end)

punchButton.Activated:Connect(throwPunch)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Zero
		or input.KeyCode == Enum.KeyCode.KeypadZero
		or input.KeyCode == Enum.KeyCode.ButtonR2
	then
		throwPunch()
	end
end)

leaveButton.Activated:Connect(function()
	trainingEvent:FireServer("leave")
end)

-- ==================== SERVER EVENTS ====================
trainingEvent.OnClientEvent:Connect(function(kind, ...)
	if kind == "open" then
		local info = ...
		isVip = info.isVip
		strength = info.strength
		running = false
		autoTrain = false
		-- Fall back to the heaviest unlocked weight if the remembered one is locked
		while selectedWeight > 1 and strength < TRAINING.Weights[selectedWeight].requiredStrength do
			selectedWeight -= 1
		end
		progressLabel.Text = MANUAL_HINT
		panel.Visible = true
		refresh()
	elseif kind == "close" then
		panel.Visible = false
		running = false
		autoTrain = false
	elseif kind == "punch" then
		local character, bag, side, lbs = ...
		if character and bag then
			swingBag(bag, character, lbs)
			animatePunch(character, side)
		end
	elseif kind == "progress" then
		local info = ...
		strength = info.strength
		progressLabel.Text = string.format("Punch %d/%d   ·   +%d power this set", info.punch, info.total, info.gained)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			popGain(root, info.gain)
		end
		refresh()
	elseif kind == "setComplete" then
		local info = ...
		strength = info.strength
		if info.auto then
			progressLabel.Text = string.format("Set done: +%d power. Next set starting...", info.gained)
		else
			progressLabel.Text = string.format("Set complete! +%d power. Strength is now %d.", info.gained, info.strength)
		end
		refresh()
	elseif kind == "stopped" then
		running = false
		refresh()
	elseif kind == "notice" then
		running = false
		autoTrain = false
		progressLabel.Text = ...
		refresh()
	end
end)
