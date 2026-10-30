-- Private servers with a number. A player buys one with Robux in the game (WorldConfig.PrivateServers:
-- 100 Robux for a month) and gets their own server and a 6-digit number for it. Buying again adds another
-- month and keeps the number. Once it runs out, nobody can join it until it's bought again. Anyone who types that number
-- in the private server panel (PrivateServerClient) joins that server, so the buyer shares the number with
-- friends; the owner can join any of them the same way. Each number points to a reserved server
-- (TeleportService:ReserveServer); the number and its access code are kept in a DataStore.
--
-- Inside one, ReplicatedStorage's "PrivateServerNumber" attribute says which number it is (it's sent
-- along when players teleport in), so the panel can show it. Teleports only work in the real game.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Admins = require(script.Parent:WaitForChild("Admins"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local ReceiptRouter = require(script.Parent:WaitForChild("ReceiptRouter"))

local CONFIG = WorldConfig.PrivateServers
local codeStore = DataStoreService:GetDataStore("PrivateServerNumbers_v1") -- "n_<number>" = { accessCode, ownerId, expiresAt }
local PERIOD = CONFIG.Days * 24 * 60 * 60

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local privateServerFunction = Instance.new("RemoteFunction")
privateServerFunction.Name = "PrivateServer"
privateServerFunction.Parent = eventsFolder
local privateServerNotice = Instance.new("RemoteEvent") -- server -> client: e.g. a teleport that failed
privateServerNotice.Name = "PrivateServerNotice"
privateServerNotice.Parent = eventsFolder

local processedReceipts = {}
local busy = {} -- one buy/join at a time per player

-- ==================== WHICH SERVER IS THIS? ====================
local function noteNumberFrom(player)
	if ReplicatedStorage:GetAttribute("PrivateServerNumber") then
		return
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	local data = ok and joinData and joinData.TeleportData
	if type(data) == "table" and tonumber(data.privateServerNumber) and game.PrivateServerId ~= "" then
		ReplicatedStorage:SetAttribute("PrivateServerNumber", tonumber(data.privateServerNumber))
	end
end
Players.PlayerAdded:Connect(noteNumberFrom)
for _, player in ipairs(Players:GetPlayers()) do
	noteNumberFrom(player)
end

-- ==================== MAKING ONE ====================
-- One paid month: a player with a server gets another month on it (same number); anyone else gets a new
-- reserved server and a free 6-digit number. Returns the number, or nil and why not.
local function addMonth(player)
	local data = FighterStats.GetPlayerData(player)
	local now = os.time()
	local expiresAt = math.max(now, data.privateServerExpiresAt or 0) + PERIOD
	if data.privateServerNumber then
		local ok = pcall(codeStore.UpdateAsync, codeStore, "n_" .. data.privateServerNumber, function(entry)
			if type(entry) ~= "table" then
				return nil
			end
			entry.expiresAt = expiresAt
			return entry
		end)
		if not ok then
			return nil, "Couldn't renew your server right now. Try again."
		end
		data.privateServerExpiresAt = expiresAt
		return data.privateServerNumber
	end
	local reserved, accessCode = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not reserved then
		return nil, RunService:IsStudio() and "Private servers only work in the real game (publish it and try there)." or "Couldn't make your server right now. Try again."
	end
	for _ = 1, 10 do
		local number = math.random(100000, 999999)
		local claimed = false
		local ok = pcall(codeStore.UpdateAsync, codeStore, "n_" .. number, function(old)
			if old then
				return nil -- that number is taken, try another
			end
			claimed = true
			return { accessCode = accessCode, ownerId = player.UserId, expiresAt = expiresAt }
		end)
		if ok and claimed then
			data.privateServerNumber = number
			data.privateServerExpiresAt = expiresAt
			return number
		end
	end
	return nil, "Couldn't make your server right now. Try again."
end

-- ==================== JOINING ONE ====================
local function join(player, number)
	number = tonumber(number)
	if not number or number < 100000 or number > 999999 then
		return "Type a 6-digit server number."
	end
	if ReplicatedStorage:GetAttribute("PrivateServerNumber") == number then
		return "You're already in private server #" .. number .. "!"
	end
	local ok, entry = pcall(codeStore.GetAsync, codeStore, "n_" .. math.floor(number))
	if not ok then
		return "Couldn't look that number up right now. Try again."
	end
	if type(entry) ~= "table" or not entry.accessCode then
		return "There's no private server #" .. math.floor(number) .. "."
	end
	-- Ran out: closed until its owner buys another month (the game's owner can still go in)
	if entry.expiresAt and entry.expiresAt < os.time() and not Admins.IsOwner(player) then
		return "Private server #" .. math.floor(number) .. " has run out. Its owner can renew it for " .. CONFIG.Robux .. " Robux."
	end
	if RunService:IsStudio() then
		return "Joining only works in the real game (publish it and try there)."
	end
	local teleported, err = pcall(TeleportService.TeleportToPrivateServer, TeleportService, game.PlaceId, entry.accessCode, { player }, nil, {
		privateServerNumber = math.floor(number),
	})
	if not teleported then
		return "Couldn't join: " .. tostring(err)
	end
	return "Joining private server #" .. math.floor(number) .. "..."
end

TeleportService.TeleportInitFailed:Connect(function(player, _, message)
	privateServerNotice:FireClient(player, "Couldn't join that server: " .. tostring(message))
end)

-- ==================== BUYING ONE ====================
ReceiptRouter.Register(function(receipt)
	if CONFIG.ProductId == 0 or receipt.ProductId ~= CONFIG.ProductId then
		return nil
	end
	if processedReceipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local number = addMonth(player)
	if not number then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again later
	end
	processedReceipts[receipt.PurchaseId] = true
	privateServerNotice:FireClient(player, "Private server #" .. number .. " is yours for another " .. CONFIG.Days .. " days!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end)

-- Buying (or renewing) a month
local function buy(player)
	if CONFIG.ProductId == 0 then
		if RunService:IsStudio() then
			local number, problem = addMonth(player)
			return number and ("Private server #" .. number .. " is yours for " .. CONFIG.Days .. " days! (Studio test, no Robux)") or problem
		end
		return "Private servers aren't for sale yet (no Developer Product ID)."
	end
	MarketplaceService:PromptProductPurchase(player, CONFIG.ProductId)
	return nil
end

privateServerFunction.OnServerInvoke = function(player, action, value)
	if busy[player] then
		return { message = "One moment..." }
	end
	busy[player] = true
	local ok, message = pcall(function()
		if action == "buy" then
			return buy(player)
		elseif action == "join" then
			return join(player, value)
		elseif action == "mine" then
			local data = FighterStats.GetPlayerData(player)
			if not data.privateServerNumber then
				return "You don't have a private server yet."
			elseif (data.privateServerExpiresAt or 0) < os.time() then
				return "Your private server ran out. Renew it for " .. CONFIG.Robux .. " Robux."
			end
			return join(player, data.privateServerNumber)
		end
		return nil
	end)
	busy[player] = nil
	local data = FighterStats.GetPlayerData(player)
	return {
		message = ok and message or "Something went wrong. Try again.",
		mine = data.privateServerNumber,
		secondsLeft = data.privateServerExpiresAt and math.max(0, data.privateServerExpiresAt - os.time()) or 0,
		here = ReplicatedStorage:GetAttribute("PrivateServerNumber"),
		price = CONFIG.Robux,
		days = CONFIG.Days,
	}
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
