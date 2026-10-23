-- Store UI for the normal shop and the VIP shop (opened by the server from a shop counter prompt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local storeEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("StoreAction")

local gui = Instance.new("ScreenGui")
gui.Name = "StoreGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 460, 0, 440)
frame.Position = UDim2.new(0.5, -230, 0.5, -220)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 215, 0)
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 36)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 30)
closeBtn.Position = UDim2.new(1, -42, 0, 3)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = frame
closeBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 24)
status.Position = UDim2.new(0, 10, 1, -28)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Text = ""
status.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -76)
list.Position = UDim2.new(0, 10, 0, 40)
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 6
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = list

local currentStore = "normal"

local function addRow(text, buttons)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	row.Parent = list

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextWrapped = true
	label.Text = text
	label.Parent = row

	for i, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.24, 0, 0, 30)
		btn.Position = UDim2.new(0.5 + (i - 1) * 0.25, 2, 0, 5)
		btn.BackgroundColor3 = info.color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextWrapped = true
		btn.Text = info.text
		btn.Parent = row
		btn.MouseButton1Click:Connect(function()
			storeEvent:FireServer(info.action or "buy", info.itemId, info.method)
		end)
	end
end

local ROBUX_COLOR = Color3.fromRGB(0, 140, 70)
local MONEY_COLOR = Color3.fromRGB(190, 140, 20)

local function robuxButton(item, itemId, price)
	return { text = "R$ " .. Catalog.FormatNumber(price), itemId = itemId, method = "robux", color = ROBUX_COLOR }
end

local WEAR_COLOR = Color3.fromRGB(75, 110, 180)
local lastState = nil

-- e.g. "+30% STR & KICK": the fight boost a skin gives while worn
local function bonusText(sky)
	return string.format("+%d%% STR & KICK", math.floor(sky.bonus * 100 + 0.5))
end

-- Color Shop: the current sky event's skin is for sale; owned skins can be worn any time
local function renderColorShop(state)
	title.Text = "COLOR SHOP"
	local eventColorId = ReplicatedStorage:GetAttribute("SkyEventColor")
	local eventSky = eventColorId and Catalog.SkyColorById[eventColorId]
	if eventSky then
		local item = Catalog.ById["skin_" .. eventSky.id]
		if state.ownedSkins and state.ownedSkins[eventSky.id] then
			addRow(item.name .. " (owned) · " .. bonusText(eventSky), {})
		else
			addRow(eventSky.name .. " sky event! " .. item.name .. " · " .. bonusText(eventSky), {
				{ text = Catalog.FormatNumber(item.money) .. " money", itemId = item.id, method = "money", color = MONEY_COLOR },
				robuxButton(item, item.id, item.robux),
			})
		end
	else
		addRow("No sky event right now. Come back when the sky changes color!", {})
	end

	for _, sky in ipairs(Catalog.SkyColors) do
		if state.ownedSkins and state.ownedSkins[sky.id] then
			local wearing = state.skin == sky.id
			addRow(sky.name .. " Skin · " .. bonusText(sky) .. (wearing and " (wearing)" or ""), wearing and {} or {
				{ text = "WEAR", itemId = sky.id, action = "wear", color = WEAR_COLOR },
			})
		end
	end
	if state.skin then
		addRow("Normal look", { { text = "WEAR", itemId = "none", action = "wear", color = WEAR_COLOR } })
	end
end

local function render(state)
	lastState = state
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if currentStore == "color" then
		renderColorShop(state)
		return
	end

	if currentStore == "vip" then
		title.Text = "VIP SHOP"
		if not state.vipUnlocked then
			addRow(string.format(
				"🔒 World Champions only: reach %s strength (you have %s)",
				Catalog.FormatNumber(state.vipRequiredStrength),
				Catalog.FormatNumber(state.strength)
			), {})
			return
		end
		for _, item in ipairs(Catalog.Vip) do
			addRow(item.name, { robuxButton(item, item.id, item.robux) })
		end
		return
	end

	title.Text = "SHOP"
	for _, item in ipairs(Catalog.Normal) do
		local text = item.name
		if item.kind == "wins10" then
			text = string.format("%s (now %sx)", item.name, Catalog.FormatNumber(state.winMultiplier or 1))
		end
		addRow(text, { robuxButton(item, item.id, item.robux) })
	end
	if state.nextLuck then
		addRow("Luck " .. state.luck .. " > " .. state.nextLuck, { robuxButton(nil, "luck", state.luckPrice) })
	else
		addRow("Luck is maxed (" .. state.luck .. ")", {})
	end
	for _, item in ipairs(Catalog.Treadmills) do
		if state.treadmills and state.treadmills[item.tier] then
			addRow(item.name .. " (owned)", {})
		else
			addRow(item.name, {
				{ text = Catalog.FormatNumber(item.money) .. " money", itemId = item.id, method = "money", color = MONEY_COLOR },
				robuxButton(item, item.id, item.robux),
			})
		end
	end
end

storeEvent.OnClientEvent:Connect(function(action, a, b, c)
	if action == "open" then
		currentStore = a
		status.Text = ""
		render(b)
		frame.Visible = true
	elseif action == "notice" then
		status.Text = a
		status.TextColor3 = b and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 80, 80)
		if frame.Visible and c then
			render(c)
		end
	end
end)

-- Refresh the Color Shop when a sky event starts or ends while it's open
ReplicatedStorage:GetAttributeChangedSignal("SkyEventColor"):Connect(function()
	if frame.Visible and currentStore == "color" and lastState then
		render(lastState)
	end
end)
