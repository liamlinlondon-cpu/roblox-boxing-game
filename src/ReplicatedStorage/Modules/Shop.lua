local Shop = {}

local MAX_STRENGTH = 1000000000000
local MAX_LUCK = 99
local HULK_THRESHOLD = 500000000000

function Shop.BuyDoubleStrength(playerData)
    if playerData.strength >= MAX_STRENGTH then
        return false, "Max strength reached."
    end

    playerData.strengthPurchases = playerData.strengthPurchases or 0
    local cost = 213 + (playerData.strengthPurchases * 50)

    if playerData.money < cost then
        return false, "Not enough Robux. Cost: " .. cost
    end

    playerData.money = playerData.money - cost
    playerData.strength = math.min(MAX_STRENGTH, playerData.strength * 2)
    playerData.strengthPurchases = playerData.strengthPurchases + 1

    return true, "Strength doubled! Next cost: " .. (213 + (playerData.strengthPurchases * 50))
end

function Shop.BuyTripleKick(playerData)
    if playerData.kick >= MAX_STRENGTH then
        return false, "Max kick reached."
    end

    playerData.kickPurchases = playerData.kickPurchases or 0
    local cost = 299 + (playerData.kickPurchases * 50)

    if playerData.money < cost then
        return false, "Not enough Robux. Cost: " .. cost
    end

    playerData.money = playerData.money - cost
    playerData.kick = math.min(MAX_STRENGTH, playerData.kick * 3)
    playerData.kickPurchases = playerData.kickPurchases + 1

    return true, "Kick tripled! Next cost: " .. (299 + (playerData.kickPurchases * 50))
end

function Shop.BuyLuckUpgrade(playerData)
    if playerData.luck >= MAX_LUCK then
        return false, "Max luck reached."
    end

    local cost = 100 + (playerData.luck * 45)

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.luck = playerData.luck + 1

    return true, "Luck increased!"
end

function Shop.BuySkinColor(playerData, colorName)
    if playerData.strength >= HULK_THRESHOLD then
        return false, "You are in Hulk form. Skin color is locked to green."
    end

    local skinColors = {
        red = 75,
        blue = 75,
        yellow = 75,
        purple = 75,
        orange = 75,
        pink = 75,
        white = 75,
        black = 75,
    }

    local cost = skinColors[colorName]
    if not cost then
        return false, "Color not found."
    end

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.skinColor = colorName

    return true, "Skin color changed to " .. colorName .. "!"
end

function Shop.CheckHulkReward(playerData)
    if playerData.strength >= HULK_THRESHOLD and not playerData.hulkRewardClaimed then
        playerData.money = playerData.money + 1000
        playerData.hulkRewardClaimed = true
        return true, "+1000 Robux for reaching Hulk form!"
    end

    return false, ""
end

return Shop
