local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shop"))
local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local shopActionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ShopAction")
local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")
local arenaEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ArenaAction")

local playerDataMap = {}

local function getPlayerData(player)
    if not playerDataMap[player] then
        playerDataMap[player] = FighterStats.CreatePlayerData()
    end
    return playerDataMap[player]
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

local function handleShopPurchase(player, action, colorName)
    local data = getPlayerData(player)
    local success = false
    local message = ""

    if action == "buy_strength" then
        success, message = Shop.BuyDoubleStrength(data)
    elseif action == "buy_kick" then
        success, message = Shop.BuyTripleKick(data)
    elseif action == "buy_luck" then
        success, message = Shop.BuyLuckUpgrade(data)
    elseif action == "buy_skin" then
        success, message = Shop.BuySkinColor(data, colorName)
    end

    -- Check for Hulk reward
    local hulkReward, hulkMessage = Shop.CheckHulkReward(data)
    if hulkReward then
        message = message .. " " .. hulkMessage
    end

    -- Update body stage based on strength
    if data.strength < 50 then
        data.bodyStage = "skinny_bones"
    elseif data.strength < 5000 then
        data.bodyStage = "regular_person"
    elseif data.strength < 500000 then
        data.bodyStage = "four_abs"
    else
        data.bodyStage = "green_hulk_like"
    end

    matchResultEvent:FireClient(player, {
        type = "shop_result",
        success = success,
        message = message,
    })

    sendPlayerStats(player)
end

local function startArenaCountdown(player)
    local data = getPlayerData(player)
    data.isInMatch = true
    data.health = 100

    -- Send countdown to client
    for countdown = 3, 1, -1 do
        matchResultEvent:FireClient(player, {
            type = "countdown",
            number = countdown,
        })
        wait(1)
    end

    -- Send match start signal
    matchResultEvent:FireClient(player, {
        type = "match_started",
        opponentName = "Bot Boxer",
        opponentHealth = 100,
    })
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

local function clampHealth(value)
    return math.max(0, value)
end

local function awardWin(player)
    local data = getPlayerData(player)
    data.money = data.money + 10
    data.arenaWins += 1
end

local function awardLoss(player)
    local data = getPlayerData(player)
    data.arenaLosses += 1
end

local function resolveAttack(player, actionType)
    local data = getPlayerData(player)
    local enemy = getAIEnemy()

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
            moneyAward = 10,
            remainingHealth = data.health,
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
    })

    data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
    sendPlayerStats(player)
end

local function handleArenaAction(player, actionType)
    if actionType == "start_match" then
        startArenaCountdown(player)
        return
    end

    if actionType == "punch" or actionType == "kick" or actionType == "combo" or actionType == "knee" or actionType == "block" then
        if actionType == "block" then
            matchResultEvent:FireClient(player, {
                type = "block",
                message = "Blocked the incoming hit.",
            })
            return
        end

        resolveAttack(player, actionType)
    end

    if actionType == "go_home" then
        getPlayerData(player).isInMatch = false
        matchResultEvent:FireClient(player, {
            type = "go_home",
        })
        return
    end
end

shopActionEvent.OnServerEvent:Connect(handleShopPurchase)
arenaEvent.OnServerEvent:Connect(handleArenaAction)

Players.PlayerAdded:Connect(function(player)
    local data = getPlayerData(player)
    data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
    sendPlayerStats(player)
end)
