-- Normal shop and VIP shop. Items are defined in Modules/Catalog.
-- Robux purchases go through Developer Products (receipts routed via ReceiptRouter);
-- treadmill unlocks can also be bought with in-game money.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Catalog = require(Modules:WaitForChild("Catalog"))
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local ReceiptRouter = require(script.Parent:WaitForChild("ReceiptRouter"))
local Admins = require(script.Parent:WaitForChild("Admins"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local storeEvent = eventsFolder:FindFirstChild("StoreAction")
if not storeEvent then
	storeEvent = Instance.new("RemoteEvent")
	storeEvent.Name = "StoreAction"
	storeEvent.Parent = eventsFolder
end
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local processedReceipts = {}

local productItems = {}
for id, item in pairs(Catalog.ById) do
	if item.productId and item.productId ~= 0 then
		productItems[item.productId] = id
	end
end
for _, productId in ipairs(Catalog.LuckProductIds) do
	if productId ~= 0 then
		productItems[productId] = "luck"
	end
end

local function sendStats(player)
	local data = FighterStats.GetPlayerData(player)
	matchResultEvent:FireClient(player, {
		type = "stats",
		money = data.money,
		strength = data.strength,
		kick = data.kick,
		luck = data.luck,
		bodyStage = data.bodyStage,
		health = data.health,
		stamina = data.stamina,
		maxStamina = data.maxStamina,
		arenaWins = data.arenaWins,
		gameBeats = data.gameBeats,
		rebirths = data.rebirths,
	})
end

local function buildState(player)
	local data = FighterStats.GetPlayerData(player)
	return {
		money = data.money,
		luck = data.luck,
		nextLuck = Catalog.NextLuck(data.luck),
		luckPrice = Catalog.LuckPrice(data.luckPurchases),
		treadmills = data.treadmills,
		carpet = data.carpet,
		carpetPass = data.carpetPass,
		winMultiplier = data.winMultiplier,
		strength = data.strength,
		vipUnlocked = FighterStats.IsWorldChampion(data.strength),
		vipRequiredStrength = FighterStats.Stages[#FighterStats.Stages].minStrength,
		ownedSkins = data.ownedSkins,
		skin = data.skin,
	}
end

local function notify(player, text, success)
	storeEvent:FireClient(player, "notice", text, success, buildState(player))
end

-- ==================== MAGIC CARPET ====================
-- Owning the carpet puts a "Magic Carpet" tool in the backpack. Equipping it shows a rainbow carpet with
-- rainbow fire at the corners under the player; CarpetClient makes them sit and fly (Space up, Q down).

local CARPET_TOOL_NAME = "Magic Carpet"
local CARPET_MODEL_NAME = "MagicCarpet"
local CARPET_STRIPES = {
	Color3.fromRGB(255, 50, 50),
	Color3.fromRGB(255, 150, 30),
	Color3.fromRGB(255, 230, 40),
	Color3.fromRGB(50, 210, 80),
	Color3.fromRGB(50, 120, 255),
	Color3.fromRGB(160, 70, 230),
}
local RAINBOW_FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 130, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 240)),
})

local function addRainbowFire(part, offset)
	local attachment = Instance.new("Attachment")
	attachment.Position = offset
	attachment.Parent = part
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = RAINBOW_FIRE -- each flame runs through the rainbow as it rises
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.4, 0.7)
	fire.Rate = 40
	fire.Speed = NumberRange.new(2, 4)
	fire.SpreadAngle = Vector2.new(15, 15)
	fire.Rotation = NumberRange.new(0, 360)
	fire.RotSpeed = NumberRange.new(-90, 90)
	fire.Parent = attachment
end

local function removeCarpet(character)
	local model = character and character:FindFirstChild(CARPET_MODEL_NAME)
	if model then
		model:Destroy()
	end
end

