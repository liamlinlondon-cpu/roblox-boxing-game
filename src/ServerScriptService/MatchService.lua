local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local combatActionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CombatAction")
local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")

local playerDataMap = {}

local function getPlayerData(player)
	if not playerDataMap[player] then
		playerDataMap[player] = FighterStats.CreatePlayerData()
	end
	return playerDataMap[player]
end

local function clampHealth(value)
	return math.max(0, value)
end

local function getAIEnemy()
	return {
		name = "Bot Boxer",
		health = 100,
		strength = 40,
		kick = 45,
		luck = 1,
	}
end

local function sendPlayerStats(player)
	local data = getPlayerData(player)
	matchResultEvent:FireClient(player, {
		type = "stats",
		money = data.money,
		strength = data.strength,
		kick = data.kick,
		luck = data.luck,
		bodyStage = data.bodyStage,
		health = data.health,
	})
end

local function awardWin(player)
	local data = getPlayerData(player)
	data.money = data.money + 100
	data.arenaWins += 1
end

local function awardLoss(player)
	local data = getPlayerData(player)
	data.arenaLosses += 1
end

local function applyGymTraining(player)
	local data = getPlayerData(player)
	FighterStats.TrainStrength(data, 50)
	if data.strength > 50 then
		data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	end
	data.health = 100
	sendPlayerStats(player)
end

local function startMatch(player, againstAI)
	local data = getPlayerData(player)
	data.isInMatch = true
	data.health = 100

	local opponentName = againstAI and "Bot Boxer" or "Player Rival"
	matchResultEvent:FireClient(player, {
		type = "match_start",
		arenaType = againstAI and "ai" or "pvp",
		opponentName = opponentName,
	})
end

local function getAttackAnimation(actionType)
	if actionType == "kick" or actionType == "knee" then
		return "front_flip_knockout"
	elseif actionType == "punch" then
		return "jab"
	elseif actionType == "combo" then
		return "quick_combo"
	elseif actionType == "block" then
		return "guard"
	end
	return "standard_hit"
end

local function resolveAttack(player, actionType)
	local data = getPlayerData(player)
	local enemy = getAIEnemy()
	local animationType = getAttackAnimation(actionType)

	if actionType == "punch" then
		data.strength = math.min(1000000000000, data.strength + 1)
	elseif actionType == "kick" then
		data.kick = data.kick + 1
	elseif actionType == "combo" then
		data.strength = math.min(1000000000000, data.strength + 2)
		data.kick = data.kick + 2
	elseif actionType == "knee" then
		data.strength = math.min(1000000000000, data.strength + 3)
	end

	local damage = FighterStats.CalculateDamage(data, actionType)
	local currentEnemyHealth = enemy.health - damage
	local enemyDamage = 10 + (enemy.strength * 0.2)

	if currentEnemyHealth <= 0 then
		awardWin(player)
		data.isInMatch = false
		matchResultEvent:FireClient(player, {
			type = "win",
			moneyAward = 100,
			remainingHealth = data.health,
			animation = animationType,
			impact = "front_flip_land_back",
		})
		data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
		sendPlayerStats(player)
		return
	end

	data.health = clampHealth(data.health - enemyDamage)
	if data.health <= 0 then
		awardLoss(player)
		data.isInMatch = false
		matchResultEvent:FireClient(player, {
			type = "lose",
			remainingHealth = 0,
			animation = animationType,
			impact = "front_flip_land_back",
		})
		sendPlayerStats(player)
		return
	end

	matchResultEvent:FireClient(player, {
		type = "fight_update",
		playerHealth = data.health,
		opponentHealth = currentEnemyHealth,
		damageDealt = damage,
		damageTaken = enemyDamage,
		animation = animationType,
		impact = (actionType == "kick" or actionType == "knee") and "front_flip_land_back" or "standard_body_impact",
	})

	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	sendPlayerStats(player)
end

local function handleCombatAction(player, actionType)
	if actionType == "gym" then
		applyGymTraining(player)
		return
	end

	if actionType == "start_match" then
		startMatch(player, true)
		return
	end

	if actionType == "buy_luck" then
		local success = FighterStats.BuyLuck(getPlayerData(player))
		matchResultEvent:FireClient(player, {
			type = "luck_result",
			success = success,
		})
		sendPlayerStats(player)
		return
	end

	if actionType == "go_home" then
		getPlayerData(player).isInMatch = false
		matchResultEvent:FireClient(player, {
			type = "go_home",
		})
		return
	end

	if actionType == "block" then
		matchResultEvent:FireClient(player, {
			type = "block",
			message = "Blocked the incoming hit.",
			animation = "guard",
		})
		return
	end

	if actionType == "punch" or actionType == "kick" or actionType == "combo" or actionType == "knee" then
		resolveAttack(player, actionType)
	end
end

combatActionEvent.OnServerEvent:Connect(handleCombatAction)

Players.PlayerAdded:Connect(function(player)
	local data = getPlayerData(player)
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	sendPlayerStats(player)
end)
