-- The owner's rainbow VIP ADMIN panel: a sparkly rainbow VIP button above the ADMIN button opens a big panel with a menu
-- on the left and pages on the right:
--   ⚡ EVENTS    a button for every sky event (and a normal sky), started straight away
--   📊 SETS      the same stat boxes as the ADMIN panel (speed, jump, strength, kick, ...)
--   🗺️ TELEPORT  a map of the whole world from above; click anywhere to teleport there
-- More pages can be added to PAGES. Only the owner gets it; the server checks every action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local events = ReplicatedStorage:WaitForChild("Events")
local adminSkyEvent = events:WaitForChild("AdminSkyEvent")
local adminPanelFunction = events:WaitForChild("AdminPanel")
local teleportFunction = events:WaitForChild("Teleport")

local player = Players.LocalPlayer

-- Only the owner (the server says)
local okCheck, isOwner = pcall(adminSkyEvent.InvokeServer, adminSkyEvent)
if not okCheck or isOwner ~= true then
	return
end

local GOLD = Color3.fromRGB(255, 200, 40)
local DARK = Color3.fromRGB(22, 22, 28)
local WHITE = Color3.new(1, 1, 1)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 150, 30)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 210, 80)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(50, 120, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(160, 70, 230)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
})

-- Everything rainbow: gradients spin, rings and the chosen tab change color
local spinningGradients, colorCycling = {}, {}
local function rainbowGradient(parent, spin)
	local gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW
	gradient.Parent = parent
	if spin then
		table.insert(spinningGradients, gradient)
	end
	return gradient
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, gradient in ipairs(spinningGradients) do
		gradient.Rotation = (t * 90) % 360
	end
	for _, item in ipairs(colorCycling) do
		if item.object then
			item.object[item.property] = Color3.fromHSV((t * 0.35 + (item.offset or 0)) % 1, 0.75, 1)
		end
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VipAdminPanelGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
screenGui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
end

local function text(parent, props)
	local label = Instance.new(props.button and "TextButton" or "TextLabel")
	label.BackgroundTransparency = props.background and 0 or 1
	label.BackgroundColor3 = props.background or DARK
	label.Size = props.size or UDim2.new()
	label.Position = props.position or UDim2.new()
	label.Text = props.text or ""
	label.TextColor3 = props.color or WHITE
	label.Font = props.font or Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

-- ==================== THE VIP BUTTON ====================
local openButton = text(screenGui, {
	button = true,
	text = "VIP",
	size = UDim2.new(0, 64, 0, 64),
	background = WHITE,
	color = WHITE,
	font = Enum.Font.GothamBlack,
})
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -30, 0.5, -320) -- just above the ADMIN button
openButton.TextStrokeTransparency = 0
openButton.ClipsDescendants = false
corner(openButton, UDim.new(0.5, 0))
rainbowGradient(openButton, true)
local openRing = Instance.new("UIStroke")
openRing.Thickness = 4
openRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
openRing.Parent = openButton
table.insert(colorCycling, { object = openRing, property = "Color" })

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
		star.Parent = openButton
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
panel.Name = "VipAdminPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, 720, 0, 440)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = DARK
panel.Visible = false
panel.Parent = screenGui
corner(panel, UDim.new(0, 12))
local panelRing = Instance.new("UIStroke")
panelRing.Thickness = 4
panelRing.Parent = panel
table.insert(colorCycling, { object = panelRing, property = "Color" })
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(720, 440)
sizeLimit.Parent = panel
local scale = Instance.new("UIScale") -- shrinks the panel on small screens
scale.Parent = panel
local function fitToScreen()
	local camera = Workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.min(1, (view.X - 40) / 720, (view.Y - 40) / 440)
end
fitToScreen()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local title = text(panel, { text = "🌈 VIP ADMIN PANEL", size = UDim2.new(1, -70, 0, 40), position = UDim2.new(0, 16, 0, 8), color = WHITE, font = Enum.Font.GothamBlack, alignX = Enum.TextXAlignment.Left })
title.TextStrokeTransparency = 0.4
rainbowGradient(title, false)
local closeButton = text(panel, { button = true, text = "X", size = UDim2.new(0, 36, 0, 36), position = UDim2.new(1, -46, 0, 10), background = Color3.fromRGB(150, 40, 40) })
corner(closeButton)

-- Left: the menu. Right: the page area, with a status line at the bottom.
local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 170, 1, -66)
menu.Position = UDim2.new(0, 12, 0, 56)
menu.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
menu.Parent = panel
corner(menu)
local menuRing = Instance.new("UIStroke")
menuRing.Thickness = 2
menuRing.Parent = menu
table.insert(colorCycling, { object = menuRing, property = "Color", offset = 0.5 })
local menuLayout = Instance.new("UIListLayout")
menuLayout.Padding = UDim.new(0, 8)
menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
menuLayout.Parent = menu
local menuPadding = Instance.new("UIPadding")
menuPadding.PaddingTop = UDim.new(0, 8)
menuPadding.PaddingLeft = UDim.new(0, 8)
menuPadding.PaddingRight = UDim.new(0, 8)
menuPadding.Parent = menu

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -206, 1, -100)
content.Position = UDim2.new(0, 194, 0, 56)
content.BackgroundTransparency = 1
content.Parent = panel

