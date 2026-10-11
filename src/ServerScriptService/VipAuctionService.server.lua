-- VIP floor auctions. Every 30-minute session, each gym's VIP floor goes to the highest bidders.
--
-- How it works (Roblox can't hold Robux in escrow, so only winners are charged):
--   1. During a session, players bid a Robux tier for the NEXT session at one gym (one bid per player).
--   2. When the session ends, bids are ranked (higher tier first, earlier bid wins ties) and the top
--      SlotsPerGym bidders are prompted to buy the Developer Product for their tier.
--   3. Anyone who declines or doesn't pay within PaymentWindowSeconds is skipped and the next bidder is asked.
--   4. Slots still free after the queue runs out can be bought directly at the lowest tier.
-- VIP access lasts until the session ends; VIPs are then moved back to the ground floor.
--
-- This script owns MarketplaceService.ProcessReceipt. Roblox allows only one handler per game,
-- so any future Developer Products must be routed through it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local VIP = WorldConfig.Vip
local GYM = WorldConfig.Gyms

local auctionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VipAuction")

local function now()
	return Workspace:GetServerTimeNow()
end

local tierByProduct = {}
for index, tier in ipairs(VIP.Tiers) do
	if tier.productId ~= 0 then
		tierByProduct[tier.productId] = index
	elseif RunService:IsStudio() then
		warn(string.format("VIP tier %d (%d R$) has no productId: purchases are granted free in Studio only.", index, tier.robux))
	else
		warn(string.format("VIP tier %d (%d R$) has no productId: it cannot be purchased.", index, tier.robux))
	end
end

local gyms = {}
for index, info in ipairs(GYM.List) do
	gyms[index] = {
		id = index,
		name = info.name,
		cframe = WorldConfig.GetGymCFrame(index),
		vipUsers = {}, -- [userId] = true: paid for the current session
		offers = {}, -- [userId] = { tier, expiresAt }: won a slot, waiting for payment
		lapsed = {}, -- [userId] = tier: offer timed out or player left; a late payment is still honored
		queue = {}, -- ranked bidders from the last auction not yet offered a slot
	}
end

local bids = {} -- [userId] = { gymId, tier, time }: bids for the next session
local sessionEndsAt = now() + VIP.SessionSeconds
local processedReceipts = {}
local lastAction = {}

local function countKeys(map)
	local count = 0
	for _ in pairs(map) do
		count += 1
	end
	return count
end

local function keyList(map)
	local list = {}
	for key in pairs(map) do
		table.insert(list, key)
	end
	return list
end

local function compareBids(a, b)
	if a.tier ~= b.tier then
		return a.tier > b.tier
	end
	return a.time < b.time
end

local function openSlotCount(gym)
	if #gym.queue > 0 then
		return 0
	end
	return math.max(0, VIP.SlotsPerGym - countKeys(gym.vipUsers) - countKeys(gym.offers))
end

local function findOffer(userId)
	for _, gym in ipairs(gyms) do
		if gym.offers[userId] then
			return gym, gym.offers[userId]
		end
	end
	return nil
end

local function findLapsed(userId)
	for _, gym in ipairs(gyms) do
		if gym.lapsed[userId] then
			return gym
		end
	end
	return nil
end

local function rankedBids(gymId)
	local list = {}
	for userId, bid in pairs(bids) do
		local player = Players:GetPlayerByUserId(userId)
		if bid.gymId == gymId and player then
			table.insert(list, {
				userId = userId,
				name = player.DisplayName,
				tier = bid.tier,
				robux = VIP.Tiers[bid.tier].robux,
				time = bid.time,
			})
		end
	end
	table.sort(list, compareBids)
	return list
end

local function buildState()
	local state = {
		sessionEndsAt = sessionEndsAt,
		slots = VIP.SlotsPerGym,
		gyms = {},
	}
	for _, gym in ipairs(gyms) do
		state.gyms[gym.id] = {
			name = gym.name,
			vipCount = countKeys(gym.vipUsers),
			vipUserIds = keyList(gym.vipUsers),
			offerUserIds = keyList(gym.offers),
			openSlots = openSlotCount(gym),
			bids = rankedBids(gym.id),
		}
	end
	return state
end

local function broadcast()
	auctionEvent:FireAllClients("state", buildState())
end

local function notify(player, text)
	auctionEvent:FireClient(player, "notice", text)
end

local function teleport(player, cframe)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
	end
end

local function isInVipZone(gym, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local p = gym.cframe:PointToObjectSpace(root.Position)
	-- Covers the VIP floor and the roof above it
	return math.abs(p.X) < GYM.Width / 2
		and math.abs(p.Z) < GYM.Depth / 2
		and p.Y > GYM.FloorHeight + 1
		and p.Y < GYM.FloorHeight * 2 + 8
end

local function grantVip(gym, userId)
	gym.offers[userId] = nil
	gym.lapsed[userId] = nil
	gym.vipUsers[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		notify(player, "VIP unlocked at " .. gym.name .. "! Use the gold elevator pad.")
	end
	broadcast()
end

local function makeOffer(gym, player, tierIndex)
	local tier = VIP.Tiers[tierIndex]
	local userId = player.UserId

	if tier.productId == 0 and not RunService:IsStudio() then
		notify(player, "VIP purchases aren't set up yet.")
		return false
	end

	gym.offers[userId] = { tier = tierIndex, expiresAt = now() + VIP.PaymentWindowSeconds }
	notify(player, string.format("You got a VIP slot at %s! Complete the %d R$ purchase within %d seconds.", gym.name, tier.robux, VIP.PaymentWindowSeconds))

	if tier.productId == 0 then
		-- Studio test mode: grant without a real purchase
		task.delay(1, function()
			if gym.offers[userId] then
				grantVip(gym, userId)
			end
		end)
	else
		MarketplaceService:PromptProductPurchase(player, tier.productId)
	end
	return true
end

local function fillOffers(gym)
	while countKeys(gym.vipUsers) + countKeys(gym.offers) < VIP.SlotsPerGym and #gym.queue > 0 do
		local entry = table.remove(gym.queue, 1)
		local player = Players:GetPlayerByUserId(entry.userId)
		if player and not findOffer(entry.userId) then
			makeOffer(gym, player, entry.tier)
		end
	end
end

local function rotateSession()
	sessionEndsAt = now() + VIP.SessionSeconds

	local rankedByGym = {}
	for _, gym in ipairs(gyms) do
		rankedByGym[gym.id] = rankedBids(gym.id)
	end
	table.clear(bids)

	for _, gym in ipairs(gyms) do
		local previousVips = gym.vipUsers

		-- Payments still in flight from the old session are honored in the new one
		local lapsed = {}
		for userId, offer in pairs(gym.offers) do
			lapsed[userId] = offer.tier
		end

		gym.vipUsers = {}
		gym.offers = {}
		gym.lapsed = lapsed
		gym.queue = rankedByGym[gym.id]

		for userId in pairs(previousVips) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				if isInVipZone(gym, player) then
					teleport(player, WorldConfig.GetGymPoint(gym.id, GYM.Points.GroundArrival))
				end
				notify(player, "Your VIP session at " .. gym.name .. " has ended.")
			end
		end

		fillOffers(gym)
	end

	broadcast()
end

local function expireOffers()
	local changed = false
	for _, gym in ipairs(gyms) do
		for userId, offer in pairs(gym.offers) do
			if now() >= offer.expiresAt then
				gym.offers[userId] = nil
				gym.lapsed[userId] = offer.tier
				changed = true
				local player = Players:GetPlayerByUserId(userId)
				if player then
					notify(player, "Your VIP purchase window expired; the slot went to the next bidder.")
				end
			end
		end
		fillOffers(gym)
	end
	if changed then
		broadcast()
	end
end

local function enforceVipZones()
	for _, player in ipairs(Players:GetPlayers()) do
		for _, gym in ipairs(gyms) do
			if not gym.vipUsers[player.UserId] and isInVipZone(gym, player) then
				teleport(player, WorldConfig.GetGymPoint(gym.id, GYM.Points.Entrance))
				notify(player, "The VIP floor is for this session's winning bidders.")
			end
		end
	end
end

-- ==================== PURCHASES ====================

MarketplaceService.ProcessReceipt = function(receipt)
	if processedReceipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not tierByProduct[receipt.ProductId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local gym = findOffer(receipt.PlayerId) or findLapsed(receipt.PlayerId)
	if not gym then
		warn("VIP receipt with no matching offer", receipt.PlayerId, receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantVip(gym, receipt.PlayerId)
	processedReceipts[receipt.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if isPurchased then
		return -- granted in ProcessReceipt
	end
	local gym, offer = findOffer(userId)
	if gym and VIP.Tiers[offer.tier].productId == productId then
		gym.offers[userId] = nil
		fillOffers(gym)
		broadcast()
	end
end)

-- ==================== CLIENT REQUESTS ====================

auctionEvent.OnServerEvent:Connect(function(player, action, gymId, tierIndex)
	local clock = os.clock()
	if lastAction[player] and clock - lastAction[player] < 0.25 then
		return
	end
	lastAction[player] = clock

	local userId = player.UserId

	if action == "requestState" then
		auctionEvent:FireClient(player, "state", buildState())
		return
	end

	if action == "cancel" then
		if bids[userId] then
			bids[userId] = nil
			notify(player, "Bid cancelled.")
			broadcast()
		end
		return
	end

	local gym = typeof(gymId) == "number" and gyms[gymId] or nil
	if not gym then
		return
	end

	if action == "bid" then
		local tier = typeof(tierIndex) == "number" and VIP.Tiers[tierIndex] or nil
		if not tier then
			return
		end
		local existing = bids[userId]
		if existing and existing.gymId == gymId and existing.tier == tierIndex then
			return
		end
		bids[userId] = { gymId = gymId, tier = tierIndex, time = os.clock() }
		notify(player, string.format("Bid placed: %d R$ for %s next session. You only pay if you win.", tier.robux, gym.name))
		broadcast()
	elseif action == "buyOpenSlot" then
		if gym.vipUsers[userId] then
			notify(player, "You're already VIP here this session.")
		elseif findOffer(userId) then
			notify(player, "Finish your pending VIP purchase first.")
		elseif openSlotCount(gym) <= 0 then
			notify(player, "No open VIP slots right now. Bid for the next session instead.")
		elseif makeOffer(gym, player, 1) then
			broadcast()
		end
	end
end)

-- ==================== PROMPTS ====================

local function hookTag(tag, handler)
	local function hook(prompt)
		prompt.Triggered:Connect(function(player)
			local gym = gyms[prompt:GetAttribute("GymId")]
			if gym then
				handler(gym, player)
			end
		end)
	end
	for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

hookTag("VipBoard", function(gym, player)
	auctionEvent:FireClient(player, "open", gym.id, buildState())
end)

hookTag("VipElevator", function(gym, player)
	if gym.vipUsers[player.UserId] then
		teleport(player, WorldConfig.GetGymPoint(gym.id, GYM.Points.VipArrival))
	else
		notify(player, "The VIP floor is for this session's winning bidders.")
		auctionEvent:FireClient(player, "open", gym.id, buildState())
	end
end)

hookTag("VipExit", function(gym, player)
	teleport(player, WorldConfig.GetGymPoint(gym.id, GYM.Points.GroundArrival))
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	bids[userId] = nil
	lastAction[player] = nil
	-- Paid VIP slots are kept so the player can rejoin this server during their session
	for _, gym in ipairs(gyms) do
		local offer = gym.offers[userId]
		if offer then
			gym.offers[userId] = nil
			gym.lapsed[userId] = offer.tier
			fillOffers(gym)
		end
	end
	broadcast()
end)

task.spawn(function()
	while true do
		task.wait(1)
		if now() >= sessionEndsAt then
			rotateSession()
		end
		expireOffers()
		enforceVipZones()
	end
end)
