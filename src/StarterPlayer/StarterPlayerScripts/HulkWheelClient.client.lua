-- The Hulk Wheel and the "message the owner" chat (HulkWheelService), with two buttons at the bottom left:
--   🎡 HULK WHEEL   shows once the player turned Hulk: a color wheel with spins left. Magenta (huge),
--                   purple, red and blue win nothing; orange, yellow, pink, cyan and the tiny green sliver
--                   give that skin; rainbow starts a Rainbow sky event. The server picks the result and
--                   the wheel turns to it.
--   📨 MESSAGE THE OWNER  a chat with the owner (everyone but the owner), e.g. to ask for a wheel reset.
--                   The owner answers from any server; a red dot shows when there's an answer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local events = ReplicatedStorage:WaitForChild("Events")
local wheelFunction = events:WaitForChild("HulkWheel")
local wheelNotice = events:WaitForChild("HulkWheelNotice")

local player = Players.LocalPlayer
local isOwner = player.UserId == WorldConfig.OwnerUserId

local WHEEL = WorldConfig.HulkWheel
local DARK = Color3.fromRGB(22, 22, 28)
local WHITE = Color3.new(1, 1, 1)
local HULK_GREEN = Color3.fromRGB(40, 200, 70)
local SPIN_SECONDS = 4

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HulkWheelGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 11
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

local function window(name, width, height, titleText, titleColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0, width, 0, height)
	frame.BackgroundColor3 = DARK
	frame.Visible = false
	frame.Parent = screenGui
	corner(frame, UDim.new(0, 12))
	local ring = Instance.new("UIStroke")
	ring.Color = titleColor
	ring.Thickness = 3
	ring.Parent = frame
	local fit = Instance.new("UIScale")
	fit.Parent = frame
	local camera = workspace.CurrentCamera
	local function resize()
		local view = camera.ViewportSize
		fit.Scale = math.min(1, (view.X - 30) / width, (view.Y - 30) / height)
	end
	resize()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	text(frame, { text = titleText, size = UDim2.new(1, -70, 0, 36), position = UDim2.new(0, 16, 0, 8), color = titleColor, font = Enum.Font.GothamBlack, alignX = Enum.TextXAlignment.Left })
	local close = text(frame, { button = true, text = "X", size = UDim2.new(0, 34, 0, 34), position = UDim2.new(1, -44, 0, 9), background = Color3.fromRGB(150, 40, 40) })
	corner(close)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	return frame
end

-- ==================== BOTTOM-LEFT BUTTONS ====================
local buttons = Instance.new("Frame")
buttons.AnchorPoint = Vector2.new(0, 1)
buttons.Size = UDim2.new(0, 220, 0, 100)
buttons.Position = UDim2.new(0, 16, 1, isOwner and -56 or -16) -- above the owner's stat search box
buttons.BackgroundTransparency = 1
buttons.Parent = screenGui
local buttonList = Instance.new("UIListLayout")
buttonList.VerticalAlignment = Enum.VerticalAlignment.Bottom
buttonList.Padding = UDim.new(0, 8)
buttonList.SortOrder = Enum.SortOrder.LayoutOrder
buttonList.Parent = buttons

local wheelButton = text(buttons, { button = true, text = "🎡 HULK WHEEL", size = UDim2.new(1, 0, 0, 42), background = HULK_GREEN, font = Enum.Font.GothamBlack })
wheelButton.LayoutOrder = 1
wheelButton.TextStrokeTransparency = 0.4
wheelButton.Visible = false
corner(wheelButton)

local chatButton = text(buttons, { button = true, text = "📨 MESSAGE THE OWNER", size = UDim2.new(1, 0, 0, 42), background = Color3.fromRGB(50, 90, 200), font = Enum.Font.GothamBlack })
chatButton.LayoutOrder = 2
chatButton.TextStrokeTransparency = 0.4
chatButton.Visible = not isOwner
corner(chatButton)
local unreadDot = Instance.new("Frame")
unreadDot.AnchorPoint = Vector2.new(0.5, 0.5)
unreadDot.Size = UDim2.new(0, 16, 0, 16)
unreadDot.Position = UDim2.new(1, -4, 0, 4)
unreadDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
unreadDot.Visible = false
unreadDot.Parent = chatButton
corner(unreadDot, UDim.new(0.5, 0))