-- Six rainbow stripes (front to back) welded under the player, with a rainbow flame on each corner
local function attachCarpet(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:FindFirstChild(CARPET_MODEL_NAME) then
		return
	end
	local model = Instance.new("Model")
	model.Name = CARPET_MODEL_NAME
	local stripeLength = 1
	local base = root.CFrame * CFrame.new(0, -1.6, 0.4)
	for i, color in ipairs(CARPET_STRIPES) do
		local stripe = Instance.new("Part")
		stripe.Name = "Stripe" .. i
		stripe.Size = Vector3.new(4, 0.2, stripeLength)
		stripe.Color = color
		stripe.Material = Enum.Material.Neon
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripe.Massless = true
		stripe.CFrame = base * CFrame.new(0, 0, (i - 3.5) * stripeLength)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = stripe
		weld.Parent = stripe
		stripe.Parent = model
		-- Flames on the four corners: both sides of the front and back stripes
		if i == 1 then
			addRainbowFire(stripe, Vector3.new(-2, 0.1, -stripeLength / 2))
			addRainbowFire(stripe, Vector3.new(2, 0.1, -stripeLength / 2))
		elseif i == #CARPET_STRIPES then
			addRainbowFire(stripe, Vector3.new(-2, 0.1, stripeLength / 2))
			addRainbowFire(stripe, Vector3.new(2, 0.1, stripeLength / 2))
		end
	end
	model.Parent = character
end

local function giveCarpetTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or backpack:FindFirstChild(CARPET_TOOL_NAME) or (character and character:FindFirstChild(CARPET_TOOL_NAME)) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = CARPET_TOOL_NAME
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Equip to ride and fly: Space up, Q down"
	tool.Equipped:Connect(function()
		attachCarpet(tool.Parent)
	end)
	tool.Unequipped:Connect(function()
		removeCarpet(player.Character)
	end)
	tool.Parent = backpack
end

-- Color skins: the whole body turns the skin color (clothing is removed so the color shows).
-- The rainbow skin gives each body section its own color from Catalog.RainbowColors.
local BODY_COLOR_PROPERTIES = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

-- Which BodyColors section an R6 or R15 body part belongs to ("LeftUpperArm" -> "LeftArmColor3")
local function bodyColorProperty(partName)
	if partName == "Head" then
		return "HeadColor3"
	elseif string.find(partName, "Torso") then
		return "TorsoColor3"
	end
	for _, side in ipairs({ "Left", "Right" }) do
		if string.find(partName, side) then
			if string.find(partName, "Arm") or string.find(partName, "Hand") then
				return side .. "ArmColor3"
			elseif string.find(partName, "Leg") or string.find(partName, "Foot") then
				return side .. "LegColor3"
			end
		end
	end
	return nil
end

local function skinColor(sky, property)
	if sky.rainbow then
		return Catalog.RainbowColors[table.find(BODY_COLOR_PROPERTIES, property)]
	end
	return sky.color
end

-- The fiery aura (skins with `aura`): flames all over the body
local AURA_PARTS = { "UpperTorso", "Torso", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }
local function removeAura(character)
	for _, item in ipairs(character:GetDescendants()) do
		if item.Name == "SkinAura" then
			item:Destroy()
		end
	end
	character:SetAttribute("DiscoSkin", nil) -- DiscoSkinClient's lights
end
local function addAura(character)
	for _, partName in ipairs(AURA_PARTS) do
		local part = character:FindFirstChild(partName)
		if part then
			local fire = Instance.new("Fire")
			fire.Name = "SkinAura"
			fire.Size = 4
			fire.Heat = 8
			fire.Color = Color3.fromRGB(255, 140, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
			fire.Parent = part
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local glow = Instance.new("PointLight")
		glow.Name = "SkinAura"
		glow.Color = Color3.fromRGB(255, 120, 40)
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = root
	end
end

local function applySkin(player)
	local data = FighterStats.GetPlayerData(player)
	local character = player.Character
	local sky = data.skin and Catalog.SkyColorById[data.skin]
	if character then
		removeAura(character)
	end
	if not character or not sky then
		return
	end
	if sky.aura then
		addAura(character)
	end
	if sky.disco then
		character:SetAttribute("DiscoSkin", true)
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			local property = bodyColorProperty(child.Name)
			if property then
				child.Color = skinColor(sky, property)
			end
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	for _, property in ipairs(BODY_COLOR_PROPERTIES) do
		bodyColors[property] = skinColor(sky, property)
	end
end

-- Puts the player's own avatar look back (body colors and clothing)
local function restoreLook(player)
	local character = player.Character
	if character then
		removeAura(character)
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid:ApplyDescription(Players:GetHumanoidDescriptionFromUserId(player.UserId))
		end)
	end
end

local function grant(player, itemId)
	local data = FighterStats.GetPlayerData(player)
	local item = Catalog.ById[itemId]
	if itemId == "luck" then
		local nextLuck = Catalog.NextLuck(data.luck)
		if not nextLuck then
			return false, "Max luck reached."
		end
		data.luck = nextLuck
		data.luckPurchases += 1
		return true, "Luck is now " .. nextLuck .. "!"
	elseif not item then
		return false, "Unknown item."
	elseif item.kind == "money" then
		data.money += item.amount
		return true, "+" .. Catalog.FormatNumber(item.amount) .. " money!"
	elseif item.kind == "carpet" then
		data.carpet = true
		giveCarpetTool(player)
		return true, "Magic Carpet unlocked! Equip it from your backpack to fly (Space up, Q down)."
	elseif item.kind == "strength" then
		FighterStats.TrainStrength(data, item.amount)
		return true, "+" .. Catalog.FormatNumber(item.amount) .. " strength!"
	elseif item.kind == "kick" then
		FighterStats.TrainKick(data, item.amount)
		return true, "+" .. Catalog.FormatNumber(item.amount) .. " kick!"
	elseif item.kind == "maxluck" then
		data.luck = Catalog.VipMaxLuck
		return true, "2x max luck (" .. Catalog.VipMaxLuck .. ") unlocked!"
	elseif item.kind == "wins10" then
		data.winMultiplier = (data.winMultiplier or 1) * Catalog.WinsMultiplierStep
		return true, "Win rewards are now " .. Catalog.FormatNumber(data.winMultiplier) .. "x!"
	elseif item.kind == "carpetpass" then
		data.carpetPass = true
		return true, "Carpet Parkour Pass unlocked! You can now fly the Magic Carpet over the parkour."
	elseif item.kind == "treadmill" then
		data.treadmills[item.tier] = true
		return true, item.name .. " unlocked!"
	elseif item.kind == "skin" then
		data.ownedSkins[item.colorId] = true
		data.skin = item.colorId
		applySkin(player)
		return true, item.name .. " unlocked and equipped! " .. Catalog.SkinPerkText(Catalog.SkyColorById[item.colorId])
	end
	return false, "Unknown item."
end

local function priceCheck(player, itemId)
	local data = FighterStats.GetPlayerData(player)
	local item = Catalog.ById[itemId]
	if item and item.store == "vip" and not FighterStats.IsWorldChampion(data.strength) then
		return "The VIP shop is for World Champions only."
	end
	if itemId == "luck" then
		if not Catalog.NextLuck(data.luck) then
			return "Max luck reached."
		end
	elseif itemId == "maxluck" and data.luck >= Catalog.VipMaxLuck then
		return "You already have 2x max luck."
	elseif itemId == "carpet" and data.carpet then
		return "You already own the Magic Carpet."
	elseif itemId == "carpetpass" and data.carpetPass then
		return "You already have the Carpet Parkour Pass."
	elseif Catalog.ById[itemId] and Catalog.ById[itemId].kind == "treadmill" and data.treadmills[Catalog.ById[itemId].tier] then
		return "Treadmill already unlocked."
	elseif item and item.kind == "skin" then
		if data.ownedSkins[item.colorId] then
			return "You already own the " .. item.name .. ". Press WEAR to put it on."
		end
		if item.colorId == "disco" then
			-- Only right after a disco party starts: 30 seconds (the owner gets a minute)
			local startedAt = ReplicatedStorage:GetAttribute("DiscoStartedAt")
			local window = Admins.IsOwner(player) and Catalog.DiscoSaleSecondsOwner or Catalog.DiscoSaleSeconds
			if not ReplicatedStorage:GetAttribute("DiscoParty") or not startedAt or workspace:GetServerTimeNow() - startedAt > window then
				return "Too late! The Disco Skin is only sold for " .. window .. " seconds when a disco party starts."
			end
		elseif ReplicatedStorage:GetAttribute("SkyEventColor") ~= item.colorId then
			return "The " .. item.name .. " is only sold during a " .. Catalog.SkyColorById[item.colorId].name .. " sky event."
		end
	end
	return nil
end

local function productFor(itemId, data)
	if itemId == "luck" then
		return Catalog.LuckProductIds[data.luckPurchases + 1] or 0
	end
	return Catalog.ById[itemId].productId
end

local function buy(player, itemId, method)
	if type(itemId) ~= "string" or (itemId ~= "luck" and not Catalog.ById[itemId]) then
		return
	end
	local data = FighterStats.GetPlayerData(player)
	local problem = priceCheck(player, itemId)
	if problem then
		notify(player, problem, false)
		return
	end

	if method == "money" then
		local item = Catalog.ById[itemId]
		if not item or not item.money then
			notify(player, "This item can only be bought with Robux.", false)
			return
		end
		if data.money < item.money then
			notify(player, "Not enough money. Cost: " .. Catalog.FormatNumber(item.money), false)
			return
		end
		data.money -= item.money
		local _, message = grant(player, itemId)
		sendStats(player)
		notify(player, message, true)
	elseif method == "robux" then
		local productId = productFor(itemId, data)
		if productId == 0 then
			if RunService:IsStudio() then
				local _, message = grant(player, itemId)
				sendStats(player)
				notify(player, message .. " (Studio test grant)", true)
			else
				notify(player, "This item isn't for sale yet (no Developer Product ID).", false)
			end
			return
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end

ReceiptRouter.Register(function(receipt)
	local itemId = productItems[receipt.ProductId]
	if not itemId then
		return nil
	end
	if processedReceipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, message = grant(player, itemId)
	processedReceipts[receipt.PurchaseId] = true
	sendStats(player)
	notify(player, ok and message or (message .. " Contact the owner for a refund."), ok)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end)

-- Sell an owned lasting item back for its price in money (see Catalog.CanSell / Catalog.SellPrice)
local function sell(player, itemId)
	local item = type(itemId) == "string" and Catalog.ById[itemId] or nil
	if not Catalog.CanSell(item) then
		notify(player, "That can't be sold.", false)
		return
	end
	local data = FighterStats.GetPlayerData(player)
	local owned
	if item.kind == "carpet" then
		owned = data.carpet
	elseif item.kind == "carpetpass" then
		owned = data.carpetPass
	elseif item.kind == "treadmill" then
		owned = data.treadmills[item.tier]
	elseif item.kind == "skin" then
		owned = data.ownedSkins[item.colorId]
	end
	if not owned then
		notify(player, "You don't own the " .. item.name .. ".", false)
		return
	end

	if item.kind == "carpet" then
		data.carpet = false
		local character = player.Character
		for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), character }) do
			local tool = container and container:FindFirstChild(CARPET_TOOL_NAME)
			if tool then
				tool:Destroy()
			end
		end
		removeCarpet(character)
	elseif item.kind == "carpetpass" then
		data.carpetPass = false
	elseif item.kind == "treadmill" then
		data.treadmills[item.tier] = nil
		if item.tier == "owner" then
			data.ownerTreadmillAnywhere = false
		end
	elseif item.kind == "skin" then
		data.ownedSkins[item.colorId] = nil
		if data.skin == item.colorId then
			data.skin = nil
			restoreLook(player)
		end
	end

	local price = Catalog.SellPrice(item)
	data.money += price
	sendStats(player)
	notify(player, "Sold the " .. item.name .. " for " .. Catalog.FormatNumber(price) .. " money.", true)