local status = text(panel, { text = "", size = UDim2.new(1, -206, 0, 26), position = UDim2.new(0, 194, 1, -36), color = Color3.fromRGB(200, 200, 200), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })

local function say(message)
	status.Text = message or ""
end

-- ==================== EVENTS PAGE ====================
local function buildEventsPage(page)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 155, 0, 50)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = page

	local choices = {}
	for _, sky in ipairs(Catalog.SkyColors) do
		table.insert(choices, { id = sky.id, name = sky.name, color = sky.color, rainbow = sky.rainbow })
	end
	table.insert(choices, { id = "clear", name = "Normal sky", color = Color3.fromRGB(110, 150, 200) })

	for order, choice in ipairs(choices) do
		local button = text(page, { button = true, text = choice.name, background = choice.color, color = WHITE, font = Enum.Font.GothamBlack })
		button.LayoutOrder = order
		button.TextStrokeTransparency = 0.3
		corner(button)
		if choice.rainbow then
			button.BackgroundColor3 = WHITE
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 40)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(50, 120, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 70, 230)),
			})
			gradient.Parent = button
		end
		button.Activated:Connect(function()
			local ok, message = pcall(adminSkyEvent.InvokeServer, adminSkyEvent, choice.id)
			say(ok and message or "That didn't work. Try again.")
		end)
	end
end

-- ==================== SETS PAGE ====================
local SET_ROWS = {
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

local function buildSetsPage(page)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, row in ipairs(SET_ROWS) do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, -10, 0, 32)
		line.BackgroundTransparency = 1
		line.LayoutOrder = order
		line.Parent = list
		text(line, { text = row.label, size = UDim2.new(0, 120, 1, 0), alignX = Enum.TextXAlignment.Left })
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -210, 1, 0)
		box.Position = UDim2.new(0, 126, 0, 0)
		box.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		box.TextColor3 = WHITE
		box.PlaceholderText = "number"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.Gotham
		box.TextScaled = true
		box.Parent = line
		corner(box, UDim.new(0, 6))
		local set = text(line, { button = true, text = "SET", size = UDim2.new(0, 72, 1, 0), position = UDim2.new(1, -76, 0, 0), background = Color3.fromRGB(60, 160, 80) })
		corner(set, UDim.new(0, 6))
		local function submit()
			local value = tonumber((string.gsub(box.Text, "[,%s]", "")))
			if not value then
				say("Type a number for " .. row.label .. ".")
				return
			end
			local ok, message = pcall(adminPanelFunction.InvokeServer, adminPanelFunction, row.stat, value)
			say(ok and message or "That didn't work. Try again.")
		end
		set.Activated:Connect(submit)
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				submit()
			end
		end)
	end
end

-- ==================== TELEPORT PAGE (MAP) ====================
-- The world from above: the map (420 x 420) and the parkour outside its east wall
local WORLD_MIN = Vector2.new(-215, -215) -- x, z
local WORLD_MAX = Vector2.new(775, 215)

local mapDot = nil
local mapFrame = nil

local function toMap(x, z)
	local size = WORLD_MAX - WORLD_MIN
	return UDim2.fromScale((x - WORLD_MIN.X) / size.X, (z - WORLD_MIN.Y) / size.Y)
end

local function mapBox(parent, x, z, sizeX, sizeZ, color, rotation, round)
	local box = Instance.new("Frame")
	local size = WORLD_MAX - WORLD_MIN
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = toMap(x, z)
	box.Size = UDim2.fromScale(sizeX / size.X, sizeZ / size.Y)
	box.BackgroundColor3 = color
	box.BorderSizePixel = 0
	box.Rotation = rotation or 0
	box.Parent = parent
	if round then
		corner(box, UDim.new(0.5, 0))
	end
	return box
end

