-- Shared layout and VIP settings for the boxing world.
-- Used by WorldBuilder/ArenaBuilder (geometry), VipAuctionService (zones, teleports) and the VIP client UI.

local WorldConfig = {}

-- Also set this in Creator Dashboard > Places > Server Size; scripts cannot change it.
WorldConfig.MaxPlayers = 90

WorldConfig.GroundSize = 420
WorldConfig.SpawnRadius = 70

WorldConfig.Arena = {
	Center = Vector3.new(0, 0, 0),
	RingSize = 24, -- inside of the ropes, in studs
	RingHeight = 4, -- canvas height above the ground
	PostHeight = 9,
	DistrictRadius = 45, -- ring + bleachers + light towers
}

WorldConfig.Gyms = {
	Radius = 120, -- distance from the arena center to each gym center
	Width = 64,
	Depth = 48,
	FloorHeight = 16,
	DoorWidth = 14,
	DoorHeight = 11,
	FreeStations = 5, -- ground floor, open to everyone (one row of punch bags; the other row is treadmills)
	VipStations = 5, -- second floor, auction winners only
	List = {
		{ name = "Iron Den", color = Color3.fromRGB(200, 60, 60) },
		{ name = "Titan Gym", color = Color3.fromRGB(60, 120, 220) },
		{ name = "Knockout Club", color = Color3.fromRGB(240, 170, 40) },
		{ name = "Steel Fist", color = Color3.fromRGB(70, 180, 110) },
		{ name = "Jab Factory", color = Color3.fromRGB(160, 80, 200) },
		{ name = "VIP Shop", color = Color3.fromRGB(255, 200, 60), vipShop = true },
	},
}
WorldConfig.Gyms.Count = #WorldConfig.Gyms.List

-- Points inside a gym, in the gym's local space (-Z faces the arena).
local floor = WorldConfig.Gyms.FloorHeight
WorldConfig.Gyms.Points = {
	Elevator = Vector3.new(24, 0, 18), -- x/z of the elevator pad on both floors
	GroundArrival = Vector3.new(16, 4, 18),
	VipArrival = Vector3.new(16, floor + 5, 18),
	Entrance = Vector3.new(0, 4, -16),
}

-- Normal shop kiosk on the plaza edge and the arena's side entrance (used by the nav bar teleports)
WorldConfig.Shop = {
	Position = Vector3.new(27.5, 0, 47.6),
}
WorldConfig.ArenaEntrance = Vector3.new(0, 4, 24)

-- Beat the game: a parkour course outside the east wall (built by WorldBuilder), ending at a hill whose
-- red portal leads to the red button. The sign explaining it stands by the arena plaza.
WorldConfig.BeatGame = {
	SignPosition = Vector3.new(-14, 0, 48),
}

-- Sell Shop kiosk next to the ring (between the normal shop and the Color Shop): buys back owned items
WorldConfig.SellShop = {
	Position = Vector3.new(27.5, 0, -47.6),
}

-- Color Shop kiosk next to the ring, opposite the normal shop. It sells the current sky event's skin.
WorldConfig.ColorShop = {
	Position = Vector3.new(-27.5, 0, -47.6),
}

-- Sky color events: the sky turns a color (Catalog.SkyColors) for a few minutes
WorldConfig.SkyEvents = {
	FirstDelaySeconds = 60, -- first event this long after the server starts
	IntervalSeconds = 60 * 60, -- one hour between the end of one event and the start of the next
	DurationSeconds = 60, -- each event lasts one minute
	-- Natural events follow this order, then repeat from the start. Colors not listed here (yellow and
	-- orange are the rare ones) only appear when the owner starts them with a chat command.
	Schedule = {
		"blue", "magenta", "red", "purple", "magenta", "purple", "magenta",
		"red", "blue", "magenta", "purple", "red", "blue",
	},
	-- Chat commands that start an event right away, e.g. "/ruby" -> red sky (color ids from Catalog.SkyColors)
	Commands = {
		ruby = "red",
		amber = "orange",
		sy = "yellow",
		sapphire = "blue",
		crystal = "purple",
		mta = "magenta",
		rbr = "rainbow",
	},
	-- Chat command that ends the current event and turns the sky back to normal ("/non color")
	ClearCommand = "non",
	ClearCommandAlias = "noncolor",
}

-- The only account that can use the chat commands (sky events, /ban, /unban): Liantw1.
-- Everyone else, including test players in Studio, gets nothing when they type them.
WorldConfig.OwnerUserId = 11702564473
-- Add user IDs here to give other accounts the commands too (none right now). Admins can't be banned.
WorldConfig.AdminUserIds = {}

WorldConfig.WallHeight = 60
WorldConfig.WallThickness = 4

-- Bag training. Punching bags train strength and kicking bags train kick. Each hit adds `power` to that
-- stat; heavier hits are slower and unlock once that stat reaches `required`.
WorldConfig.Training = {
	PunchCounts = { 5, 10, 20, 50 },
	Weights = {
		{ lbs = 10, power = 1, interval = 0.45, required = 0 },
		{ lbs = 20, power = 2, interval = 0.55, required = 30 },
		{ lbs = 50, power = 5, interval = 0.7, required = 100 },
		{ lbs = 100, power = 10, interval = 0.9, required = 250 },
	},
	Modes = {
		punch = { stat = "strength", statName = "Strength", statLabel = "STR", gainLabel = "POWER", bagName = "Punching Bag", hit = "punch", hits = "punches" },
		kick = { stat = "kick", statName = "Kick", statLabel = "KICK", gainLabel = "KICK", bagName = "Kicking Bag", hit = "kick", hits = "kicks" },
	},
	VipMultiplier = 2, -- VIP floor bags give double gain per hit
	AutoRestSeconds = 1.5, -- pause between sets when auto-training
}

WorldConfig.Vip = {
	SlotsPerGym = 5,
	SessionSeconds = 30 * 60,
	PaymentWindowSeconds = 60, -- how long a winner has to complete the purchase before the next bidder is offered
	-- Bid tiers in Robux per 30-minute session. Create one Developer Product per tier
	-- (Creator Dashboard > your experience > Monetization > Developer Products) priced at
	-- exactly that amount, and paste its ID here. productId 0 = free test grant, Studio only.
	Tiers = {
		{ robux = 25, productId = 0 },
		{ robux = 50, productId = 0 },
		{ robux = 100, productId = 0 },
		{ robux = 250, productId = 0 },
		{ robux = 500, productId = 0 },
	},
}

function WorldConfig.GetGymCFrame(index)
	local angle = (index - 1) * (2 * math.pi / WorldConfig.Gyms.Count)
	local center = WorldConfig.Arena.Center
	local position = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * WorldConfig.Gyms.Radius
	return CFrame.lookAt(position, center)
end

function WorldConfig.GetGymPoint(index, localPosition)
	return WorldConfig.GetGymCFrame(index) * CFrame.new(localPosition)
end

return WorldConfig
