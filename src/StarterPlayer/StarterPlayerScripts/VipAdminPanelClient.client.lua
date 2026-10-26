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
local wheelFunction = events:WaitForChild("HulkWheel")
local wheelNotice = events:WaitForChild("HulkWheelNotice")

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
-- A real picture of the world from straight above: the map, gyms, boxing ring, leaderboards, and the
-- lava, buildings and hill of the beat-the-game parkour outside the east wall. It's a copy of the world
-- in a ViewportFrame, filmed by a camera high up looking down. Clicking sends a ray from that camera
-- into the real world, so you land on whatever you clicked (a roof, the hill, the ground).
local MAP_SOURCES = { "BoxingWorld", "BoxingArena", "Leaderboards" }
local CAMERA_HEIGHT = 5000 -- very high with a narrow lens, so the picture is almost flat
local REMOVE_FROM_COPY = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "ParticleEmitter", "Light", "LayerCollector", "Beam", "Trail", "Fire", "Smoke", "Sparkles" }

local WORLD_MIN = Vector2.new(-215, -215) -- x, z
local WORLD_MAX = Vector2.new(775, 215)

local mapDot = nil

local function toMap(x, z)
	local size = WORLD_MAX - WORLD_MIN
	return UDim2.fromScale((x - WORLD_MIN.X) / size.X, (z - WORLD_MIN.Y) / size.Y)
end

local function worldCenter()
	local middle = (WORLD_MIN + WORLD_MAX) / 2
	return Vector3.new(middle.X, CAMERA_HEIGHT, middle.Y)
end

local refreshMap = nil -- set by buildTeleportPage; called whenever the page opens

