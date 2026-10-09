local Shop = {}

local MAX_STRENGTH = 1000000000000
local MAX_LUCK = 99

function Shop.BuyDoubleStrength(playerData)
    if playerData.strength >= MAX_STRENGTH then
        return false, "Max strength reached."
    end

    local cost = 250

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.strength = math.min(MAX_STRENGTH, playerData.strength * 2)

    return true, "Strength doubled!"
end

function Shop.BuyDoubleKick(playerData)
    if playerData.kick >= MAX_STRENGTH then
        return false, "Max kick reached."
    end

    local cost = 250

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.kick = math.min(MAX_STRENGTH, playerData.kick * 2)

    return true, "Kick doubled!"
end

function Shop.BuyLuckUpgrade(playerData)
    if playerData.luck >= MAX_LUCK then
        return false, "Max luck reached."
    end

    local cost = 150 + (playerData.luck * 40)

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.luck = playerData.luck + 1

    return true, "Luck increased!"
end

function Shop.BuyHealthPack(playerData)
    local cost = 50

    if playerData.money < cost then
        return false, "Not enough Robux."
    end

    playerData.money = playerData.money - cost
    playerData.health = math.min(100, playerData.health + 30)

    return true, "Health restored!"
end

return Shop
