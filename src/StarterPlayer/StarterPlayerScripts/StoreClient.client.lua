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

-- ==================== PICTURES ====================
-- Every row has a little picture on the left: an emoji for the kind of item (🍀 luck, 💰 money, 💪
-- strength...) or a color swatch for skins.
local KIND_PICTURES = {
	money = "💰",
	strength = "💪",
	kick = "🦵",
	carpetpass = "🎫",
	treadmill = "🏃",
	wins10 = "🏆",
	maxluck = "🍀",
}
-- Money packs get bigger and bigger containers full of money, and a bigger picture every step
local MONEY_PICTURES = {
	money_1k = { emoji = "💵", grow = 0 }, -- one piece of money
	money_100k = { emoji = "💰", grow = 1 }, -- a bag of money
	money_1m = { emoji = "🗑️", extra = "💵", grow = 2 }, -- a trash can full of money
	money_10m = { emoji = "🚗", extra = "💵", grow = 3 }, -- a car full of money
	money_1b = { emoji = "🚚", extra = "💰", grow = 4 }, -- a truck full of money
	money_1t = { emoji = "🚛", extra = "💰", grow = 5 }, -- a dump truck full of money
	money_1qa = { emoji = "✈️", extra = "💰", grow = 6 }, -- a plane full of money
	money_1sx = { emoji = "🐳", extra = "💰", grow = 7 }, -- the Beluga plane full of money
	money_1sp = { emoji = "🛫", extra = "💰", grow = 8 }, -- the biggest plane in the world
	money_1no = { emoji = "🛫", extra = "💰", grow = 9 }, -- the biggest plane, even bigger
	money_inf = { emoji = "🌍", extra = "💰", grow = 10 }, -- a whole planet full of money
}
local PICTURE_SIZE = 34 -- the smallest picture; money pictures grow by PICTURE_GROW each step
local PICTURE_GROW = 4

local RAINBOW_SWATCH = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 210, 80)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(50, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 70, 230)),
})

-- What picture an item gets: an emoji, { sky = ... } for a skin's color, or { emoji, extra, grow }
local function pictureFor(itemId, action)
	if MONEY_PICTURES[itemId] then
		return MONEY_PICTURES[itemId]
	elseif itemId == "luck" then
		return "🍀"
	elseif itemId == "none" then
		return "🙂"
	elseif action == "wear" then
		return { sky = Catalog.SkyColorById[itemId] }
	elseif action == "sellTool" then
		return "🎒"
	end
	local item = Catalog.ById[itemId]
	if item and item.kind == "carpet" then
		return { carpet = true }
	elseif item and item.kind == "skin" then
		return { sky = Catalog.SkyColorById[item.colorId] }
	end
	return item and KIND_PICTURES[item.kind] or nil
end

local function pictureSize(picture)
	return PICTURE_SIZE + (type(picture) == "table" and (picture.grow or 0) or 0) * PICTURE_GROW
end

-- The Magic Carpet's picture: a little rainbow rug with gold tassels that waves in the wind
local wavingStrips = {} -- { frame, index, baseY }: moved up and down while the shop is open
local CARPET_PICTURE_STRIPS = 8
local CARPET_PICTURE_COLORS = {
	Color3.fromRGB(255, 50, 50),
	Color3.fromRGB(255, 150, 30),
	Color3.fromRGB(255, 230, 40),
	Color3.fromRGB(50, 210, 80),
	Color3.fromRGB(50, 120, 255),
	Color3.fromRGB(160, 70, 230),
}

