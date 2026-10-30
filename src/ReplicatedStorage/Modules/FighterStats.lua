local Catalog = require(script.Parent:WaitForChild("Catalog"))

local FighterStats = {}

FighterStats.BASE_STAMINA = 100

FighterStats.TreadmillTiers = {
	regular = { name = "Regular Treadmill", multiplier = 1, gain = 50 },
	hacker = { name = "Hacker's Treadmill", multiplier = 1000, gain = 50000 },
	admin = { name = "Admin Treadmill", multiplier = 10000000, gain = 50000000 },
	owner = { name = "Owner's Treadmill", multiplier = 100000000000, gain = 5000000000000, privateServerOnly = true },
}

FighterStats.StaminaCosts = {
	punch = 10,
	kick = 15,
	combo = 25,
	knee = 20,
	block = 5,
}

local sharedPlayerData = {}

function FighterStats.CreatePlayerData()
	return {
		strength = 10,
		kick = 10,
		luck = 1,
		money = 100, -- every new player starts with 100 money
		bodyStage = "Skinny Bones",
		health = 100,
		stamina = FighterStats.BASE_STAMINA,
		maxStamina = FighterStats.BASE_STAMINA,
		arenaWins = 0,
		arenaLosses = 0,
		isInMatch = false,
		treadmills = { regular = true },
		luckPurchases = 0,
		winMultiplier = 1,
		carpet = false,
		carpetPass = false, -- may ride the Magic Carpet outside the map, over the parkour
		gameBeats = 0, -- times the player pressed the red button and beat the game
		rebirths = 0, -- 0 to FighterStats.MaxRebirths
		milestoneRewarded = false, -- got the 2 million strength/kick/stamina reward (RebirthService)
		hulkSpinsGiven = false, -- got the Hulk Wheel spins for turning Hulk (HulkWheelService), once only
		hulkSpins = 0, -- Hulk Wheel spins left
		moneyGoal = nil, -- the current money goal at the top of the screen (MoneyGoalService)
		luckExpiresAt = nil, -- os.time() when bought luck runs out (StoreService); nil = luck doesn't run out
		permanentLuck = 1, -- what luck goes back to when bought luck runs out (VIP max luck, admin-set luck)
		rebirthSkips = 0, -- rebirths skipped with Robux (each skip costs double the last)
		privateServerNumber = nil, -- the number of the private server they bought (PrivateServerService)
		privateServerExpiresAt = nil, -- os.time() when it runs out (buying again adds a month)
		robuxSpent = 0, -- real Robux spent on purchases in this game (counted when a receipt is granted)
		soldTools = {}, -- [toolName] = true: backpack tools sold at the Sell Shop, removed if they come back
		ownedSkins = {}, -- [colorId] = true, bought in the Color Shop during sky events
		ownerTreadmillAnywhere = false, -- given with the owner's /give: may use the Owner's Treadmill in public servers
		skin = nil, -- colorId currently worn, or nil for the player's normal look
	}
end

-- Server-side player data shared between all services
function FighterStats.GetPlayerData(player)
	if not sharedPlayerData[player] then
		sharedPlayerData[player] = FighterStats.CreatePlayerData()
	end
	return sharedPlayerData[player]
end

-- Puts a player's stats back to a new player's. The same table is refilled in place, so any
-- service still holding it sees the reset values.
function FighterStats.ResetPlayerData(player)
	local data = FighterStats.GetPlayerData(player)
	table.clear(data)
	for key, value in pairs(FighterStats.CreatePlayerData()) do
		data[key] = value
	end
	return data
end

-- Body stages by minimum strength, lowest first (also drives the strength bar on screen)
FighterStats.Stages = {
	{ minStrength = 0, name = "Skinny Bones" },
	{ minStrength = 20, name = "Average Boxer" },
	{ minStrength = 40, name = "Rising Fighter" },
	{ minStrength = 70, name = "Strong Athlete" },
	{ minStrength = 120, name = "Power Puncher" },
	{ minStrength = 180, name = "Elite Boxer" },
	{ minStrength = 250, name = "World Champion" },
}

-- Returns the index of the stage the player is in
function FighterStats.GetStageIndex(strength)
	local index = 1
	for i, stage in ipairs(FighterStats.Stages) do
		if strength >= stage.minStrength then
			index = i
		end
	end
	return index
end

function FighterStats.GetStageFromStrength(strength)
	return FighterStats.Stages[FighterStats.GetStageIndex(strength)].name
end

-- The top stage; required to use the VIP shop
function FighterStats.IsWorldChampion(strength)
	return FighterStats.GetStageIndex(strength) == #FighterStats.Stages
