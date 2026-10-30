-- The 🔒 PRIVATE SERVER button (bottom left) and its panel (PrivateServerService):
--   • your own private server: its number, days left, GO TO MY SERVER, and BUY / RENEW (100 Robux = 1 month)
--   • join any private server by typing its 6-digit number
--   • inside a private server, its number is shown so it can be shared with friends

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local events = ReplicatedStorage:WaitForChild("Events")
local privateServerFunction = events:WaitForChild("PrivateServer")
local privateServerNotice = events:WaitForChild("PrivateServerNotice")

local player = Players.LocalPlayer
local isOwner = player.UserId == WorldConfig.OwnerUserId

local DARK = Color3.fromRGB(22, 22, 28)
local WHITE = Color3.new(1, 1, 1)
local PURPLE = Color3.fromRGB(120, 70, 220)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PrivateServerGui"
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
	label.TextWrapped = true
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

-- The button: above the Hulk Wheel / message buttons at the bottom left
local openButton = text(screenGui, { button = true, text = "🔒 PRIVATE SERVER", size = UDim2.new(0, 220, 0, 42), background = PURPLE, font = Enum.Font.GothamBlack })
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 16, 1, isOwner and -164 or -124)
openButton.TextStrokeTransparency = 0.4
corner(openButton)

-- The panel
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0, 400, 0, 330)
panel.BackgroundColor3 = DARK
panel.Visible = false
panel.Parent = screenGui
corner(panel, UDim.new(0, 12))
local ring = Instance.new("UIStroke")
ring.Color = PURPLE
ring.Thickness = 3
ring.Parent = panel

text(panel, { text = "🔒 PRIVATE SERVERS", size = UDim2.new(1, -70, 0, 34), position = UDim2.new(0, 16, 0, 10), color = Color3.fromRGB(190, 150, 255), font = Enum.Font.GothamBlack, alignX = Enum.TextXAlignment.Left })
local closeButton = text(panel, { button = true, text = "X", size = UDim2.new(0, 32, 0, 32), position = UDim2.new(1, -42, 0, 10), background = Color3.fromRGB(150, 40, 40) })
corner(closeButton)

local hereLabel = text(panel, { text = "", size = UDim2.new(1, -32, 0, 22), position = UDim2.new(0, 16, 0, 48), color = Color3.fromRGB(120, 255, 140), alignX = Enum.TextXAlignment.Left })

-- Your own server
local mineLabel = text(panel, { text = "", size = UDim2.new(1, -32, 0, 40), position = UDim2.new(0, 16, 0, 74), alignX = Enum.TextXAlignment.Left })
local goButton = text(panel, { button = true, text = "GO TO MY SERVER", size = UDim2.new(0.5, -20, 0, 40), position = UDim2.new(0, 16, 0, 120), background = Color3.fromRGB(40, 150, 70) })
corner(goButton)
local buyButton = text(panel, { button = true, text = "BUY · R$ 100 / month", size = UDim2.new(0.5, -20, 0, 40), position = UDim2.new(0.5, 4, 0, 120), background = Color3.fromRGB(0, 140, 70) })
corner(buyButton)

-- Joining by number
text(panel, { text = "Join a private server with its number:", size = UDim2.new(1, -32, 0, 20), position = UDim2.new(0, 16, 0, 176), color = Color3.fromRGB(190, 190, 200), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })
local numberBox = Instance.new("TextBox")
numberBox.Size = UDim2.new(1, -130, 0, 40)
numberBox.Position = UDim2.new(0, 16, 0, 200)
numberBox.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
numberBox.TextColor3 = WHITE
numberBox.PlaceholderText = "e.g. 482913"
numberBox.Text = ""
numberBox.ClearTextOnFocus = false
numberBox.TextScaled = true
numberBox.Font = Enum.Font.GothamBold
numberBox.Parent = panel
corner(numberBox, UDim.new(0, 6))
local joinButton = text(panel, { button = true, text = "JOIN", size = UDim2.new(0, 98, 0, 40), position = UDim2.new(1, -114, 0, 200), background = PURPLE, font = Enum.Font.GothamBlack })
corner(joinButton, UDim.new(0, 6))

local status = text(panel, { text = "", size = UDim2.new(1, -32, 0, 34), position = UDim2.new(0, 16, 0, 248), color = Color3.fromRGB(220, 220, 230), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })
text(panel, { text = "Give your number to friends so they can join you. Fights need 2 players!", size = UDim2.new(1, -32, 0, 30), position = UDim2.new(0, 16, 1, -40), color = Color3.fromRGB(150, 150, 160), font = Enum.Font.Gotham, alignX = Enum.TextXAlignment.Left })

local function show(info)
	if type(info) ~= "table" then
		status.Text = "That didn't work. Try again."
		return
	end
	hereLabel.Text = info.here and ("📍 You're in private server #" .. info.here .. " — share this number!") or ""
	local daysLeft = math.ceil((info.secondsLeft or 0) / 86400)
	if info.mine and daysLeft > 0 then
		mineLabel.Text = string.format("Your server: #%d  (%d day%s left)", info.mine, daysLeft, daysLeft == 1 and "" or "s")
		buyButton.Text = string.format("RENEW · R$ %d / month", info.price or 100)
		goButton.Visible = true
	elseif info.mine then
		mineLabel.Text = "Your server #" .. info.mine .. " ran out. Renew it to use it again."
		buyButton.Text = string.format("RENEW · R$ %d / month", info.price or 100)
		goButton.Visible = false
	else
		mineLabel.Text = "Get your own private server with its own number!"
		buyButton.Text = string.format("BUY · R$ %d / month", info.price or 100)
		goButton.Visible = false
	end
	if info.message then
		status.Text = info.message
	end
end

local function ask(action, value)
	status.Text = "One moment..."
	local ok, info = pcall(privateServerFunction.InvokeServer, privateServerFunction, action, value)
	if ok then
		show(info)
		if type(info) == "table" and not info.message then
			status.Text = ""
		end
	else
		status.Text = "That didn't work. Try again."
	end
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		ask("state")
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
goButton.Activated:Connect(function()
	ask("mine")
end)
buyButton.Activated:Connect(function()
	ask("buy")
end)
local function joinTyped()
	local number = string.gsub(numberBox.Text, "%D", "")
	ask("join", number)
end
joinButton.Activated:Connect(joinTyped)
numberBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		joinTyped()
	end
end)

privateServerNotice.OnClientEvent:Connect(function(message)
	panel.Visible = true
	ask("state")
	status.Text = tostring(message)
end)