local function drawCarpetPicture(box)
	box.BackgroundColor3 = Color3.fromRGB(120, 175, 235) -- sky behind it
	box.ClipsDescendants = true
	local rug = Instance.new("Frame")
	rug.AnchorPoint = Vector2.new(0.5, 0.5)
	rug.Position = UDim2.fromScale(0.5, 0.5)
	rug.Size = UDim2.fromScale(0.78, 0.42)
	rug.BackgroundTransparency = 1
	rug.Rotation = -12
	rug.Parent = box
	for i = 1, CARPET_PICTURE_STRIPS do
		local fraction = (i - 1) / (CARPET_PICTURE_STRIPS - 1)
		local position = fraction * (#CARPET_PICTURE_COLORS - 1) + 1
		local low = math.floor(position)
		local color = CARPET_PICTURE_COLORS[low]:Lerp(CARPET_PICTURE_COLORS[math.min(low + 1, #CARPET_PICTURE_COLORS)], position - low)
		local strip = Instance.new("Frame")
		strip.AnchorPoint = Vector2.new(0, 0.5)
		strip.Size = UDim2.new(1 / CARPET_PICTURE_STRIPS, 1, 1, 0)
		strip.Position = UDim2.new((i - 1) / CARPET_PICTURE_STRIPS, 0, 0.5, 0)
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		strip.Parent = rug
		-- Gold border on the long edges
		for _, y in ipairs({ 0, 1 }) do
			local trim = Instance.new("Frame")
			trim.AnchorPoint = Vector2.new(0, y)
			trim.Size = UDim2.new(1, 0, 0.14, 0)
			trim.Position = UDim2.fromScale(0, y)
			trim.BackgroundColor3 = Color3.fromRGB(230, 180, 50)
			trim.BorderSizePixel = 0
			trim.Parent = strip
		end
		-- Tassels on both ends
		if i == 1 or i == CARPET_PICTURE_STRIPS then
			for k = 1, 3 do
				local tassel = Instance.new("Frame")
				tassel.AnchorPoint = Vector2.new(i == 1 and 1 or 0, 0.5)
				tassel.Size = UDim2.new(0.5, 0, 0.12, 0)
				tassel.Position = UDim2.new(i == 1 and 0 or 1, 0, k / 4, 0)
				tassel.BackgroundColor3 = Color3.fromRGB(230, 180, 50)
				tassel.BorderSizePixel = 0
				tassel.Parent = strip
			end
		end
		table.insert(wavingStrips, { frame = strip, index = i })
	end
end

local function drawPicture(row, picture)
	local size = pictureSize(picture)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(0, size, 0, size)
	box.Position = UDim2.new(0, 3, 0, 3)
	box.BackgroundColor3 = Color3.fromRGB(62, 62, 72)
	box.Parent = row
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = box
	if type(picture) == "table" and picture.carpet then
		drawCarpetPicture(box)
		return
	end
	local emoji = type(picture) == "string" and picture or (type(picture) == "table" and picture.emoji) or nil
	local sky = type(picture) == "table" and picture.sky or nil
	if sky then
		box.BackgroundColor3 = sky.color
		if sky.rainbow or sky.disco then
			box.BackgroundColor3 = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = RAINBOW_SWATCH
			gradient.Rotation = 45
			gradient.Parent = box
		end
		emoji = sky.disco and "🪩" or sky.aura and "🔥" or nil
		local ring = Instance.new("UIStroke")
		ring.Color = Color3.new(1, 1, 1)
		ring.Thickness = 1.5
		ring.Parent = box
	end
	if emoji then
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Text = emoji
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.Parent = box
	end
	-- "Full of money": the money peeking out in the corner
	if type(picture) == "table" and picture.extra then
		local extra = Instance.new("TextLabel")
		extra.AnchorPoint = Vector2.new(1, 1)
		extra.Size = UDim2.fromScale(0.5, 0.5)
		extra.Position = UDim2.fromScale(1.05, 1.05)
		extra.BackgroundTransparency = 1
		extra.Text = picture.extra
		extra.TextScaled = true
		extra.Font = Enum.Font.GothamBold
		extra.ZIndex = 2
		extra.Parent = box
	end
end

-- picture (optional): an emoji or { sky = ... }; without one it comes from the row's buttons
local function addRow(text, buttons, picture)
	if not picture then
		for _, info in ipairs(buttons) do
			picture = pictureFor(info.itemId, info.action)
			if picture then
				break
			end
		end
	end
	-- Rows with a big picture (the biggest money) are taller
	local size = picture and pictureSize(picture) or PICTURE_SIZE
	local height = math.max(40, size + 6)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, height)
	row.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	row.Parent = list

	if picture then
		drawPicture(row, picture)
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, -(size + 8), 1, 0)
	label.Position = UDim2.new(0, size + 8, 0, 0)
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
		btn.Position = UDim2.new(0.5 + (i - 1) * 0.25, 2, 0, (height - 30) / 2)
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
			addRow(item.name .. " (owned) · " .. Catalog.SkinPerkText(sky), {}, { sky = sky })
		else
			addRow(sale.why .. item.name .. " · " .. Catalog.SkinPerkText(sky), {
				{ text = Catalog.FormatNumber(item.money) .. " money", itemId = item.id, method = "money", color = MONEY_COLOR },
				robuxButton(item, item.id, item.robux),
			})
		end
	end
	if #onSale == 0 then
		addRow("No sky event right now. Come back when the sky changes color!", {}, "☁️")
	end

	-- Luck: works straight away for 10 minutes (each purchase starts the time again), and takes the
	-- common slices off the Hulk Wheel
	if state.luckSecondsLeft and state.luckSecondsLeft > 0 then
		addRow(string.format("Luck %s runs out in %d:%02d", tostring(state.luck), state.luckSecondsLeft // 60, state.luckSecondsLeft % 60), {}, "⏳")
	end
	if state.nextLuck then
		addRow("Luck " .. state.luck .. " > " .. state.nextLuck .. " for " .. math.floor(Catalog.LuckSeconds / 60) .. " min (better Hulk Wheel)", {
			{ text = Catalog.FormatNumber(state.luckMoneyPrice or Catalog.LuckMoneyPriceFor(state.luck)) .. " money", itemId = "luck", method = "money", color = MONEY_COLOR },
			robuxButton(nil, "luck", state.luckPrice),
		})
	else
		addRow("Luck is maxed (" .. state.luck .. ")", {}, "🍀")
	end

	for _, sky in ipairs(Catalog.SkyColors) do
		if state.ownedSkins and state.ownedSkins[sky.id] then
			local wearing = state.skin == sky.id
			local buttons = {}
			if not wearing then
				table.insert(buttons, { text = "EQUIP", itemId = sky.id, action = "wear", color = WEAR_COLOR })
			end
			table.insert(buttons, sellButton(Catalog.ById["skin_" .. sky.id]))
			addRow(sky.name .. " Skin · " .. Catalog.SkinPerkText(sky) .. (wearing and " (equipped)" or ""), buttons)
		end
	end
	if state.skin then
		addRow("Normal look", { { text = "EQUIP", itemId = "none", action = "wear", color = WEAR_COLOR } })
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
				table.insert(buttons, { text = "EQUIP", itemId = sky.id, action = "wear", color = WEAR_COLOR })
			end
			table.insert(buttons, sellButton(item))
			addRow(item.name .. (wearing and " (equipped)" or ""), buttons)
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
	table.clear(wavingStrips) -- the old rows (and their carpet picture) are about to go
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
				"World Champions only: reach %s strength (you have %s)",
				Catalog.FormatNumber(state.vipRequiredStrength),
				Catalog.FormatNumber(state.strength)
			), {}, "🔒")
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

-- The Magic Carpet picture waves while the shop is open: a ripple runs along the rug
game:GetService("RunService").RenderStepped:Connect(function()
	if not frame.Visible or #wavingStrips == 0 then
		return
	end
	local t = os.clock()
	for _, strip in ipairs(wavingStrips) do
		strip.frame.Position = UDim2.new((strip.index - 1) / CARPET_PICTURE_STRIPS, 0, 0.5, math.sin(t * 5 - strip.index * 0.8) * 3)
	end
end)