end

function FighterStats.TrainStrength(data, amount)
	data.strength = data.strength + amount
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	data.health = 100
end

function FighterStats.TrainKick(data, amount)
	data.kick = data.kick + amount
	data.health = 100
end

-- Adds one treadmill payout (times `multiplier`, e.g. the rebirth boost). Who may use which treadmill is
-- checked before running (FlowService), so the owner and gifted players get paid too.
function FighterStats.TrainStamina(data, tierKey, multiplier)
	local tier = FighterStats.TreadmillTiers[tierKey]
	if not tier then
		return false
	end
	data.maxStamina = data.maxStamina + tier.gain * (multiplier or 1)
	data.stamina = data.maxStamina
	return true, tier
end

-- ==================== REBIRTHS ====================
-- Up to MaxRebirths. The first rebirth needs 100 strength, 100 kick and 1,000 max stamina, and every
-- rebirth after that needs double the one before (1+1=2, 2+2=4, ...). Rebirthing resets those three,
-- wins and the beat the game count to the start (money stays), and adds +1x to training gains (bags and
-- treadmills) for good.
FighterStats.MaxRebirths = 9
local FIRST_REBIRTH = { strength = 100, kick = 100, stamina = 1000 }

-- What rebirth number n (1 = the first) needs
function FighterStats.RebirthRequirement(n)
	local scale = 2 ^ (n - 1)
	return {
		strength = FIRST_REBIRTH.strength * scale,
		kick = FIRST_REBIRTH.kick * scale,
		stamina = FIRST_REBIRTH.stamina * scale,
	}
end

-- Training gain boost from rebirths: 1x with none, 2x after one, ... 6x after five
-- Skip Rebirth (Robux): a rebirth without the strength/kick/stamina needed. 137 Robux the first time,
-- double every skip after (137, 274, 548, ...). One Developer Product per price, in order.
FighterStats.SkipRebirthBasePrice = 137
FighterStats.SkipRebirthProductIds = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }

function FighterStats.SkipRebirthPrice(skips)
	return FighterStats.SkipRebirthBasePrice * 2 ^ (skips or 0)
end

-- Money from winning doubles with every rebirth: 1 rebirth = 2x, 2 = 4x, 3 = 8x, ...
function FighterStats.MoneyMultiplier(data)
	return 2 ^ (data.rebirths or 0)
end

function FighterStats.RebirthMultiplier(data)
	return 1 + (data.rebirths or 0)
end

-- Walk speed and jump power boost from rebirths: +15 after the first, doubling each time
-- (+30, +60, +120, ...). Normal walk speed is 16 and jump power 50.
FighterStats.BaseWalkSpeed = 16
FighterStats.BaseJumpPower = 50
-- The highest walk speed or jump power a character actually gets: Roblox's physics freezes or flings
-- characters far beyond this (the rebirth boost reaches it around rebirth 8)
FighterStats.MaxMoveValue = 1000
function FighterStats.RebirthSpeedBoost(rebirths)
	if (rebirths or 0) <= 0 then
		return 0
	end
	return 15 * 2 ^ (rebirths - 1)
end

function FighterStats.ResetStamina(data)
	data.stamina = data.maxStamina
end

-- Returns true and spends stamina if the player can afford the action
function FighterStats.ConsumeStamina(data, actionType)
	local cost = FighterStats.StaminaCosts[actionType] or 0
	if data.stamina < cost or (cost > 0 and data.stamina <= 0) then
		return false
	end

	data.stamina = data.stamina - cost
	return true
end

-- Fight boost from the worn color skin (Catalog.SkyColors `bonus`), e.g. 0.3 = +30% strength and kick
function FighterStats.GetSkinBonus(data)
	local sky = data.skin and Catalog.SkyColorById[data.skin]
	return sky and sky.bonus or 0
end

function FighterStats.CalculateDamage(data, actionType)
	local skinMultiplier = 1 + FighterStats.GetSkinBonus(data)
	local base = data.strength * skinMultiplier * 0.9
	local kickBonus = data.kick * skinMultiplier * 0.7

	if actionType == "punch" then
		return math.floor(base * 0.75)
	elseif actionType == "kick" then
		return math.floor((base * 1.2) + kickBonus * 0.8)
	elseif actionType == "combo" then
		return math.floor((base * 1.6) + kickBonus * 0.9)
	elseif actionType == "knee" then
		return math.floor((base * 1.7) + kickBonus)
	else
		return 0
	end
end

function FighterStats.BuyLuck(data)
	if data.money < 100 then
		return false
	end

	data.money = data.money - 100
	data.luck = data.luck + 1
	return true
end

return FighterStats