end

-- Sell any other tool from the backpack (see Catalog.BackpackToolSellPrice). Every copy of it goes, and
-- it's remembered so copies that come back later (after respawning) are removed instead of sold again.
local function sellTool(player, toolName)
	if type(toolName) ~= "string" or toolName == CARPET_TOOL_NAME then
		return -- the Magic Carpet is sold as a shop item
	end
	local data = FighterStats.GetPlayerData(player)
	if data.soldTools[toolName] then
		notify(player, "You already sold the " .. toolName .. ".", false)
		return
	end
	local found = false
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == toolName then
					child:Destroy()
					found = true
				end
			end
		end
	end
	if not found then
		notify(player, "You don't have the " .. toolName .. ".", false)
		return
	end
	data.soldTools[toolName] = true
	data.money += Catalog.BackpackToolSellPrice
	sendStats(player)
	notify(player, "Sold the " .. toolName .. " for " .. Catalog.FormatNumber(Catalog.BackpackToolSellPrice) .. " money.", true)
end

-- Removes sold tools that show up again in a backpack (StarterPack items come back on every respawn)
local function watchBackpack(player, backpack)
	local function check(child)
		if child:IsA("Tool") and FighterStats.GetPlayerData(player).soldTools[child.Name] then
			task.defer(function()
				child:Destroy()
			end)
		end
	end
	backpack.ChildAdded:Connect(check)
	for _, child in ipairs(backpack:GetChildren()) do
		check(child)
	end