-- ==================== THE WHEEL ====================
local wheelWindow = window("HulkWheel", 640, 420, "💚 HULK WHEEL", HULK_GREEN)

local WHEEL_SIZE = 300
local wheelArea = Instance.new("Frame")
wheelArea.Size = UDim2.new(0, WHEEL_SIZE, 0, WHEEL_SIZE)
wheelArea.Position = UDim2.new(0, 20, 0, 70)
wheelArea.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
wheelArea.Parent = wheelWindow
corner(wheelArea, UDim.new(0.5, 0))
local rim = Instance.new("UIStroke")
rim.Color = Color3.fromRGB(255, 215, 60)
rim.Thickness = 5
rim.Parent = wheelArea

-- The disc turns; it's drawn as thin spokes from the middle out, each colored by its slice
local disc = Instance.new("Frame")
disc.Size = UDim2.fromScale(1, 1)
disc.BackgroundTransparency = 1
disc.Parent = wheelArea

local sliceAngles = {} -- [index] = { from, to } in degrees, clockwise from the top
do
	local total = 0
	for _, slice in ipairs(WHEEL.Slices) do
		total += slice.chance
	end
	local angle = 0
	local radius = WHEEL_SIZE / 2
	for index, slice in ipairs(WHEEL.Slices) do
		local width = slice.chance / total * 360
		sliceAngles[index] = { from = angle, to = angle + width }
		local sky = Catalog.SkyColorById[slice.color]
		local spokes = math.max(1, math.ceil(width))
		local step = width / spokes
		for k = 0, spokes - 1 do
			local spokeAngle = angle + (k + 0.5) * step
			local holder = Instance.new("Frame")
			holder.Size = UDim2.fromScale(1, 1)
			holder.BackgroundTransparency = 1
			holder.Rotation = spokeAngle
			holder.Parent = disc
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.fromScale(0.5, 0)
			bar.Size = UDim2.new(0, math.rad(step) * radius + 1.5, 0.5, 0)
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = sky.color
			bar.Parent = holder
			if sky.rainbow then
				local gradient = Instance.new("UIGradient")
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 40)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 255)),
				})
				gradient.Rotation = 90
				gradient.Parent = bar
			end
		end
		-- Names on the slices big enough to hold them
		if width >= 20 then
			local holder = Instance.new("Frame")
			holder.Size = UDim2.fromScale(1, 1)
			holder.BackgroundTransparency = 1
			holder.Rotation = angle + width / 2
			holder.Parent = disc
			local label = text(holder, { text = sky.name, size = UDim2.new(0, 90, 0, 22), position = UDim2.new(0.5, -45, 0.1, 0), font = Enum.Font.GothamBlack })
			label.TextStrokeTransparency = 0.2
		end
		angle += width
	end
end

local hub = Instance.new("Frame")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.new(0, 46, 0, 46)
hub.BackgroundColor3 = Color3.fromRGB(255, 215, 60)
hub.ZIndex = 3
hub.Parent = wheelArea
corner(hub, UDim.new(0.5, 0))
local pointer = text(wheelArea, { text = "▼", size = UDim2.new(0, 40, 0, 40), position = UDim2.new(0.5, -20, 0, -30), color = Color3.fromRGB(255, 255, 255), font = Enum.Font.GothamBlack })
pointer.TextStrokeTransparency = 0
pointer.ZIndex = 4

-- The list of prizes on the right
local legend = Instance.new("Frame")
legend.Size = UDim2.new(0, 270, 0, 250)
legend.Position = UDim2.new(0, 350, 0, 56)
legend.BackgroundTransparency = 1
legend.Parent = wheelWindow
local legendList = Instance.new("UIListLayout")
legendList.Padding = UDim.new(0, 2)
legendList.SortOrder = Enum.SortOrder.LayoutOrder
legendList.Parent = legend
do
	local total = 0
	for _, slice in ipairs(WHEEL.Slices) do
		total += slice.chance
	end
	for index = #WHEEL.Slices, 1, -1 do -- rarest first
		local slice = WHEEL.Slices[index]
		local sky = Catalog.SkyColorById[slice.color]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.LayoutOrder = #WHEEL.Slices - index
		row.Parent = legend
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 16, 0, 16)
		swatch.Position = UDim2.new(0, 0, 0, 3)
		swatch.BackgroundColor3 = sky.color
		swatch.Parent = row
		corner(swatch, UDim.new(0, 4))
		local prize = slice.wasted and "nothing" or slice.event and "Rainbow event!" or "skin"
		local percent = slice.chance / total * 100
		local percentText = percent >= 1 and string.format("%d%%", math.floor(percent + 0.5)) or string.format("%.1f%%", percent)
		text(row, {
			text = string.format("%s  %s  —  %s", sky.name, percentText, prize),
			size = UDim2.new(1, -24, 1, 0),
			position = UDim2.new(0, 24, 0, 0),
			color = slice.wasted and Color3.fromRGB(150, 150, 150) or WHITE,
			font = slice.wasted and Enum.Font.Gotham or Enum.Font.GothamBold,
			alignX = Enum.TextXAlignment.Left,
		})
	end
