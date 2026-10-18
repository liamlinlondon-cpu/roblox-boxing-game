local FighterStats = {}

FighterStats.BASE_STAMINA = 100

FighterStats.TreadmillTiers = {
	regular = { name = "Regular Treadmill", multiplier = 1, gain = 50 },
	hacker = { name = "Hacker's Treadmill", multiplier = 1000, gain = 50000 },
	admin = { name = "Admin Treadmill", multiplier = 10000000, gain = 50000000 },
	owner = { name = "Owner's Treadmill", multiplier = 100000000000, gain = 5000000000000 },
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
	}
end

-- Server-side player data shared between all services
function FighterStats.GetPlayerData(player)
	if not sharedPlayerData[player] then
		sharedPlayerData[player] = FighterStats.CreatePlayerData()
	end
	return sharedPlayerData[player]
end

function FighterStats.GetStageFromStrength(strength)
	if strength >= 250 then
		return "World Champion"
	elseif strength >= 180 then
		return "Elite Boxer"
	elseif strength >= 120 then
		return "Power Puncher"
	elseif strength >= 70 then
		return "Strong Athlete"
	elseif strength >= 40 then
		return "Rising Fighter"
	elseif strength >= 20 then
		return "Average Boxer"
	else
		return "Skinny Bones"
	end
end

function FighterStats.TrainStrength(data, amount)
	data.strength = data.strength + amount
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
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

function FighterStats.CalculateDamage(data, actionType)
	local base = data.strength * 0.9
	local kickBonus = data.kick * 0.7

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