local function buildTeleportPage(page)
	local hint = text(page, { text = "Click anywhere on the map to teleport there.", size = UDim2.new(1, 0, 0, 24) })
	table.insert(colorCycling, { object = hint, property = "TextColor3" })

	-- Stretch the map east to the end of the lava, wherever the parkour ends
	local course = Workspace:WaitForChild("BoxingWorld"):WaitForChild("BeatGameCourse", 10)
	local lava = course and course:FindFirstChild("Lava")
	if lava then
		WORLD_MAX = Vector2.new(lava.Position.X + lava.Size.X / 2 + 5, WORLD_MAX.Y)
	end

	-- Keep the map's real shape
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 1, -30)
	holder.Position = UDim2.new(0, 0, 0, 30)
	holder.BackgroundTransparency = 1
	holder.Parent = page

	mapFrame = Instance.new("TextButton")
	mapFrame.Text = ""
	mapFrame.AutoButtonColor = false
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.Position = UDim2.fromScale(0.5, 0.5)
	mapFrame.Size = UDim2.fromScale(1, 1)
	mapFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mapFrame.ClipsDescendants = true
	mapFrame.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	local worldSize = WORLD_MAX - WORLD_MIN
	aspect.AspectRatio = worldSize.X / worldSize.Y
	aspect.Parent = mapFrame
	corner(mapFrame)

	local half = WorldConfig.GroundSize / 2
	mapBox(mapFrame, 0, 0, half * 2, half * 2, Color3.fromRGB(70, 120, 60)) -- the grass
	if lava then -- the lava outside the east wall
		mapBox(mapFrame, lava.Position.X, lava.Position.Z, lava.Size.X, lava.Size.Z, Color3.fromRGB(200, 80, 20))
	end
	mapBox(mapFrame, 0, 0, WorldConfig.Arena.DistrictRadius * 2, WorldConfig.Arena.DistrictRadius * 2, Color3.fromRGB(150, 150, 155), 0, true) -- plaza
	mapBox(mapFrame, 0, 0, 30, 30, Color3.fromRGB(40, 70, 160)) -- the ring

	-- Gyms, with their names
	for i, info in ipairs(WorldConfig.Gyms.List) do
		local cframe = WorldConfig.GetGymCFrame(i)
		local _, yRotation = cframe:ToOrientation()
		local gym = mapBox(mapFrame, cframe.Position.X, cframe.Position.Z, WorldConfig.Gyms.Width, WorldConfig.Gyms.Depth, info.color, -math.deg(yRotation))
		local label = text(gym, { text = info.name, size = UDim2.fromScale(1, 1), color = WHITE })
		label.TextStrokeTransparency = 0.3
		label.Rotation = math.deg(yRotation)
	end

	-- Parkour buildings and the hill, read from the world
	if course then
		for _, part in ipairs(course:GetChildren()) do
			if part:IsA("BasePart") then
				if string.match(part.Name, "^Building%d+%a*$") or string.match(part.Name, "Floor$") then
					mapBox(mapFrame, part.Position.X, part.Position.Z, part.Size.X, part.Size.Z, Color3.fromRGB(120, 120, 130))
				elseif string.match(part.Name, "^HillTier") then
					mapBox(mapFrame, part.Position.X, part.Position.Z, part.Size.Y, part.Size.Z, Color3.fromRGB(76, 140, 60), 0, true)
				end
			end
		end
		local portal = course:FindFirstChild("RedPortal")
		if portal then
			mapBox(mapFrame, portal.Position.X, portal.Position.Z, 10, 10, Color3.fromRGB(255, 40, 40), 0, true)
		end
	end

	-- You
	mapDot = mapBox(mapFrame, 0, 0, 12, 12, GOLD, 0, true)
	mapDot.ZIndex = 5
	local dotRing = Instance.new("UIStroke")
	dotRing.Color = Color3.new(0, 0, 0)
	dotRing.Thickness = 2
	dotRing.Parent = mapDot

	-- Click: teleport there (the server finds the ground or roof at that spot)
	mapFrame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local relative = (Vector2.new(input.Position.X, input.Position.Y) - mapFrame.AbsolutePosition) / mapFrame.AbsoluteSize
		local x = WORLD_MIN.X + relative.X * (WORLD_MAX.X - WORLD_MIN.X)
		local z = WORLD_MIN.Y + relative.Y * (WORLD_MAX.Y - WORLD_MIN.Y)
		local ok, allowed, message = pcall(teleportFunction.InvokeServer, teleportFunction, Vector3.new(x, 0, z), nil, true)
		if ok and allowed then
			say(string.format("Teleported to (%d, %d).", x, z))
		else
			say(ok and message or "That didn't work. Try again.")
		end
	end)
end

-- Keep your dot on the map while the panel is open
RunService.Heartbeat:Connect(function()
	if not panel.Visible or not mapDot then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		mapDot.Position = toMap(root.Position.X, root.Position.Z)
	end
end)

-- ==================== MENU ====================
local PAGES = { -- add more pages here later
	{ name = "⚡ EVENTS", build = buildEventsPage },
	{ name = "📊 SETS", build = buildSetsPage },
	{ name = "🗺️ TELEPORT", build = buildTeleportPage },
}

local pageFrames, menuButtons = {}, {}
local chosenTab = { property = "BackgroundColor3" } -- the open page's tab glows rainbow
table.insert(colorCycling, chosenTab)

local function showPage(index)
	for i, frame in ipairs(pageFrames) do
		frame.Visible = i == index
		menuButtons[i].BackgroundColor3 = Color3.fromRGB(55, 55, 65)
		menuButtons[i].TextColor3 = i == index and Color3.new(0, 0, 0) or WHITE
	end
	chosenTab.object = menuButtons[index]
	say("")
end

for i, page in ipairs(PAGES) do
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = content
	page.build(frame)
	pageFrames[i] = frame

	local button = text(menu, { button = true, text = page.name, size = UDim2.new(1, 0, 0, 46), background = Color3.fromRGB(55, 55, 65) })
	button.LayoutOrder = i
	corner(button)
	button.Activated:Connect(function()
		showPage(i)
	end)
	menuButtons[i] = button
end
showPage(1)

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
