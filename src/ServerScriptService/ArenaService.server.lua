local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shop"))
local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local shopActionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ShopAction")
local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")
local arenaEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ArenaAction")

local function getPlayerData(player)
    return FighterStats.GetPlayerData(player)
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
        stamina = data.stamina,
        maxStamina = data.maxStamina,
        arenaWins = data.arenaWins,
        gameBeats = data.gameBeats,
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
    FighterStats.ResetStamina(data)

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
        stamina = data.stamina,
        maxStamina = data.maxStamina,
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

local WIN_REWARD = 10
local LOSS_PENALTY = 20

local function awardWin(player)
    local data = getPlayerData(player)
    data.money = data.money + WIN_REWARD * data.winMultiplier
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
            moneyAward = WIN_REWARD * data.winMultiplier,
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
        stamina = data.stamina,
        maxStamina = data.maxStamina,
    })

    data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
    sendPlayerStats(player)
end

local function handleBotAction(player, actionType)
    if actionType == "start_match" then
        startArenaCountdown(player)
        return
    end

    if actionType == "punch" or actionType == "kick" or actionType == "combo" or actionType == "knee" or actionType == "block" then
        local data = getPlayerData(player)
        if not FighterStats.ConsumeStamina(data, actionType) then
            matchResultEvent:FireClient(player, {
                type = "no_stamina",
                message = "Not enough stamina to " .. actionType .. "!",
                stamina = data.stamina,
                maxStamina = data.maxStamina,
            })
            return
        end

        if actionType == "block" then
            matchResultEvent:FireClient(player, {
                type = "block",
                message = "Blocked the incoming hit.",
                stamina = data.stamina,
                maxStamina = data.maxStamina,
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


-- ==================== PLAYER VS PLAYER ====================
-- Red/blue corner buttons (built by ArenaBuilder). When two different players hold the corners the
-- match starts after 3 seconds. A player loses when their health or stamina runs out.
local stateEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("StateUpdate")
local corners = { red = nil, blue = nil }
local countdownId = 0

local function teleportTo(player, cframe)
    if player.Character then
        player.Character:PivotTo(cframe)
    end
end

local function cornerSpawn(team)
    local arena = Workspace:FindFirstChild("BoxingArena")
    local spawnPart = arena and arena:FindFirstChild(team == "red" and "RedSpawn" or "BlueSpawn")
    return spawnPart and spawnPart.CFrame * CFrame.new(0, 3, 0)
end

local function releaseCorner(player)
    for team, occupant in pairs(corners) do
        if occupant == player then
            corners[team] = nil
        end
    end
end

local function sendToEntrance(player)
    local entrance = WorldConfig.ArenaEntrance
    teleportTo(player, CFrame.lookAt(entrance, WorldConfig.Arena.Center + Vector3.new(0, entrance.Y, 0)))
end

local function endPvpMatch(winner, loser)
    local winnerData = getPlayerData(winner)
    local loserData = getPlayerData(loser)
    winnerData.opponent = nil
    loserData.opponent = nil
    awardWin(winner)
    awardLoss(loser)
    loserData.money = math.max(0, loserData.money - LOSS_PENALTY)
    winnerData.isInMatch = false
    loserData.isInMatch = false
    releaseCorner(winner)
    releaseCorner(loser)

    matchResultEvent:FireClient(winner, {
        type = "win",
        moneyAward = WIN_REWARD * winnerData.winMultiplier,
        remainingHealth = winnerData.health,
    })
    matchResultEvent:FireClient(loser, {
        type = "lose",
        remainingHealth = loserData.health,
    })
    sendPlayerStats(winner)
    sendPlayerStats(loser)

    task.delay(3, function()
        sendToEntrance(winner)
        sendToEntrance(loser)
    end)
end

local function startPvpMatch(red, blue)
    local redData, blueData = getPlayerData(red), getPlayerData(blue)
    redData.isInMatch, blueData.isInMatch = true, true
    for _, p in ipairs({ red, blue }) do
        stateEvent:FireClient(p, { type = "location", location = "arena" })
    end

    countdownId += 1
    local id = countdownId
    for countdown = 3, 1, -1 do
        for _, p in ipairs({ red, blue }) do
            matchResultEvent:FireClient(p, { type = "countdown", number = countdown })
        end
        task.wait(1)
        if id ~= countdownId or corners.red ~= red or corners.blue ~= blue
            or not red.Parent or not blue.Parent then
            -- Someone left: cancel
            redData.isInMatch, blueData.isInMatch = false, false
            return
        end
    end

    redData.health, blueData.health = 100, 100
    FighterStats.ResetStamina(redData)
    FighterStats.ResetStamina(blueData)
    redData.opponent, blueData.opponent = blue, red
    for _, pair in ipairs({ { red, blue }, { blue, red } }) do
        local me, other = pair[1], pair[2]
        local myData = getPlayerData(me)
        matchResultEvent:FireClient(me, {
            type = "match_started",
            opponentName = other.DisplayName,
            opponentHealth = 100,
            stamina = myData.stamina,
            maxStamina = myData.maxStamina,
        })
    end
end

local function onArenaButton(player, team)
    local data = getPlayerData(player)
    if data.isInMatch or data.opponent then
        return
    end
    local other = team == "red" and "blue" or "red"
    if corners[team] and corners[team] ~= player and corners[team].Parent then
        return
    end
    if corners[other] == player then
        corners[other] = nil
    end
    local destination = cornerSpawn(team)
    if not destination then
        return
    end
    corners[team] = player
    teleportTo(player, destination)

    local opponent = corners[other]
    if opponent and opponent ~= player and opponent.Parent then
        local red, blue = corners.red, corners.blue
        task.spawn(startPvpMatch, red, blue)
    end
end

local function hookArenaButton(prompt)
    prompt.Triggered:Connect(function(player)
        onArenaButton(player, prompt:GetAttribute("Team"))
    end)
end
for _, prompt in ipairs(CollectionService:GetTagged("ArenaButton")) do
    hookArenaButton(prompt)
end
CollectionService:GetInstanceAddedSignal("ArenaButton"):Connect(hookArenaButton)

local function resolvePvpAttack(player, actionType)
    local data = getPlayerData(player)
    local opponent = data.opponent
    local opponentData = getPlayerData(opponent)

    if actionType == "block" then
        matchResultEvent:FireClient(player, {
            type = "block",
            message = "Blocked the incoming hit.",
            stamina = data.stamina,
            maxStamina = data.maxStamina,
        })
    else
        local damage = FighterStats.CalculateDamage(data, actionType)
        opponentData.health = clampHealth(opponentData.health - damage)
        if opponentData.health <= 0 then
            endPvpMatch(player, opponent)
            return
        end
        matchResultEvent:FireClient(player, {
            type = "fight_update",
            playerHealth = data.health,
            opponentHealth = opponentData.health,
            damageDealt = damage,
            damageTaken = 0,
            stamina = data.stamina,
            maxStamina = data.maxStamina,
        })
        matchResultEvent:FireClient(opponent, {
            type = "fight_update",
            playerHealth = opponentData.health,
            opponentHealth = data.health,
            damageDealt = 0,
            damageTaken = damage,
            stamina = opponentData.stamina,
            maxStamina = opponentData.maxStamina,
        })
    end

    if data.stamina <= 0 then
        endPvpMatch(opponent, player)
    end
end

Players.PlayerRemoving:Connect(function(player)
    local data = getPlayerData(player)
    if data.opponent and data.opponent.Parent then
        endPvpMatch(data.opponent, player)
    end
    releaseCorner(player)
end)

local function handleArenaAction(player, actionType)
    local data = getPlayerData(player)
    if data.opponent then
        if actionType == "punch" or actionType == "kick" or actionType == "combo" or actionType == "knee" or actionType == "block" then
            if not FighterStats.ConsumeStamina(data, actionType) then
                endPvpMatch(data.opponent, player) -- out of stamina
                return
            end
            resolvePvpAttack(player, actionType)
        end
        return
    end
    handleBotAction(player, actionType)
end

shopActionEvent.OnServerEvent:Connect(handleShopPurchase)
arenaEvent.OnServerEvent:Connect(handleArenaAction)

Players.PlayerAdded:Connect(function(player)
    local data = getPlayerData(player)
    data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
    sendPlayerStats(player)
end)
