-- Store catalog shared by the server (StoreService) and the client store UI.
-- Robux items need a Developer Product (Creator Dashboard > Monetization > Developer Products)
-- priced at exactly `robux`; paste its ID into `productId`. productId 0 = free test grant, Studio only.
-- Robux from Developer Products is paid out to the experience owner (set the owner to liamtw1 / the group
-- in Creator Dashboard); scripts cannot redirect payouts.

local Catalog = {}

Catalog.MaxLuck = 99 -- highest luck from the normal shop's luck upgrades
Catalog.VipMaxLuck = 200 -- the VIP shop's "2x Max Luck"
Catalog.WinsMultiplierStep = 10 -- each "10x Wins" purchase multiplies win rewards by this again
Catalog.LuckSteps = 6 -- luck doubles 1 > 2 > 4 > 8 > 16 > 32 > 64, then jumps to 99
Catalog.LuckBasePrice = 99 -- Robux; after the first two luck purchases the price rises by 50 each time
Catalog.LuckPriceStep = 50
Catalog.LuckFreePurchases = 2
-- One Developer Product per luck price level (7 purchases: 99, 99, 149, 199, 249, 299, 349 Robux)
Catalog.LuckProductIds = { 0, 0, 0, 0, 0, 0, 0 }

local function money(id, name, amount, robux)
	return { id = id, kind = "money", name = name, amount = amount, robux = robux, productId = 0 }
end

local function strength(id, name, amount, robux)
	return { id = id, kind = "strength", name = name, amount = amount, robux = robux, productId = 0 }
end

local function kick(id, name, amount, robux)
	return { id = id, kind = "kick", name = name, amount = amount, robux = robux, productId = 0 }
end

Catalog.Normal = {
	-- Rainbow flying carpet with rainbow fire on the corners (a tool: equip to sit on it and fly)
	{ id = "carpet", kind = "carpet", name = "Magic Carpet", robux = 1000, productId = 0 },
	-- Without this, riding the Magic Carpet outside the map (over the parkour) kills you.
	{ id = "carpetpass", kind = "carpetpass", name = "Carpet Parkour Pass", money = 10000, robux = 10000, productId = 0 },
	money("money_1k", "1,000 Money", 1e3, 272),
	money("money_100k", "100,000 Money", 1e5, 527),
	money("money_1m", "1,000,000 Money", 1e6, 752),
	money("money_10m", "10,000,000 Money", 1e7, 1056),
	money("money_1b", "1 Billion Money", 1e9, 7999),
	strength("str_100", "+100 Strength", 100, 49),
	strength("str_1k", "+1,000 Strength", 1e3, 199),
	strength("str_1m", "+1,000,000 Strength", 1e6, 1499),
	strength("str_1b", "+1 Billion Strength", 1e9, 9999),
	kick("kick_100", "+100 Kick", 100, 49),
	kick("kick_1k", "+1,000 Kick", 1e3, 199),
	kick("kick_1m", "+1,000,000 Kick", 1e6, 1499),
	kick("kick_1b", "+1 Billion Kick", 1e9, 9999),
	-- Can be bought again and again: 10x, 100x, 1,000x...
	{ id = "wins10", kind = "wins10", name = "10x Wins", robux = 2999, productId = 0 },
}

-- Only World Champions can use the VIP shop (see FighterStats.IsWorldChampion)
Catalog.Vip = {
	{ id = "maxluck", kind = "maxluck", name = "2x Max Luck (200)", robux = 4999, productId = 0 },
	strength("str_1t", "+1 Trillion Strength (Punch)", 1e12, 19999),
	kick("kick_1t", "+1 Trillion Kick", 1e12, 19999),
	money("money_1t", "1 Trillion Money", 1e12, 20000),
	money("money_1qa", "1 Quadrillion Money", 1e15, 100000),
	money("money_1sx", "1 Sextillion Money", 1e21, 1e6),
	money("money_1sp", "1 Septillion Money", 1e24, 1e7),
	money("money_1no", "1 Nonillion Money", 1e30, 1e8),
	money("money_inf", "Infinite Money", math.huge, 1e9),
}

-- Treadmill unlocks: everyone starts with the regular treadmill.
Catalog.Treadmills = {
	{ id = "tm_hacker", kind = "treadmill", tier = "hacker", name = "Hacker's Treadmill", money = 5000, robux = 5000, productId = 0 },
	{ id = "tm_admin", kind = "treadmill", tier = "admin", name = "Admin Treadmill", money = 50000, robux = 50000, productId = 0 },
	{ id = "tm_owner", kind = "treadmill", tier = "owner", name = "Owner's Treadmill (use in private servers)", money = 5e12, robux = 500000, productId = 0 },
}