end

local spinButton = text(wheelWindow, { button = true, text = "SPIN", size = UDim2.new(0, 270, 0, 48), position = UDim2.new(0, 350, 0, 312), background = HULK_GREEN, font = Enum.Font.GothamBlack })
spinButton.TextStrokeTransparency = 0.4
corner(spinButton)
local result = text(wheelWindow, { text = "", size = UDim2.new(1, -40, 0, 26), position = UDim2.new(0, 20, 1, -36), font = Enum.Font.GothamBold })

local wheelInfo = { unlocked = false, spins = 0 }
local isSpinning = false
local openChat -- the chat window, further down

local function refreshWheel()
	wheelButton.Visible = wheelInfo.unlocked
	wheelButton.Text = wheelInfo.spins > 0 and string.format("🎡 HULK WHEEL (%d)", wheelInfo.spins) or "🎡 HULK WHEEL"
	if not isSpinning then
		if wheelInfo.spins > 0 then
			spinButton.Text = string.format("SPIN (%d left)", wheelInfo.spins)
			spinButton.BackgroundColor3 = HULK_GREEN
		else
			spinButton.Text = isOwner and "No spins left" or "No spins left — ask the owner for a reset 📨"
			spinButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		end
	end
end

spinButton.Activated:Connect(function()
	if isSpinning then
		return
	end
	if wheelInfo.spins <= 0 then
		if not isOwner then
			wheelWindow.Visible = false
			openChat()
		end
		return
	end
	isSpinning = true
	spinButton.Text = "Spinning..."
	spinButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	result.Text = ""
	local ok, outcome = pcall(wheelFunction.InvokeServer, wheelFunction, "spin")
	if not ok or type(outcome) ~= "table" then
		isSpinning = false
		result.Text = "That didn't work. Try again."
		refreshWheel()
		return
	end
	-- Turn the wheel so the winning slice stops under the pointer (somewhere inside it, not on the edge)
	local slice = sliceAngles[outcome.slice]
	local inside = slice.from + (slice.to - slice.from) * (0.2 + math.random() * 0.6)
	local current = disc.Rotation % 360
	disc.Rotation = current
	local target = current + 360 * 6 + ((-inside - current) % 360)
	local turn = TweenService:Create(disc, TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
	turn:Play()
	turn.Completed:Wait()
	result.Text = outcome.message
	result.TextColor3 = outcome.won and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(200, 200, 200)
	wheelInfo.spins = outcome.spins
	isSpinning = false
	refreshWheel()
end)

wheelButton.Activated:Connect(function()
	wheelWindow.Visible = not wheelWindow.Visible
end)

-- ==================== CHAT WITH THE OWNER ====================
local chatWindow = window("OwnerChat", 460, 420, "📨 MESSAGE THE OWNER", Color3.fromRGB(120, 170, 255))
local chatHelp = text(chatWindow, {
	text = "Ask the owner anything, like a Hulk Wheel reset. If you're in a private server, tell them so they can come help.",
	size = UDim2.new(1, -32, 0, 34),
	position = UDim2.new(0, 16, 0, 46),
	color = Color3.fromRGB(180, 180, 190),
	font = Enum.Font.Gotham,
	alignX = Enum.TextXAlignment.Left,
})
chatHelp.TextWrapped = true

local chatList = Instance.new("ScrollingFrame")
chatList.Size = UDim2.new(1, -32, 1, -180)
chatList.Position = UDim2.new(0, 16, 0, 86)
chatList.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
chatList.BorderSizePixel = 0
chatList.ScrollBarThickness = 6
chatList.AutomaticCanvasSize = Enum.AutomaticSize.Y
chatList.CanvasSize = UDim2.new()
chatList.Parent = chatWindow
corner(chatList)
local chatLayout = Instance.new("UIListLayout")
chatLayout.Padding = UDim.new(0, 6)
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatLayout.Parent = chatList
local chatPadding = Instance.new("UIPadding")
chatPadding.PaddingTop = UDim.new(0, 6)
chatPadding.PaddingLeft = UDim.new(0, 8)
chatPadding.PaddingRight = UDim.new(0, 8)
chatPadding.Parent = chatList

local chatBox = Instance.new("TextBox")
chatBox.Size = UDim2.new(1, -122, 0, 40)
chatBox.Position = UDim2.new(0, 16, 1, -86)
chatBox.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
chatBox.TextColor3 = WHITE
chatBox.PlaceholderText = "Type a message..."
chatBox.Text = ""
chatBox.ClearTextOnFocus = false
chatBox.TextWrapped = true
chatBox.TextScaled = true
chatBox.Font = Enum.Font.Gotham
chatBox.Parent = chatWindow
corner(chatBox, UDim.new(0, 6))
local sendButton = text(chatWindow, { button = true, text = "SEND", size = UDim2.new(0, 90, 0, 40), position = UDim2.new(1, -106, 1, -86), background = Color3.fromRGB(50, 90, 200), font = Enum.Font.GothamBlack })
corner(sendButton, UDim.new(0, 6))
local chatStatus = text(chatWindow, { text = "", size = UDim2.new(1, -32, 0, 22), position = UDim2.new(0, 16, 1, -38), color = Color3.fromRGB(200, 200, 200), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })

-- One chat line: the owner's on the left in gold, yours on the right
local function chatLine(line, order)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = chatList
	local bubble = text(holder, {
		text = (line.owner and "👑 Owner: " or "You: ") .. line.text,
		size = UDim2.new(0.85, 0, 0, 0),
		position = line.owner and UDim2.new() or UDim2.fromScale(0.15, 0),
		background = line.owner and Color3.fromRGB(80, 65, 20) or Color3.fromRGB(40, 60, 120),
		font = Enum.Font.Gotham,
		alignX = Enum.TextXAlignment.Left,
	})
	bubble.TextScaled = false
	bubble.TextSize = 16
	bubble.TextWrapped = true
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = bubble
	corner(bubble)
end

local function loadChat()
	chatStatus.Text = "Loading..."
	local ok, lines = pcall(wheelFunction.InvokeServer, wheelFunction, "chat")
	for _, child in ipairs(chatList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not ok or type(lines) ~= "table" then
		chatStatus.Text = "Messages can't load right now."
		return
	end
	chatStatus.Text = #lines == 0 and "No messages yet. Say hi!" or ""
	for order, line in ipairs(lines) do
		chatLine(line, order)
	end
	unreadDot.Visible = false
	task.defer(function()
		chatList.CanvasPosition = Vector2.new(0, 1e6)
	end)
end

openChat = function()
	chatWindow.Visible = true
	loadChat()
end

local sending = false
local function send()
	if sending or not string.find(chatBox.Text, "%S") then
		return
	end
	sending = true
	chatStatus.Text = "Sending..."
	local ok, answer = pcall(wheelFunction.InvokeServer, wheelFunction, "send", chatBox.Text)
	sending = false
	if ok and answer == true then
		chatBox.Text = ""
		loadChat()
		chatStatus.Text = "📨 Sent! The owner will answer here, even if you leave and come back."
	else
		chatStatus.Text = ok and tostring(answer) or "Couldn't send. Try again."
	end
end
sendButton.Activated:Connect(send)
chatBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		send()
	end
end)

chatButton.Activated:Connect(function()
	if chatWindow.Visible then
		chatWindow.Visible = false
	else
		openChat()
	end
end)

-- ==================== NEWS FROM THE SERVER ====================
wheelNotice.OnClientEvent:Connect(function(kind, info, opened)
	if kind == "wheel" and type(info) == "table" then
		wheelInfo = info
		refreshWheel()
		if opened then
			wheelWindow.Visible = true
		end
	elseif kind == "chat" and not isOwner then
		if chatWindow.Visible then
			loadChat()
		else
			unreadDot.Visible = true
		end
	end
end)

local ok, info = pcall(wheelFunction.InvokeServer, wheelFunction, "state")
if ok and type(info) == "table" then
	wheelInfo = info
end
refreshWheel()