local function buildTeleportPage(page)
	local hint = text(page, { text = "Click anywhere on the map to teleport there.", size = UDim2.new(1, 0, 0, 24) })
	table.insert(colorCycling, { object = hint, property = "TextColor3" })

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 1, -30)
	holder.Position = UDim2.new(0, 0, 0, 30)
	holder.BackgroundTransparency = 1
	holder.Parent = page

	-- Keeps the world's real shape
	local mapFrame = Instance.new("Frame")
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.Position = UDim2.fromScale(0.5, 0.5)
	mapFrame.Size = UDim2.fromScale(1, 1)
	mapFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mapFrame.ClipsDescendants = true
	mapFrame.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = mapFrame
	corner(mapFrame)
	local mapRing = Instance.new("UIStroke")
	mapRing.Thickness = 2
	mapRing.Parent = mapFrame
	table.insert(colorCycling, { object = mapRing, property = "Color", offset = 0.25 })

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(110, 160, 210)
	viewport.Ambient = Color3.fromRGB(170, 170, 170)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = mapFrame
	corner(viewport)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Name tags on top of the picture
	local tags = Instance.new("Frame")
	tags.Size = UDim2.fromScale(1, 1)
	tags.BackgroundTransparency = 1
	tags.ZIndex = 2
	tags.Parent = mapFrame
	local function tag(name, x, z)
		local label = text(tags, { text = name, size = UDim2.new(0, 110, 0, 16) })
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = toMap(x, z)
		label.TextStrokeTransparency = 0.2
		label.ZIndex = 3
		label:SetAttribute("WorldX", x)
		label:SetAttribute("WorldZ", z)
	end
	for i, info in ipairs(WorldConfig.Gyms.List) do
		local position = WorldConfig.GetGymCFrame(i).Position
		tag(info.name, position.X, position.Z)
	end
	tag("🥊 Boxing Ring", WorldConfig.Arena.Center.X, WorldConfig.Arena.Center.Z + 20)
	local center = WorldConfig.Arena.Center + WorldConfig.Leaderboards.Position
	tag("🏆 Leaderboards", center.X - 8, center.Z)
	local parkourTag = text(tags, { text = "🔥 Beat the Game", size = UDim2.new(0, 130, 0, 18) })
	parkourTag.AnchorPoint = Vector2.new(0.5, 0)
	parkourTag.TextStrokeTransparency = 0.2
	parkourTag.ZIndex = 3

	-- You
	local size = WORLD_MAX - WORLD_MIN
	mapDot = Instance.new("Frame")
	mapDot.AnchorPoint = Vector2.new(0.5, 0.5)
	mapDot.Size = UDim2.new(0, 12, 0, 12)
	mapDot.BackgroundColor3 = GOLD
	mapDot.ZIndex = 5
	mapDot.Parent = mapFrame
	corner(mapDot, UDim.new(0.5, 0))
	local dotRing = Instance.new("UIStroke")
	dotRing.Color = Color3.new(0, 0, 0)
	dotRing.Thickness = 2
	dotRing.Parent = mapDot

	-- Copies the world into the picture again (things far away may only load in later)
	local lastRefresh = -math.huge
	refreshMap = function()
		if os.clock() - lastRefresh < 5 then
			return
		end
		lastRefresh = os.clock()
		viewport:ClearAllChildren()
		camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		-- Stretch the map east to the end of the lava, wherever the parkour ends
		local world = Workspace:FindFirstChild("BoxingWorld")
		local course = world and world:FindFirstChild("BeatGameCourse")
		local lava = course and course:FindFirstChild("Lava")
		if lava then
			WORLD_MAX = Vector2.new(lava.Position.X + lava.Size.X / 2 + 5, WORLD_MAX.Y)
			parkourTag.Position = toMap(lava.Position.X, WORLD_MIN.Y + 4)
		else
			parkourTag.Position = toMap((WorldConfig.GroundSize / 2 + WORLD_MAX.X) / 2, WORLD_MIN.Y + 4)
		end
		size = WORLD_MAX - WORLD_MIN
		aspect.AspectRatio = size.X / size.Y
		for _, label in ipairs(tags:GetChildren()) do
			if label:GetAttribute("WorldX") then
				label.Position = toMap(label:GetAttribute("WorldX"), label:GetAttribute("WorldZ"))
			end
		end

		-- Camera straight above the middle, looking down (top of the picture is north, -Z)
		camera.CFrame = CFrame.new(worldCenter()) * CFrame.Angles(-math.pi / 2, 0, 0)
		camera.FieldOfView = math.deg(2 * math.atan((size.Y / 2) / CAMERA_HEIGHT))

		for _, name in ipairs(MAP_SOURCES) do
			local source = Workspace:FindFirstChild(name)
			if source then
				local wasArchivable = source.Archivable
				source.Archivable = true
				local ok, copy = pcall(source.Clone, source)
				source.Archivable = wasArchivable
				if ok and copy then
					for _, item in ipairs(copy:GetDescendants()) do
						for _, className in ipairs(REMOVE_FROM_COPY) do
							if item:IsA(className) then
								item:Destroy()
								break
							end
						end
					end
					copy.Parent = viewport
				end
			end
		end
	end

	-- Click: teleport to what's under that spot in the picture
	local clickLayer = Instance.new("TextButton")
	clickLayer.Text = ""
	clickLayer.BackgroundTransparency = 1
	clickLayer.Size = UDim2.fromScale(1, 1)
	clickLayer.ZIndex = 10
	clickLayer.Parent = mapFrame
	clickLayer.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local relative = (Vector2.new(input.Position.X, input.Position.Y) - mapFrame.AbsolutePosition) / mapFrame.AbsoluteSize
		local ground = Vector3.new(WORLD_MIN.X + relative.X * size.X, 0, WORLD_MIN.Y + relative.Y * size.Y)

		-- Follow the camera's line of sight down into the real world to find the roof or ground clicked
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local from = worldCenter()
		local hit = Workspace:Raycast(from, (ground - from).Unit * (CAMERA_HEIGHT + 200), params)
		local target = hit and hit.Position or ground

		local ok, allowed, message = pcall(teleportFunction.InvokeServer, teleportFunction, Vector3.new(target.X, 0, target.Z), nil, true)
		if ok and allowed then
			say(string.format("Teleported to (%d, %d).", target.X, target.Z))
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

-- ==================== MESSAGES PAGE ====================
-- Chats from players (HulkWheelService), from any server: the list on the left, the open chat on the
-- right with a reply box and buttons to join their server, reset their Hulk Wheel, or finish the chat.
local refreshMessages = nil -- set by buildMessagesPage
local newMessageDot = nil -- red dot on the VIP button while there are unread messages

