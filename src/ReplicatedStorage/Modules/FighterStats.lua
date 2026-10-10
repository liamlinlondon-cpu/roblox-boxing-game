local FighterStats = {}

function FighterStats.CreatePlayerData()
	return {
		strength = 10,
		kick = 10,
		luck = 1,
		money = 0,
		bodyStage = "Skinny Bones",
		health = 100,
		arenaWins = 0,
		arenaLosses = 0,
		isInMatch = false,
	}
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
