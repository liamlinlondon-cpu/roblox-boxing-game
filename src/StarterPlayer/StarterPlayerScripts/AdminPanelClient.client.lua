-- The ADMIN button (sparkly rainbow, above the ♻ rebirth button) and its panel: type a number for speed,
-- jump, strength, kick, stamina, rebirths, money, luck, wins or beat the game and press SET to give it to
-- yourself (up to 1 nonillion). Only the owner, and players the owner gave it to with
-- "/give <name> admin panel", get the button; the server (AdminCommandService) checks every change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local adminPanelFunction = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AdminPanel")

local player = Players.LocalPlayer

local ROWS = {
	{ stat = "speed", label = "Speed" },
	{ stat = "jump", label = "Jump" },
	{ stat = "strength", label = "Strength" },
	{ stat = "kick", label = "Kick" },
	{ stat = "stamina", label = "Stamina" },
	{ stat = "rebirths", label = "Rebirths" },
	{ stat = "money", label = "Money" },
	{ stat = "luck", label = "Luck" },
	{ stat = "wins", label = "Wins" },
	{ stat = "beatthegame", label = "Beat the game" },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 150, 30)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 210, 80)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(50, 120, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(160, 70, 230)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
})

local screenGui = nil -- built the first time the player may use the panel

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- ==================== THE ADMIN BUTTON ====================
	local button = Instance.new("TextButton")
	button.Name = "AdminButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Size = UDim2.new(0, 64, 0, 64)
	button.Position = UDim2.new(1, -30, 0.5, -245) -- just above the ♻ rebirth button
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Text = "ADMIN"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.ClipsDescendants = false
	button.Parent = screenGui

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW
	gradient.Parent = button

	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = button

	-- Rainbow spinning round the button and the ring changing color
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		gradient.Rotation = (t * 90) % 360
		ring.Color = Color3.fromHSV((t * 0.4) % 1, 0.8, 1)
	end)

	-- Sparkles popping up around it
	task.spawn(function()
		while screenGui.Parent do
			task.wait(0.2)
			local star = Instance.new("TextLabel")
			star.BackgroundTransparency = 1
			star.Text = "✦"
			star.TextScaled = true
			star.Font = Enum.Font.GothamBold
			star.TextColor3 = Color3.fromHSV(math.random(), 0.7, 1)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Size = UDim2.new(0, 6, 0, 6)
			star.Position = UDim2.new(math.random() * 1.3 - 0.15, 0, math.random() * 1.3 - 0.15, 0)
			star.ZIndex = 3
			star.Parent = button
			local grow = TweenService:Create(star, TweenInfo.new(0.35), { Size = UDim2.new(0, 16, 0, 16), Rotation = 45 })
			grow:Play()
			grow.Completed:Once(function()
				local fade = TweenService:Create(star, TweenInfo.new(0.4), { TextTransparency = 1 })
				fade:Play()
				fade.Completed:Once(function()
					star:Destroy()
				end)
			end)
		end
	end)

	-- ==================== THE PANEL ====================
	local panel = Instance.new("Frame")
	panel.Name = "AdminPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.new(0, 400, 0, 80 + #ROWS * 38)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	local panelRing = Instance.new("UIStroke")
	panelRing.Thickness = 3
	panelRing.Parent = panel
	RunService.RenderStepped:Connect(function()
		panelRing.Color = Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1)
	end)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 34)
	title.Position = UDim2.new(0, 12, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "ADMIN PANEL"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel
	local titleGradient = gradient:Clone()
	titleGradient.Rotation = 0
	titleGradient.Parent = title

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 34, 0, 34)
	close.Position = UDim2.new(1, -42, 0, 6)
	close.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Parent = panel

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -24, 0, 24)
	status.Position = UDim2.new(0, 12, 1, -30)
	status.BackgroundTransparency = 1
	status.Text = "Type a number (up to 1 nonillion) and press SET."
	status.TextColor3 = Color3.fromRGB(200, 200, 200)
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.Parent = panel

	for i, row in ipairs(ROWS) do
		local y = 46 + (i - 1) * 38
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, 110, 0, 30)
		name.Position = UDim2.new(0, 12, 0, y)
		name.BackgroundTransparency = 1
		name.Text = row.label
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = panel

		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -220, 0, 30)
		box.Position = UDim2.new(0, 128, 0, y)
		box.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		box.TextColor3 = Color3.new(1, 1, 1)
		box.PlaceholderText = "number"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.Gotham
		box.TextScaled = true
		box.Parent = panel

		local set = Instance.new("TextButton")
		set.Size = UDim2.new(0, 70, 0, 30)
		set.Position = UDim2.new(1, -82, 0, y)
		set.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
		set.Text = "SET"
		set.TextColor3 = Color3.new(1, 1, 1)
		set.Font = Enum.Font.GothamBold
		set.TextScaled = true
		set.Parent = panel

		local function submit()
			-- Commas and spaces are fine: "1,000,000" or "1 000 000"
			local value = tonumber((string.gsub(box.Text, "[,%s]", "")))
			if not value then
				status.Text = "Type a number for " .. row.label .. "."
				return
			end
			local ok, message = pcall(adminPanelFunction.InvokeServer, adminPanelFunction, row.stat, value)
			status.Text = ok and type(message) == "string" and message or "That didn't work. Try again."
		end
		set.Activated:Connect(submit)
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				submit()
			end
		end)
	end

	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
end

-- Shows or hides the panel's button: the owner always has it, others while they've been given it
local function update()
	local ok, allowed = pcall(adminPanelFunction.InvokeServer, adminPanelFunction)
	allowed = ok and allowed == true
	if allowed and not screenGui then
		build()
	elseif screenGui then
		screenGui.Enabled = allowed
	end
end

update()
player:GetAttributeChangedSignal("HasAdminPanel"):Connect(update)