local function buildMessagesPage(page)
	local chats = Instance.new("ScrollingFrame")
	chats.Size = UDim2.new(0, 170, 1, 0)
	chats.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
	chats.BorderSizePixel = 0
	chats.ScrollBarThickness = 4
	chats.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chats.CanvasSize = UDim2.new()
	chats.Parent = page
	corner(chats)
	local chatsLayout = Instance.new("UIListLayout")
	chatsLayout.Padding = UDim.new(0, 4)
	chatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatsLayout.Parent = chats

	local right = Instance.new("Frame")
	right.Size = UDim2.new(1, -180, 1, 0)
	right.Position = UDim2.new(0, 180, 0, 0)
	right.BackgroundTransparency = 1
	right.Parent = page

	local heading = text(right, { text = "Pick a chat on the left.", size = UDim2.new(1, 0, 0, 22), alignX = Enum.TextXAlignment.Left })
	local whereLabel = text(right, { text = "", size = UDim2.new(1, 0, 0, 18), position = UDim2.new(0, 0, 0, 22), color = Color3.fromRGB(180, 180, 190), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })

	local lines = Instance.new("ScrollingFrame")
	lines.Size = UDim2.new(1, 0, 1, -128)
	lines.Position = UDim2.new(0, 0, 0, 44)
	lines.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
	lines.BorderSizePixel = 0
	lines.ScrollBarThickness = 4
	lines.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lines.CanvasSize = UDim2.new()
	lines.Parent = right
	corner(lines)
	local linesLayout = Instance.new("UIListLayout")
	linesLayout.Padding = UDim.new(0, 4)
	linesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	linesLayout.Parent = lines
	local linesPadding = Instance.new("UIPadding")
	linesPadding.PaddingTop = UDim.new(0, 4)
	linesPadding.PaddingLeft = UDim.new(0, 6)
	linesPadding.PaddingRight = UDim.new(0, 6)
	linesPadding.Parent = lines

	local actions = Instance.new("Frame")
	actions.Size = UDim2.new(1, 0, 0, 34)
	actions.Position = UDim2.new(0, 0, 1, -78)
	actions.BackgroundTransparency = 1
	actions.Parent = right
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.Padding = UDim.new(0, 6)
	actionsLayout.Parent = actions
	local function actionButton(label, color)
		local button = text(actions, { button = true, text = label, size = UDim2.new(1 / 3, -4, 1, 0), background = color })
		corner(button, UDim.new(0, 6))
		return button
	end
	local joinButton = actionButton("🚀 Join them", Color3.fromRGB(50, 90, 200))
	local resetButton = actionButton("🔄 Reset wheel", Color3.fromRGB(40, 160, 70))
	local doneButton = actionButton("🗑 Done", Color3.fromRGB(120, 50, 50))

	local replyBox = Instance.new("TextBox")
	replyBox.Size = UDim2.new(1, -86, 0, 36)
	replyBox.Position = UDim2.new(0, 0, 1, -38)
	replyBox.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	replyBox.TextColor3 = WHITE
	replyBox.PlaceholderText = "Write back... (e.g. what's your private server?)"
	replyBox.Text = ""
	replyBox.ClearTextOnFocus = false
	replyBox.TextScaled = true
	replyBox.Font = Enum.Font.Gotham
	replyBox.Parent = right
	corner(replyBox, UDim.new(0, 6))
	local sendButton = text(right, { button = true, text = "SEND", size = UDim2.new(0, 80, 0, 36), position = UDim2.new(1, -80, 1, -38), background = Color3.fromRGB(50, 90, 200) })
	corner(sendButton, UDim.new(0, 6))

	local openUserId = nil

	local function clear(frame)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function showChat(userId, name)
		openUserId = userId
		heading.Text = "💬 " .. (name or ("Player " .. userId))
		whereLabel.Text = "Loading..."
		clear(lines)
		local ok, chat = pcall(wheelFunction.InvokeServer, wheelFunction, "open", userId)
		if openUserId ~= userId then
			return
		end
		if not ok or type(chat) ~= "table" then
			whereLabel.Text = "This chat can't load right now."
			return
		end
		local where = chat.where
		if not where then
			whereLabel.Text = "📍 Not sure where they are."
		elseif where.private then
			whereLabel.Text = "📍 In " .. (where.privateOwner and (where.privateOwner .. "'s ") or "a ") .. "private server (ask them to let you in)"
		else
			whereLabel.Text = "📍 In a public server (Join them works)"
		end
		for order, line in ipairs(chat.lines or {}) do
			local label = text(lines, {
				text = (line.owner and "👑 You: " or "💬 ") .. line.text,
				size = UDim2.new(1, 0, 0, 0),
				color = line.owner and GOLD or WHITE,
				font = Enum.Font.Gotham,
				alignX = Enum.TextXAlignment.Left,
			})
			label.TextScaled = false
			label.TextSize = 15
			label.TextWrapped = true
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.LayoutOrder = order
		end
		task.defer(function()
			lines.CanvasPosition = Vector2.new(0, 1e6)
		end)
	end

	refreshMessages = function()
		local ok, list = pcall(wheelFunction.InvokeServer, wheelFunction, "inbox")
		clear(chats)
		if not ok or type(list) ~= "table" then
			say("Messages can't load right now (in Studio, turn on API access).")
			return
		end
		local unread = 0
		for order, item in ipairs(list) do
			local row = text(chats, {
				button = true,
				text = (item.unread and "🔴 " or "") .. (item.name or "?") .. "\n" .. (item.preview or ""),
				size = UDim2.new(1, -4, 0, 44),
				background = item.userId == openUserId and Color3.fromRGB(70, 70, 90) or Color3.fromRGB(45, 45, 55),
				font = item.unread and Enum.Font.GothamBold or Enum.Font.Gotham,
				alignX = Enum.TextXAlignment.Left,
			})
			row.TextScaled = false
			row.TextSize = 13
			row.TextWrapped = true
			row.TextTruncate = Enum.TextTruncate.AtEnd
			row.LayoutOrder = order
			corner(row, UDim.new(0, 6))
			row.Activated:Connect(function()
				showChat(item.userId, item.name)
				refreshMessages()
			end)
			if item.unread then
				unread += 1
			end
		end
		if #list == 0 then
			text(chats, { text = "No messages yet.", size = UDim2.new(1, 0, 0, 30), color = Color3.fromRGB(170, 170, 170), font = Enum.Font.Gotham })
		end
		if newMessageDot then
			newMessageDot.Visible = unread > 0
		end
		if openUserId then
			showChat(openUserId, string.match(heading.Text, "^💬 (.+)$"))
		end
	end

	local function act(action, extra)
		if not openUserId then
			say("Pick a chat first.")
			return nil
		end
		local ok, answer = pcall(wheelFunction.InvokeServer, wheelFunction, action, openUserId, extra)
		if not ok then
			say("That didn't work. Try again.")
			return nil
		end
		return answer
	end

	local function sendReply()
		if not string.find(replyBox.Text, "%S") then
			return
		end
		local answer = act("reply", replyBox.Text)
		if answer == true then
			replyBox.Text = ""
			say("Sent!")
			refreshMessages()
		elseif answer then
			say(tostring(answer))
		end
	end
	sendButton.Activated:Connect(sendReply)
	replyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendReply()
		end
	end)
	joinButton.Activated:Connect(function()
		local answer = act("join")
		if answer then
			say(tostring(answer))
		end
	end)
	resetButton.Activated:Connect(function()
		local answer = act("reset")
		if answer then
			say(tostring(answer))
		end
	end)
	doneButton.Activated:Connect(function()
		if act("close") then
			openUserId = nil
			heading.Text = "Pick a chat on the left."
			whereLabel.Text = ""
			clear(lines)
			say("Chat finished and removed.")
			refreshMessages()
		end
	end)