end

-- Switch between owned color skins, or "none" for the player's normal look
local function wear(player, colorId)
	local data = FighterStats.GetPlayerData(player)
	if colorId == "none" then
		if data.skin then
			data.skin = nil
			restoreLook(player)
		end
		notify(player, "Back to your normal look.", true)
	elseif type(colorId) == "string" and data.ownedSkins[colorId] then
		data.skin = colorId
		applySkin(player)
		local sky = Catalog.SkyColorById[colorId]
		notify(player, "Wearing the " .. sky.name .. " skin! " .. Catalog.SkinPerkText(sky), true)
	end
end

storeEvent.OnServerEvent:Connect(function(player, action, itemId, method)
	if action == "buy" then
		buy(player, itemId, method)
	elseif action == "wear" then
		wear(player, itemId)
	elseif action == "sell" then
		sell(player, itemId)
	elseif action == "sellTool" then
		sellTool(player, itemId)
	end
end)

local function hookKiosk(prompt)
	prompt.Triggered:Connect(function(player)
		storeEvent:FireClient(player, "open", prompt:GetAttribute("Store"), buildState(player))
	end)
end
for _, prompt in ipairs(CollectionService:GetTagged("StoreKiosk")) do
	hookKiosk(prompt)
end
CollectionService:GetInstanceAddedSignal("StoreKiosk"):Connect(hookKiosk)

