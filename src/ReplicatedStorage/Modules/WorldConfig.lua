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
	FreeStations = 10, -- ground floor, open to everyone
	VipStations = 5, -- second floor, auction winners only
	FreeTrainAmount = 50,
	VipTrainAmount = 100,
	TrainCooldown = 3, -- seconds between training reps per player
	List = {
		{ name = "Iron Den", color = Color3.fromRGB(200, 60, 60) },
		{ name = "Titan Gym", color = Color3.fromRGB(60, 120, 220) },
		{ name = "Knockout Club", color = Color3.fromRGB(240, 170, 40) },
		{ name = "Steel Fist", color = Color3.fromRGB(70, 180, 110) },
		{ name = "Jab Factory", color = Color3.fromRGB(160, 80, 200) },
		{ name = "Uppercut Hall", color = Color3.fromRGB(40, 180, 190) },
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
