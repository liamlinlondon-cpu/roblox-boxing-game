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
		money = 0,
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

function FighterStats.TrainStamina(data, tierKey)
	local tier = FighterStats.TreadmillTiers[tierKey]
	if not tier then
		return false
	end

	if not data.treadmills[tierKey] then
		return false
	end

	data.maxStamina = data.maxStamina + tier.gain
	data.stamina = data.maxStamina
	return true, tier
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