-- Treadmill locked: FlowService fires this
local openStore = Instance.new("BindableEvent")
openStore.Name = "OpenStore"
openStore.Parent = script
openStore.Event:Connect(function(player, store)
	storeEvent:FireClient(player, "open", store, buildState(player))
end)

Players.PlayerAdded:Connect(function(player)
	-- Each respawn gets a new backpack, so hand the carpet tool back when it appears
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(player, child)
			if FighterStats.GetPlayerData(player).carpet then
				giveCarpetTool(player)
			end
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchBackpack(player, backpack)
	end
	-- Re-apply the worn color skin after each respawn, once the avatar's clothes have loaded
	player.CharacterAppearanceLoaded:Connect(function()
		applySkin(player)
	end)
end)

-- Skins with strengthPerSecond give that much strength, kick and stamina every second while worn
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = FighterStats.GetPlayerData(player)
			local sky = data.skin and Catalog.SkyColorById[data.skin]
			if sky and sky.strengthPerSecond then
				FighterStats.TrainStrength(data, sky.strengthPerSecond)
				FighterStats.TrainKick(data, sky.strengthPerSecond)
				data.maxStamina += sky.strengthPerSecond
				data.stamina = data.maxStamina
				sendStats(player)
			end
		end
	end
end)

-- The owner always owns every skin color, from the start (new skins too)
local function giveOwnerSkins(player)
	if Admins.IsOwner(player) then
		local data = FighterStats.GetPlayerData(player)
		for _, sky in ipairs(Catalog.SkyColors) do
			data.ownedSkins[sky.id] = true
		end
	end
end
Players.PlayerAdded:Connect(giveOwnerSkins)
for _, player in ipairs(Players:GetPlayers()) do
	giveOwnerSkins(player)
end

-- Saved progress arrives a moment after joining (PlayerDataService): give back the Magic Carpet and
-- put the worn skin back on
script.Parent:WaitForChild("PlayerDataService"):WaitForChild("DataLoaded").Event:Connect(function(player)
	giveOwnerSkins(player) -- the saved list replaced the one given on joining
	if FighterStats.GetPlayerData(player).carpet then
		giveCarpetTool(player)
	end
	applySkin(player)
	-- Tools sold on an earlier visit may already be back in the backpack from the StarterPack
	local backpack = player:FindFirstChildOfClass("Backpack")
	local soldTools = FighterStats.GetPlayerData(player).soldTools or {}
	for _, child in ipairs(backpack and backpack:GetChildren() or {}) do
		if child:IsA("Tool") and soldTools[child.Name] then
			child:Destroy()
		end
	end
end)

-- Riding the Magic Carpet outside the map (over the parkour) kills you unless you have the Carpet
-- Parkour Pass. The owner is never stopped.
local carpetNotice = Instance.new("RemoteEvent")
carpetNotice.Name = "CarpetNotice"
carpetNotice.Parent = eventsFolder

local MAP_EDGE = WorldConfig.GroundSize / 2 + WorldConfig.WallThickness

task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and character:FindFirstChild(CARPET_MODEL_NAME) then
				local offset = root.Position - WorldConfig.Arena.Center
				local outsideMap = math.abs(offset.X) > MAP_EDGE or math.abs(offset.Z) > MAP_EDGE
				if outsideMap and not FighterStats.GetPlayerData(player).carpetPass and not Admins.IsOwner(player) then
					humanoid.Health = 0
					carpetNotice:FireClient(player)
				end
			end
		end
	end
end)
