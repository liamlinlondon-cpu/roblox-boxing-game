-- Store UI for the normal shop and the VIP shop (opened by the server from a shop counter prompt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))
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
local SELL_COLOR = Color3.fromRGB(170, 60, 60)

-- "SELL +1,000" button for an owned item
local function sellButton(item)
	return { text = "SELL +" .. Catalog.FormatNumber(Catalog.SellPrice(item)), itemId = item.id, action = "sell", color = SELL_COLOR }
end
local lastState = nil

-- Seconds left to buy the Disco skin (30 after a disco party starts, a minute for the owner)
local function discoSecondsLeft()
	local startedAt = ReplicatedStorage:GetAttribute("DiscoStartedAt")
	if not ReplicatedStorage:GetAttribute("DiscoParty") or not startedAt then
		return 0
	end
	local window = player.UserId == WorldConfig.OwnerUserId and Catalog.DiscoSaleSecondsOwner or Catalog.DiscoSaleSeconds
	return math.max(0, math.ceil(window - (workspace:GetServerTimeNow() - startedAt)))
end

-- Color Shop: the current sky event's skin is for sale (and the Disco skin during a disco party); owned
-- skins can be worn any time
local function renderColorShop(state)
	title.Text = "COLOR SHOP"
	local onSale = {}
	local eventColorId = ReplicatedStorage:GetAttribute("SkyEventColor")
	local eventSky = eventColorId and Catalog.SkyColorById[eventColorId]
	if eventSky then
		table.insert(onSale, { sky = eventSky, why = eventSky.name .. " sky event! " })
	end
	-- The Disco skin: only for a few seconds after a disco party starts (be quick!)
	local discoLeft = discoSecondsLeft()
	if discoLeft > 0 then
		table.insert(onSale, { sky = Catalog.SkyColorById.disco, why = "🪩 DISCO! Only " .. discoLeft .. "s left! " })
	end
	for _, sale in ipairs(onSale) do
		local sky = sale.sky
		local item = Catalog.ById["skin_" .. sky.id]
		if state.ownedSkins and state.ownedSkins[sky.id] then
			addRow(item.name .. " (owned) · " .. Catalog.SkinPerkText(sky), {})
		else
			addRow(sale.why .. item.name .. " · " .. Catalog.SkinPerkText(sky), {
				{ text = Catalog.FormatNumber(item.money) .. " money", itemId = item.id, method = "money", color = MONEY_COLOR },
				robuxButton(item, item.id, item.robux),
			})
		end
	end
	if #onSale == 0 then
		addRow("No sky event right now. Come back when the sky changes color!", {})
	end

	for _, sky in ipairs(Catalog.SkyColors) do
		if state.ownedSkins and state.ownedSkins[sky.id] then
			local wearing = state.skin == sky.id
			local buttons = {}
			if not wearing then
				table.insert(buttons, { text = "WEAR", itemId = sky.id, action = "wear", color = WEAR_COLOR })
			end
			table.insert(buttons, sellButton(Catalog.ById["skin_" .. sky.id]))
			addRow(sky.name .. " Skin · " .. Catalog.SkinPerkText(sky) .. (wearing and " (wearing)" or ""), buttons)
		end
	end
	if state.skin then
		addRow("Normal look", { { text = "WEAR", itemId = "none", action = "wear", color = WEAR_COLOR } })
	end
end

-- Sell Shop: every lasting item the player owns and every tool in their backpack, each with a SELL button
local function renderSellShop(state)
	title.Text = "SELL SHOP"
	local anything = false
	local function offer(item, owned)
		if owned then
			anything = true
			addRow(item.name, { sellButton(item) })
		end
	end
	offer(Catalog.ById.carpet, state.carpet)
	offer(Catalog.ById.carpetpass, state.carpetPass)
	for _, item in ipairs(Catalog.Treadmills) do
		offer(item, state.treadmills and state.treadmills[item.tier])
	end
	-- Skins can be worn from here too (same as the Color Shop), so nobody has to walk over there
	for _, sky in ipairs(Catalog.SkyColors) do
		if state.ownedSkins and state.ownedSkins[sky.id] then
			anything = true
			local item = Catalog.ById["skin_" .. sky.id]
			local wearing = state.skin == sky.id
			local buttons = {}
			if not wearing then
				table.insert(buttons, { text = "WEAR", itemId = sky.id, action = "wear", color = WEAR_COLOR })
			end
			table.insert(buttons, sellButton(item))
			addRow(item.name .. (wearing and " (wearing)" or ""), buttons)
		end
	end
	-- Anything else in the backpack (or held)
	local listed = {}
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool.Name ~= "Magic Carpet" and not listed[tool.Name] then
					listed[tool.Name] = true
					anything = true
					addRow(tool.Name .. " (backpack)", {
						{
							text = "SELL +" .. Catalog.FormatNumber(Catalog.BackpackToolSellPrice),
							itemId = tool.Name,
							action = "sellTool",
							color = SELL_COLOR,
						},
					})
				end
			end
		end
	end
	if not anything then
		addRow("You don't own anything that can be sold yet.", {})
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

	if currentStore == "sell" then
		renderSellShop(state)
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
		local buttons = {}
		local owned = (item.kind == "carpetpass" and state.carpetPass) or (item.kind == "carpet" and state.carpet)
		if owned then
			text ..= " (owned)"
			table.insert(buttons, sellButton(item))
		else
			if item.money then
				table.insert(buttons, { text = Catalog.FormatNumber(item.money) .. " money", itemId = item.id, method = "money", color = MONEY_COLOR })
			end
			if item.robux then
				table.insert(buttons, robuxButton(item, item.id, item.robux))
			end
		end
		addRow(text, buttons)
	end
	if state.nextLuck then
		addRow("Luck " .. state.luck .. " > " .. state.nextLuck, { robuxButton(nil, "luck", state.luckPrice) })
	else
		addRow("Luck is maxed (" .. state.luck .. ")", {})
	end
	for _, item in ipairs(Catalog.Treadmills) do
		if state.treadmills and state.treadmills[item.tier] then
			addRow(item.name .. " (owned)", { sellButton(item) })
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

-- Refresh the Color Shop when a sky event or disco party starts or ends while it's open
local function refreshColorShop()
	if frame.Visible and currentStore == "color" and lastState then
		render(lastState)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("SkyEventColor"):Connect(refreshColorShop)
ReplicatedStorage:GetAttributeChangedSignal("DiscoParty"):Connect(refreshColorShop)

-- The Disco skin's countdown ticks while the Color Shop is open
task.spawn(function()
	local wasOnSale = false
	while true do
		task.wait(1)
		local onSale = discoSecondsLeft() > 0
		if onSale or wasOnSale then
			refreshColorShop()
		end
		wasOnSale = onSale
	end
end)