-- Sky event colors. During a sky event the sky turns that color and the Color Shop (next to the ring)
-- sells the matching skin. Skins are kept once bought and can be worn again any time.
-- `bonus`: while worn, the skin boosts strength and kick in fights (0.3 = +30%). Best first.
-- `money` / `robux`: the skin's price in the Color Shop.
-- `strengthPerSecond`: strength gained every second while the skin is worn.
-- `rainbow`: the sky cycles through all colors and the skin colors each body part differently.
Catalog.SkyColors = {
	{
		id = "rainbow",
		name = "Rainbow",
		color = Color3.fromRGB(255, 80, 200),
		rainbow = true,
		bonus = 0.3,
		strengthPerSecond = 50,
		money = 200000,
		robux = 200,
	},
	{ id = "yellow", name = "Yellow", color = Color3.fromRGB(255, 220, 40), bonus = 0.3, money = 100000, robux = 100 },
	{ id = "orange", name = "Orange", color = Color3.fromRGB(255, 140, 30), bonus = 0.25, money = 50000, robux = 75 },
	{ id = "blue", name = "Blue", color = Color3.fromRGB(40, 90, 255), bonus = 0.2, money = 20000, robux = 60 },
	{ id = "red", name = "Red", color = Color3.fromRGB(255, 40, 40), bonus = 0.15, money = 10000, robux = 50 },
	{ id = "purple", name = "Purple", color = Color3.fromRGB(150, 60, 220), bonus = 0.1, money = 1000, robux = 40 },
	{ id = "magenta", name = "Magenta", color = Color3.fromRGB(255, 0, 255), bonus = 0.05, money = 500, robux = 25 },
	{ id = "green", name = "Green", color = Color3.fromRGB(40, 200, 70), bonus = 0.03, money = 100, robux = 10 },
	{ id = "pink", name = "Pink", color = Color3.fromRGB(255, 100, 200), bonus = 0.03, money = 100, robux = 10 },
	{ id = "cyan", name = "Cyan", color = Color3.fromRGB(40, 220, 230), bonus = 0.03, money = 100, robux = 10 },
}
-- Rainbow skin body colors: head, torso, left arm, right arm, left leg, right leg
Catalog.RainbowColors = {
	Color3.fromRGB(255, 40, 40),
	Color3.fromRGB(255, 140, 30),
	Color3.fromRGB(255, 220, 40),
	Color3.fromRGB(40, 200, 70),
	Color3.fromRGB(40, 90, 255),
	Color3.fromRGB(150, 60, 220),
}

Catalog.SkyColorById = {}
Catalog.ColorSkins = {}
for _, sky in ipairs(Catalog.SkyColors) do
	Catalog.SkyColorById[sky.id] = sky
	table.insert(Catalog.ColorSkins, {
		id = "skin_" .. sky.id,
		kind = "skin",
		colorId = sky.id,
		name = sky.name .. " Skin",
		money = sky.money,
		robux = sky.robux,
		productId = 0,
	})
end

Catalog.ById = {}
for store, list in pairs({ normal = Catalog.Normal, vip = Catalog.Vip, treadmill = Catalog.Treadmills, color = Catalog.ColorSkins }) do
	for _, item in ipairs(list) do
		item.store = store
		Catalog.ById[item.id] = item
	end
end

-- Selling back: lasting items (Magic Carpet, Carpet Parkour Pass, treadmills, skins) can be sold for the
-- same number as their price, always paid in money (Robux can't be given back): the money price, or
-- the Robux price as money when there's no money price. Used-up items (money, strength, luck...) can't.
local SELLABLE_KINDS = { carpet = true, carpetpass = true, treadmill = true, skin = true }

-- Any other tool in a player's backpack (from the StarterPack, admin kits...) sells for this much money.
-- Once sold it's gone for good: copies that come back later (e.g. after respawning) are removed.
Catalog.BackpackToolSellPrice = 100

function Catalog.CanSell(item)
	return item ~= nil and SELLABLE_KINDS[item.kind] == true
end

function Catalog.SellPrice(item)
	return item.money or item.robux or 0
end

-- What a skin does while worn, e.g. "+30% STR & KICK, +50 STR/sec"
function Catalog.SkinPerkText(sky)
	local text = string.format("+%d%% STR & KICK", math.floor(sky.bonus * 100 + 0.5))
	if sky.strengthPerSecond then
		text ..= string.format(", +%d STR/sec", sky.strengthPerSecond)
	end
	return text
end

-- Luck jumps: doubles until 64, then becomes 99
function Catalog.NextLuck(luck)
	if luck >= Catalog.MaxLuck then
		return nil
	end
	if luck >= 64 then
		return Catalog.MaxLuck
	end
	return luck * 2
end

function Catalog.LuckPrice(purchases)
	return Catalog.LuckBasePrice + Catalog.LuckPriceStep * math.max(0, purchases - Catalog.LuckFreePurchases + 1)
end

-- 123456789 -> "123,456,789" (very big numbers fall back to FormatNumber's short form)
function Catalog.FormatWithCommas(value)
	if value == math.huge or value >= 1e15 then
		return Catalog.FormatNumber(value)
	end
	local digits = string.format("%.0f", value)
	local formatted = digits
	repeat
		local count
		formatted, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end

function Catalog.FormatNumber(value)
	if value == math.huge then
		return "Infinite"
	end
	if value >= 1e15 then
		return string.format("%.3e", value)
	end
	return string.format("%.0f", value)
end

return Catalog
