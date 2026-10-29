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
        rebirths = data.rebirths,
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

-- ==================== BOT MATCHES ====================
-- Every fight is against a new random bot: its health, stamina and punching power are rolled when the
-- match starts (it doesn't copy the player). Its health is based on how hard the player hits, times a
-- random 5-10 hits, so a fight is never a one-hit win and never impossible. The bot answers each move
-- with a punch, kick, combo or knee (costing its stamina), sometimes blocks or dodges, and loses when its
-- health or stamina runs out. The player's BLOCK softens the bot's next hit; a player too tired to even
-- block loses.

local BOT_NAMES = { "Bot Boxer", "Steel Jab", "Iron Hook", "Rocky Bot", "Tank", "Lightning Fists", "The Wall", "Mad Uppercut" }
local BOT_MOVES = { -- damage multiplier and stamina cost
    { name = "punch", multiplier = 1, cost = 10 },
    { name = "kick", multiplier = 1.3, cost = 15 },
    { name = "combo", multiplier = 1.8, cost = 25 },
    { name = "knee", multiplier = 1.6, cost = 20 },
}
local BOT_BLOCK_CHANCE = 0.18 -- bot blocks: takes 30% damage
local BOT_DODGE_CHANCE = 0.08 -- bot dodges: takes no damage
local PLAYER_BLOCK_REDUCTION = 0.25 -- the player's block lets 25% of the bot's hit through

local botFights = {} -- [player] = { name, health, maxHealth, stamina, maxStamina, power }

local function clampHealth(value)
    return math.max(0, value)
end

local function newBot(player)
    local data = getPlayerData(player)
    local playerHit = FighterStats.CalculateDamage(data, "punch")
    local health
    if playerHit == math.huge then
        health = 1000 -- infinite strength wins with any hit
    else
        health = math.max(60, math.floor(math.max(playerHit, 10) * (5 + math.random() * 5)))
    end
    local stamina = math.random(100, 300)
    return {
        name = BOT_NAMES[math.random(#BOT_NAMES)],
        health = health,
        maxHealth = health,
        stamina = stamina,
        maxStamina = stamina,
        power = math.random(8, 18), -- damage of a plain punch on the player (who has 100 health)
    }
end

local function startArenaCountdown(player)
    local data = getPlayerData(player)
    data.isInMatch = true
    data.health = 100
    FighterStats.ResetStamina(data)
    local bot = newBot(player)
    botFights[player] = bot

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
        opponentName = string.format("%s (%d HP, %d stamina)", bot.name, bot.health, bot.stamina),
        opponentHealth = bot.health,
        opponentStamina = bot.stamina,
        stamina = data.stamina,
        maxStamina = data.maxStamina,
    })
end

local LOSS_PENALTY = 20
-- Money for a win is worked out from how well the player did:
local REWARD_MIN, REWARD_MAX = 50, 150 -- a random start
local STREAK_BONUS = 0.1 -- +10% for every win in a row...
local STREAK_MAX = 2 -- ...up to 2x
-- Then times the health left (full health 1.5x, almost none 0.5x), the bought win multiplier, and 2x for
-- every rebirth.

local winStreaks = {} -- [player] = wins in a row (a loss starts again)

-- Pays a win and says why: { money, streak, healthPercent }
local function awardWin(player)
    local data = getPlayerData(player)
    local streak = (winStreaks[player] or 0) + 1
    winStreaks[player] = streak
    local healthPercent = math.clamp((data.health or 0) / 100, 0, 1)
    local amount = math.random(REWARD_MIN, REWARD_MAX)
        * (0.5 + healthPercent)
        * math.min(STREAK_MAX, 1 + STREAK_BONUS * (streak - 1))
        * (data.winMultiplier or 1)
        * FighterStats.MoneyMultiplier(data)
    amount = math.floor(amount)
    data.money = data.money + amount
    data.arenaWins += 1
    return { money = amount, streak = streak, healthPercent = math.floor(healthPercent * 100 + 0.5) }
end

local function awardLoss(player)
    local data = getPlayerData(player)
    data.arenaLosses += 1
    winStreaks[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
    winStreaks[player] = nil
end)

local function endBotFight(player, won, message)
    local data = getPlayerData(player)
    botFights[player] = nil
    data.isInMatch = false
    if won then
        local reward = awardWin(player)
        matchResultEvent:FireClient(player, {
            type = "win",
            moneyAward = reward.money,
            streak = reward.streak,
            healthPercent = reward.healthPercent,
            remainingHealth = data.health,
        })
    else
        awardLoss(player)
        matchResultEvent:FireClient(player, {
            type = "lose",
            remainingHealth = data.health,
        })
    end
    if message then
        matchResultEvent:FireClient(player, { type = "block", message = message })
    end
    data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
    sendPlayerStats(player)
end

-- The bot's answer to the player's move: a random move it can still afford, or nil when it's exhausted
local function botAttack(bot)
    local affordable = {}
    for _, move in ipairs(BOT_MOVES) do
        if bot.stamina >= move.cost then
            table.insert(affordable, move)
        end
    end
    if #affordable == 0 then
        return nil
    end
    local move = affordable[math.random(#affordable)]
    bot.stamina -= move.cost
    return move, math.floor(bot.power * move.multiplier * (0.85 + math.random() * 0.3))
end

-- actionType: punch / kick / combo / knee, or block (no damage, softens the bot's hit)
local function resolveAttack(player, actionType)
    local data = getPlayerData(player)
    local bot = botFights[player]
    if not bot then
        return
    end

    local damage = 0
    local note = ""
    if actionType ~= "block" then
        -- Training while fighting, as before
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

        damage = FighterStats.CalculateDamage(data, actionType)
        local roll = math.random()
        if roll < BOT_DODGE_CHANCE then
            damage = 0
            note = bot.name .. " dodged! "
        elseif roll < BOT_DODGE_CHANCE + BOT_BLOCK_CHANCE then
            damage = math.floor(damage * 0.3)
            note = bot.name .. " blocked. "
        end
        bot.health = clampHealth(bot.health - damage)
        if bot.health <= 0 then
            endBotFight(player, true)
            return
        end
    end

    local move, hit = botAttack(bot)
    if not move then
        endBotFight(player, true, bot.name .. " ran out of stamina!")
        return
    end
    if actionType == "block" then
        hit = math.floor(hit * PLAYER_BLOCK_REDUCTION)
        note = "You blocked the " .. move.name .. ". "
    end
    data.health = clampHealth(data.health - hit)
    if data.health <= 0 then
        endBotFight(player, false)
        return
    end

    matchResultEvent:FireClient(player, {
        type = "fight_update",
        playerHealth = data.health,
        opponentHealth = bot.health,
        opponentStamina = bot.stamina,
        damageDealt = damage,
        damageTaken = hit,
        message = string.format("%sHit for %d. %s used %s: took %d.", note, damage, bot.name, move.name, hit),
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
        if not botFights[player] then
            return
        end
        if not FighterStats.ConsumeStamina(data, actionType) then
            -- Too tired to even block: the fight is lost
            if data.stamina < (FighterStats.StaminaCosts.block or 5) then
                endBotFight(player, false, "You ran out of stamina!")
                return
            end
            matchResultEvent:FireClient(player, {
                type = "no_stamina",
                message = "Not enough stamina to " .. actionType .. "!",
                stamina = data.stamina,
                maxStamina = data.maxStamina,
            })
            return
        end
        resolveAttack(player, actionType)
    end

    if actionType == "go_home" then
        botFights[player] = nil
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
    local reward = awardWin(winner)
    awardLoss(loser)
    loserData.money = math.max(0, loserData.money - LOSS_PENALTY)
    winnerData.isInMatch = false
    loserData.isInMatch = false
    releaseCorner(winner)
    releaseCorner(loser)

    matchResultEvent:FireClient(winner, {
        type = "win",
        moneyAward = reward.money,
        streak = reward.streak,
        healthPercent = reward.healthPercent,
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
    botFights[player] = nil
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
