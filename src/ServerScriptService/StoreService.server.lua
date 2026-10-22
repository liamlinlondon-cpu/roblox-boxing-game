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
local ReceiptRouter = require(script.Parent:WaitForChild("ReceiptRouter"))

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
		winMultiplier = data.winMultiplier,
		strength = data.strength,
		vipUnlocked = FighterStats.IsWorldChampion(data.strength),
		vipRequiredStrength = FighterStats.Stages[#FighterStats.Stages].minStrength,
	}
end

local function notify(player, text, success)
	storeEvent:FireClient(player, "notice", text, success, buildState(player))
end

local function attachCarpet(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or character:FindFirstChild("BasicCarpet") then
		return
	end
	local carpet = Instance.new("Part")
	carpet.Name = "BasicCarpet"
	carpet.Size = Vector3.new(4, 0.2, 6)
	carpet.Color = Color3.fromRGB(150, 30, 40)
	carpet.Material = Enum.Material.Fabric
	carpet.CanCollide = false
	carpet.Massless = true
	carpet.CFrame = root.CFrame * CFrame.new(0, -3.1, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carpet
	weld.Parent = carpet
	carpet.Parent = character
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
		if player.Character then
			attachCarpet(player.Character)
		end
		return true, "Basic carpet unlocked!"
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
	elseif item.kind == "treadmill" then
		data.treadmills[item.tier] = true
		return true, item.name .. " unlocked!"
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
		return "You already own the carpet."
	elseif Catalog.ById[itemId] and Catalog.ById[itemId].kind == "treadmill" and data.treadmills[Catalog.ById[itemId].tier] then
		return "Treadmill already unlocked."
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
		if not item or item.kind ~= "treadmill" then
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

storeEvent.OnServerEvent:Connect(function(player, action, itemId, method)
	if action == "buy" then
		buy(player, itemId, method)
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
	player.CharacterAdded:Connect(function(character)
		if FighterStats.GetPlayerData(player).carpet then
			attachCarpet(character)
		end
	end)
end)