end

-- ==================== MENU ====================
local PAGES = { -- add more pages here later
	{ name = "⚡ EVENTS", build = buildEventsPage },
	{ name = "📊 SETS", build = buildSetsPage },
	{ name = "🗺️ TELEPORT", build = buildTeleportPage, onShow = function()
		refreshMap()
	end },
	{ name = "📨 MESSAGES", build = buildMessagesPage, onShow = function()
		refreshMessages()
	end },
}

local pageFrames, menuButtons = {}, {}
local currentPage = 1
local chosenTab = { property = "BackgroundColor3" } -- the open page's tab glows rainbow
table.insert(colorCycling, chosenTab)

local function showPage(index)
	for i, frame in ipairs(pageFrames) do
		frame.Visible = i == index
		menuButtons[i].BackgroundColor3 = Color3.fromRGB(55, 55, 65)
		menuButtons[i].TextColor3 = i == index and Color3.new(0, 0, 0) or WHITE
	end
	chosenTab.object = menuButtons[index]
	currentPage = index
	say("")
	if PAGES[index].onShow then
		PAGES[index].onShow()
	end
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
	if panel.Visible and PAGES[currentPage].onShow then
		PAGES[currentPage].onShow() -- e.g. the map picks up anything that loaded in since
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

-- New messages: a red dot on the VIP button, and the list updates if it's open
newMessageDot = Instance.new("Frame")
newMessageDot.AnchorPoint = Vector2.new(0.5, 0.5)
newMessageDot.Size = UDim2.new(0, 18, 0, 18)
newMessageDot.Position = UDim2.new(0.85, 0, 0.15, 0)
newMessageDot.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
newMessageDot.ZIndex = 5
newMessageDot.Visible = false
newMessageDot.Parent = openButton
corner(newMessageDot, UDim.new(0.5, 0))

wheelNotice.OnClientEvent:Connect(function(kind)
	if kind ~= "inbox" then
		return
	end
	newMessageDot.Visible = true
	if panel.Visible and PAGES[currentPage].build == buildMessagesPage then
		refreshMessages()
	end
end)
