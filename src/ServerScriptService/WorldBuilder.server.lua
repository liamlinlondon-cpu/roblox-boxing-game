-- Builds everything around the arena: ground, plaza, paths, player spawns and the ring of gyms.
-- Each gym has a free ground floor and a VIP second floor reached only by the VIP elevator pad
-- (VipAuctionService decides who may use it). Station training is handled in FlowService.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))
local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local WORLD_NAME = "BoxingWorld"
local ARENA = WorldConfig.Arena
local GYM = WorldConfig.Gyms

local GOLD = Color3.fromRGB(255, 200, 60)

local function makePart(parent, name, size, cframe, material, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addSign(part, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

local function addPrompt(part, actionText, objectText, tag, attributes)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	for key, value in pairs(attributes) do
		prompt:SetAttribute(key, value)
	end
	prompt.Parent = part
	CollectionService:AddTag(prompt, tag)
	return prompt
end

-- mode "punch" = hanging punching bag (trains strength), "kick" = floor-standing kicking bag (trains kick)
local function buildStation(model, gymCFrame, gymIndex, name, x, floorTop, z, isVip, mode)
	mode = mode or "punch"
	local padColor = isVip and GOLD or Color3.fromRGB(70, 70, 80)
	local pad = makePart(model, name, Vector3.new(6, 0.4, 6), gymCFrame * CFrame.new(x, floorTop + 0.2, z), Enum.Material.Fabric, padColor)
	pad:SetAttribute("Vip", isVip)

	local bagZ = z + 3.5
	local modeInfo = WorldConfig.Training.Modes[mode]
	local objectText = isVip and ("VIP " .. modeInfo.bagName .. " (" .. WorldConfig.Training.VipMultiplier .. "x)") or modeInfo.bagName
	local promptAttributes = { GymId = gymIndex, Vip = isVip, Mode = mode }

	if mode == "kick" then
		-- Free-standing kicking bag on a weighted base, at leg height
		local bagColor = isVip and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(30, 70, 170)
		makePart(
			model,
			name .. "Base",
			Vector3.new(0.8, 3.4, 3.4),
			gymCFrame * CFrame.new(x, floorTop + 0.4, bagZ) * CFrame.Angles(0, 0, math.pi / 2),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(35, 35, 40),
			Enum.PartType.Cylinder
		)
		makePart(
			model,
			name .. "Bag",
			Vector3.new(5.5, 2.4, 2.4),
			gymCFrame * CFrame.new(x, floorTop + 3.55, bagZ) * CFrame.Angles(0, 0, math.pi / 2),
			Enum.Material.Leather,
			bagColor,
			Enum.PartType.Cylinder
		)
		addPrompt(pad, "Train", objectText, "GymStation", promptAttributes)
		return
	end

	-- Vertical punching bag hanging from the ceiling at the back edge of the pad
	local bagColor = isVip and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(170, 30, 30)
	makePart(
		model,
		name .. "Bag",
		Vector3.new(5, 2.4, 2.4),
		gymCFrame * CFrame.new(x, floorTop + 4.5, bagZ) * CFrame.Angles(0, 0, math.pi / 2),
		Enum.Material.Leather,
		bagColor,
		Enum.PartType.Cylinder
	)
	local chainLength = GYM.FloorHeight - 1 - 7
	local chain = makePart(
		model,
		name .. "Chain",
		Vector3.new(0.2, chainLength, 0.2),
		gymCFrame * CFrame.new(x, floorTop + 7 + chainLength / 2, bagZ),
		Enum.Material.Metal,
		Color3.fromRGB(150, 150, 150)
	)
	chain.CanCollide = false

	addPrompt(pad, "Train", objectText, "GymStation", promptAttributes)
end

local TREADMILL_COLORS = {
	regular = Color3.fromRGB(90, 90, 90),
	hacker = Color3.fromRGB(0, 200, 80),
	admin = Color3.fromRGB(60, 120, 255),
	owner = Color3.fromRGB(255, 200, 0),
}

local DARK = Color3.fromRGB(28, 28, 32)

-- Full-size gym treadmill: frame, moving belt, side rails, motor housing, handrails and a tilted console.
-- The runner faces +Z (gym local) toward the console. FlowService handles running and training.
local function buildTreadmill(model, gymCFrame, gymIndex, tierKey, x, z)
	local tier = FighterStats.TreadmillTiers[tierKey]
	local color = TREADMILL_COLORS[tierKey]
	local base = gymCFrame * CFrame.new(x, 0, z)
	local function at(dx, y, dz, rotation)
		return base * CFrame.new(dx, y, dz) * (rotation or CFrame.new())
	end

	local deck = makePart(model, tierKey .. "Treadmill", Vector3.new(5, 0.8, 10), at(0, 1.4, 0), Enum.Material.Metal, Color3.fromRGB(55, 55, 60))
	makePart(model, tierKey .. "Belt", Vector3.new(3.6, 0.2, 9), at(0, 1.9, 0), Enum.Material.Slate, DARK).CanCollide = false
	for i = -4, 4 do
		local stripe = makePart(model, tierKey .. "BeltStripe", Vector3.new(3.6, 0.05, 0.25), at(0, 2.03, i), Enum.Material.SmoothPlastic, Color3.fromRGB(60, 60, 66))
		stripe.CanCollide = false
	end
	for _, side in ipairs({ -1, 1 }) do
		makePart(model, tierKey .. "Rail", Vector3.new(0.7, 0.7, 10), at(side * 2.15, 2.1, 0), Enum.Material.SmoothPlastic, color)
		makePart(model, tierKey .. "Upright", Vector3.new(0.4, 5.2, 0.4), at(side * 2, 4.4, 4.4), Enum.Material.Metal, Color3.fromRGB(190, 190, 195))
		makePart(model, tierKey .. "Handrail", Vector3.new(0.35, 0.35, 4), at(side * 2, 6.9, 2.6), Enum.Material.Metal, Color3.fromRGB(190, 190, 195)).CanCollide = false
		makePart(model, tierKey .. "Grip", Vector3.new(0.5, 0.5, 2), at(side * 2, 6.9, 2.6), Enum.Material.Rubber, DARK).CanCollide = false
	end
	makePart(model, tierKey .. "Motor", Vector3.new(5, 1.6, 1.4), at(0, 2.3, 4.6), Enum.Material.SmoothPlastic, color)
	makePart(model, tierKey .. "ConsoleBody", Vector3.new(4.2, 2, 0.8), at(0, 6.9, 4.4, CFrame.Angles(-0.4, 0, 0)), Enum.Material.SmoothPlastic, DARK)
	local screen = makePart(model, tierKey .. "ConsoleScreen", Vector3.new(3.4, 1.4, 0.2), at(0, 6.95, 4.05, CFrame.Angles(-0.4, math.pi, 0)), Enum.Material.Neon, Color3.fromRGB(20, 40, 30))
	screen.CanCollide = false
	addSign(screen, Enum.NormalId.Front, tier.name, color)

	addPrompt(deck, "Run (+" .. string.format("%.0f", tier.gain) .. " stamina/sec)", tier.privateServerOnly and (tier.name .. " (owner, or private servers)") or tier.name, "TreadmillStation", {
		GymId = gymIndex,
		Tier = tierKey,
	})
end

-- Shop counter with a prompt that opens the store UI ("normal" or "vip")
local function buildKiosk(parent, cframe, title, color, storeKind)
	local counter = makePart(parent, title .. "Counter", Vector3.new(14, 4, 4), cframe * CFrame.new(0, 2, 0), Enum.Material.Wood, Color3.fromRGB(90, 60, 40))
	local sign = makePart(parent, title .. "Sign", Vector3.new(14, 4, 0.5), cframe * CFrame.new(0, 8, 1.5), Enum.Material.SmoothPlastic, color)
	addSign(sign, Enum.NormalId.Back, title, Color3.fromRGB(255, 255, 255))
	makePart(parent, title .. "PostL", Vector3.new(0.6, 8, 0.6), cframe * CFrame.new(-6.5, 4, 1.5), Enum.Material.Metal, Color3.fromRGB(90, 90, 90))
	makePart(parent, title .. "PostR", Vector3.new(0.6, 8, 0.6), cframe * CFrame.new(6.5, 4, 1.5), Enum.Material.Metal, Color3.fromRGB(90, 90, 90))
	local prompt = addPrompt(counter, "Open shop", title, "StoreKiosk", { Store = storeKind })
	prompt.MaxActivationDistance = 14
	return counter
end

local function buildGym(world, index)
	local info = GYM.List[index]
	local gymCFrame = WorldConfig.GetGymCFrame(index)
	local W, D, F = GYM.Width, GYM.Depth, GYM.FloorHeight
	local doorW, doorH = GYM.DoorWidth, GYM.DoorHeight

	local model = Instance.new("Model")
	model.Name = info.name
	model:SetAttribute("GymId", index)
	model.Parent = world

	local function at(x, y, z)
		return gymCFrame * CFrame.new(x, y, z)
	end

	local wallColor = Color3.fromRGB(205, 205, 210)

	-- Shell: ground slab, VIP floor slab, roof
	makePart(model, "GroundFloor", Vector3.new(W, 1, D), at(0, 0.5, 0), Enum.Material.WoodPlanks, Color3.fromRGB(160, 120, 80))
	makePart(model, "VipFloor", Vector3.new(W, 1, D), at(0, F + 0.5, 0), Enum.Material.Marble, Color3.fromRGB(235, 230, 220))
	makePart(model, "Roof", Vector3.new(W + 2, 1, D + 2), at(0, 2 * F + 0.5, 0), Enum.Material.Metal, info.color)

	-- Back and side walls run the full height
	makePart(model, "BackWall", Vector3.new(W, 2 * F, 1), at(0, F, D / 2 - 0.5), Enum.Material.Concrete, wallColor)
	makePart(model, "LeftWall", Vector3.new(1, 2 * F, D), at(-(W / 2 - 0.5), F, 0), Enum.Material.Concrete, wallColor)
	makePart(model, "RightWall", Vector3.new(1, 2 * F, D), at(W / 2 - 0.5, F, 0), Enum.Material.Concrete, wallColor)

	-- Front wall (faces the arena): doorway on the ground floor, glass on the VIP floor
	local sideWidth = (W - doorW) / 2
	local sideX = doorW / 2 + sideWidth / 2
	local frontZ = -D / 2 + 0.5
	makePart(model, "FrontLeft", Vector3.new(sideWidth, F, 1), at(-sideX, F / 2, frontZ), Enum.Material.Concrete, wallColor)
	makePart(model, "FrontRight", Vector3.new(sideWidth, F, 1), at(sideX, F / 2, frontZ), Enum.Material.Concrete, wallColor)
	makePart(model, "DoorHeader", Vector3.new(doorW, F - doorH, 1), at(0, doorH + (F - doorH) / 2, frontZ), Enum.Material.Concrete, wallColor)
	local glass = makePart(model, "VipGlass", Vector3.new(W, F, 1), at(0, F + F / 2, frontZ), Enum.Material.Glass, Color3.fromRGB(170, 210, 255))
	glass.Transparency = 0.5

	-- Signs on the outside of the front wall
	local nameSign = makePart(model, "NameSign", Vector3.new(doorW + 10, F - doorH - 1, 0.4), at(0, (doorH + F) / 2, -D / 2 - 0.25), Enum.Material.SmoothPlastic, info.color)
	addSign(nameSign, Enum.NormalId.Front, info.name, Color3.fromRGB(255, 255, 255))
	local vipSign = not info.vipShop and makePart(model, "VipSign", Vector3.new(30, 4, 0.4), at(0, 2 * F - 3, -D / 2 - 0.25), Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25))
	if vipSign then
		addSign(vipSign, Enum.NormalId.Front, "VIP FLOOR", GOLD)
	end

	-- Ceiling lights on both floors
	for _, ceilingY in ipairs({ F - 0.15, 2 * F - 0.15 }) do
		for _, x in ipairs({ -20, 0, 20 }) do
			local panel = makePart(model, "CeilingLight", Vector3.new(8, 0.3, 2), at(x, ceilingY, 2), Enum.Material.Neon, Color3.fromRGB(255, 250, 235))
			panel.CanCollide = false
			local light = Instance.new("PointLight")
			light.Range = 28
			light.Brightness = 1.5
			light.Parent = panel
		end
	end

	if info.vipShop then
		buildKiosk(model, at(0, 1, 6) * CFrame.Angles(0, math.pi, 0), "VIP SHOP", GOLD, "vip")
		return model
	end

	-- Ground floor: one row of free punching-bag stations (the other row is treadmills)
	local xs = { -24, -12, 0, 12, 24 }
	for i, x in ipairs(xs) do
		if i <= GYM.FreeStations then
			buildStation(model, gymCFrame, index, "Station" .. i, x, 1, -6, false)
		end
	end

	-- Ground floor: one large treadmill per tier in the freed row
	for i, tierKey in ipairs({ "regular", "hacker", "admin", "owner" }) do
		buildTreadmill(model, gymCFrame, index, tierKey, -18 + (i - 1) * 12, 8)
	end

	-- Ground floor: kicking bags in the open area by the entrance, either side of the doorway
	for i, x in ipairs({ -24, -14, 14, 24 }) do
		buildStation(model, gymCFrame, index, "KickStation" .. i, x, 1, -17, false, "kick")
	end

	-- VIP floor: gold carpet, one row of VIP punching bags and two VIP kicking bags
	local carpet = makePart(model, "VipCarpet", Vector3.new(W - 4, 0.1, D - 4), at(0, F + 1.05, 0), Enum.Material.Fabric, Color3.fromRGB(120, 20, 30))
	carpet.CanCollide = false
	for i = 1, math.min(GYM.VipStations, #xs) do
		buildStation(model, gymCFrame, index, "VipStation" .. i, xs[i], F + 1, -2, true)
	end
	for i, x in ipairs({ -14, 14 }) do
		buildStation(model, gymCFrame, index, "VipKickStation" .. i, x, F + 1, -17, true, "kick")
	end

	-- Bidding board on the ground floor's back wall
	local board = makePart(model, "VipBoard", Vector3.new(12, 7, 0.4), at(6, 6, D / 2 - 1.2), Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25))
	addSign(board, Enum.NormalId.Front, "VIP BIDDING\nHold E to bid", GOLD)
	local boardPrompt = addPrompt(board, "Open VIP bidding", info.name, "VipBoard", { GymId = index })
	boardPrompt.MaxActivationDistance = 12

	-- VIP elevator (ground floor) and exit pad (VIP floor). There are no stairs; access is checked on the server.
	local elevator = GYM.Points.Elevator
	local elevatorPad = makePart(model, "VipElevator", Vector3.new(6, 0.4, 6), at(elevator.X, 1.2, elevator.Z), Enum.Material.Neon, GOLD)
	addPrompt(elevatorPad, "Go to VIP floor", "VIP Elevator", "VipElevator", { GymId = index })
	local exitPad = makePart(model, "VipExit", Vector3.new(6, 0.4, 6), at(elevator.X, F + 1.2, elevator.Z), Enum.Material.Neon, Color3.fromRGB(120, 170, 255))
	addPrompt(exitPad, "Leave VIP floor", "Elevator", "VipExit", { GymId = index })

	return model
end

-- ==================== BEAT THE GAME ====================
-- Parkour course outside the east wall: a hollow diamond of buildings about the size of the whole map,
-- 11 columns long (going away from the map). The back and front tips are one building each; every column
-- in between has two, one on each side, spreading apart toward the middle and closing in again, with
-- nothing in the middle. Players go around either side of the diamond from the back tip to the front
-- tip, then jump to a three-tier hill. There are no stairs: getting over the 60-stud wall is part of
-- the challenge. Each building overlaps the next one sideways, so every jump is straight across a gap,
-- and the gaps get longer the further they go. A normal Roblox jump only covers about 8 studs on flat ground,
-- so columns get lower when the jumps get longer than that:
--   wall top 60 -> column 1 (gap 4); columns 1-8 roofs 56 (gaps 4, 5, 5, 6, 6, 7, 7);
--   column 9 roof 53 (gap 8), column 10 roof 50 (gap 8), column 11 roof 44 (gap 9);
--   column 11 -> hill top 32 (gap 10, the big one)
-- The ground outside is lava. The hill: yellow pad on the bottom tier, blue on the middle and a red round
-- portal on top, which teleports you inside the front tip building (the last one you jumped on), where
-- the red button wins the game. The tiers are 10 studs apart so they can't be climbed: missing the last jump leaves you on a
-- decoy tier. BeatGameService handles the lava, pads, portal and button.

local LAVA_COLOR = Color3.fromRGB(255, 90, 20)
local BUILDING_COLOR = Color3.fromRGB(120, 120, 130)
local RED = Color3.fromRGB(255, 40, 40)

local BUILDING_SIZE = 36
-- Sideways step between neighbouring columns' buildings; BUILDING_SIZE - DIAMOND_STEP (12 studs) is how
-- much each building overlaps the next one, i.e. the strip you jump across
local DIAMOND_STEP = 24
local FIRST_COLUMN_X = 218 -- 4 studs past the wall's outside face
-- Each column: the gap before it (from the previous column) and its roof height
local COURSE_COLUMNS = {
	{ gap = 0, roof = 56 },
	{ gap = 4, roof = 56 },
	{ gap = 5, roof = 56 },
	{ gap = 5, roof = 56 },
	{ gap = 6, roof = 56 },
	{ gap = 6, roof = 56 },
	{ gap = 7, roof = 56 },
	{ gap = 7, roof = 56 },
	{ gap = 8, roof = 53 },
	{ gap = 8, roof = 50 },
	{ gap = 9, roof = 44 },
}
local FINAL_JUMP = 10

-- Builds the list of building footprints (x from/to, z from/to, relative to the arena center)
local COURSE_BUILDINGS = {}
local courseEndX = FIRST_COLUMN_X
do
	local x = FIRST_COLUMN_X
	for column, info in ipairs(COURSE_COLUMNS) do
		if column > 1 then
			x += info.gap
		end
		-- Steps out from the diamond's center line: 0 at the tips, most in the middle column
		local steps = math.min(column - 1, #COURSE_COLUMNS - column)
		local sides = steps == 0 and { 0 } or { -steps, steps }
		for _, side in ipairs(sides) do
			local zCenter = side * DIAMOND_STEP
			table.insert(COURSE_BUILDINGS, {
				name = "Building" .. column .. (side < 0 and "Left" or side > 0 and "Right" or "Tip"),
				x = { x, x + BUILDING_SIZE },
				z = { zCenter - BUILDING_SIZE / 2, zCenter + BUILDING_SIZE / 2 },
				roof = info.roof,
				-- The front tip holds the red button room
				hollow = column == #COURSE_COLUMNS,
			})
		end
		x += BUILDING_SIZE
	end
	courseEndX = x
end

-- The hill's top tier starts FINAL_JUMP studs past the last column; its bottom tier ends just past it
local HILL_TIERS = { -- bottom to top
	{ radius = 23, top = 12, pad = { color = "yellow", rgb = Color3.fromRGB(255, 220, 40), offset = 21.5 } },
	{ radius = 20, top = 22, pad = { color = "blue", rgb = Color3.fromRGB(40, 90, 255), offset = 17 } },
	{ radius = 14, top = 32 },
}
local HILL_CENTER = Vector3.new(courseEndX + FINAL_JUMP + HILL_TIERS[#HILL_TIERS].radius, 0, 0)

local function buildCourseBuilding(model, info)
	local x1, x2, z1, z2 = info.x[1], info.x[2], info.z[1], info.z[2]
	local width, depth = x2 - x1, z2 - z1
	local center = ARENA.Center + Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	if not info.hollow then
		makePart(model, info.name, Vector3.new(width, info.roof, depth), CFrame.new(center + Vector3.new(0, info.roof / 2, 0)), Enum.Material.Concrete, BUILDING_COLOR)
		return
	end

	-- The front building is hollow: a closed room at the bottom holds the red button
	local roomTop = 12
	local function slab(name, y)
		makePart(model, name, Vector3.new(width, 1, depth), CFrame.new(center + Vector3.new(0, y, 0)), Enum.Material.Concrete, BUILDING_COLOR)
	end
	slab(info.name .. "Floor", 1) -- floor top at 1.5, above the lava
	slab(info.name .. "RoomCeiling", roomTop)
	slab(info.name .. "Roof", info.roof - 0.5)
	for _, wall in ipairs({
		{ Vector3.new(width, info.roof, 1), Vector3.new(0, info.roof / 2, -depth / 2 + 0.5) },
		{ Vector3.new(width, info.roof, 1), Vector3.new(0, info.roof / 2, depth / 2 - 0.5) },
		{ Vector3.new(1, info.roof, depth), Vector3.new(-width / 2 + 0.5, info.roof / 2, 0) },
		{ Vector3.new(1, info.roof, depth), Vector3.new(width / 2 - 0.5, info.roof / 2, 0) },
	}) do
		makePart(model, info.name .. "Wall", wall[1], CFrame.new(center + wall[2]), Enum.Material.Concrete, BUILDING_COLOR)
	end

	-- The red button on a pedestal in the middle of the room
	makePart(model, "ButtonPedestal", Vector3.new(2, 3, 2), CFrame.new(center + Vector3.new(0, 3, 0)), Enum.Material.Metal, Color3.fromRGB(60, 60, 65))
	local button = makePart(
		model,
		"RedButton",
		Vector3.new(0.5, 1.6, 1.6),
		CFrame.new(center + Vector3.new(0, 4.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Enum.Material.Neon,
		RED,
		Enum.PartType.Cylinder
	)
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 14
	light.Parent = button
	local prompt = addPrompt(button, "Press", "Red Button", "BeatGameButton", {})
	prompt.MaxActivationDistance = 8

	-- Where the red portal drops players: inside the room, facing the button
	local arrival = makePart(model, "BeatGameArrival", Vector3.new(1, 1, 1), CFrame.lookAt(center + Vector3.new(-4, 4.5, 0), center + Vector3.new(0, 4.5, 0)))
	arrival.Transparency = 1
	arrival.CanCollide = false
	arrival.CanQuery = false
	CollectionService:AddTag(arrival, "BeatGameArrival")
end

local function buildHill(model)
	local center = ARENA.Center + HILL_CENTER
	for i, tier in ipairs(HILL_TIERS) do
		makePart(
			model,
			"HillTier" .. i,
			Vector3.new(tier.top, tier.radius * 2, tier.radius * 2),
			CFrame.new(center + Vector3.new(0, tier.top / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Enum.Material.Grass,
			Color3.fromRGB(76, 140, 60),
			Enum.PartType.Cylinder
		)
		if tier.pad then
			-- Decoy pads on the ring of each lower tier
			local pad = makePart(
				model,
				tier.pad.color .. "Pad",
				Vector3.new(0.4, 3, 3),
				CFrame.new(center + Vector3.new(0, tier.top + 0.2, tier.pad.offset)) * CFrame.Angles(0, 0, math.pi / 2),
				Enum.Material.Neon,
				tier.pad.rgb,
				Enum.PartType.Cylinder
			)
			pad:SetAttribute("PadColor", tier.pad.color)
			CollectionService:AddTag(pad, "BeatGamePad")
		end
	end

	-- The red round portal standing on top of the hill, facing the buildings
	local top = HILL_TIERS[#HILL_TIERS].top
	local portal = makePart(
		model,
		"RedPortal",
		Vector3.new(0.6, 8, 8),
		CFrame.new(center + Vector3.new(0, top + 4.5, 0)),
		Enum.Material.Neon,
		RED,
		Enum.PartType.Cylinder
	)
	portal.Transparency = 0.25
	portal.CanCollide = false
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(RED)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 30
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = portal
	CollectionService:AddTag(portal, "BeatGamePortal")
end

local function buildBeatGameCourse(world)
	local model = Instance.new("Model")
	model.Name = "BeatGameCourse"
	model.Parent = world

	-- Lava covering the ground outside the east wall, under the whole course
	local wallOuter = WorldConfig.GroundSize / 2 + WorldConfig.WallThickness
	local lavaEndX = HILL_CENTER.X + HILL_TIERS[1].radius + 40
	local lava = makePart(
		model,
		"Lava",
		Vector3.new(lavaEndX - wallOuter, 1, 400),
		CFrame.new(ARENA.Center + Vector3.new((wallOuter + lavaEndX) / 2, 0, 0)),
		Enum.Material.CrackedLava,
		LAVA_COLOR
	)
	CollectionService:AddTag(lava, "KillFloor")

	for _, info in ipairs(COURSE_BUILDINGS) do
		buildCourseBuilding(model, info)
	end
	buildHill(model)
end

local function buildBeatGameSign(world)
	local position = ARENA.Center + WorldConfig.BeatGame.SignPosition
	local facing = CFrame.lookAt(position, Vector3.new(ARENA.Center.X, position.Y, ARENA.Center.Z))
	for _, side in ipairs({ -1, 1 }) do
		makePart(world, "BeatGameSignPost", Vector3.new(0.6, 10, 0.6), facing * CFrame.new(side * 7, 5, 0), Enum.Material.Wood, Color3.fromRGB(90, 60, 40))
	end
	local board = makePart(world, "BeatGameSign", Vector3.new(14, 7, 0.4), facing * CFrame.new(0, 7, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 20))
	local text = "HOW TO BEAT THE GAME\nGet over the east wall (no stairs!) and leave the map. Jump across the buildings to the hill. "
		.. "Don't touch the lava! Go into the RED portal at the top, then press the red button."
	-- Readable from both sides
	addSign(board, Enum.NormalId.Front, text, Color3.fromRGB(255, 70, 70))
	addSign(board, Enum.NormalId.Back, text, Color3.fromRGB(255, 70, 70))
end

local function buildWorld()
	local existing = Workspace:FindFirstChild(WORLD_NAME)
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = WORLD_NAME
	world.Parent = Workspace

	local center = ARENA.Center

	makePart(world, "Ground", Vector3.new(WorldConfig.GroundSize, 2, WorldConfig.GroundSize), CFrame.new(center + Vector3.new(0, -1, 0)), Enum.Material.Grass, Color3.fromRGB(76, 120, 60))
	makePart(
		world,
		"Plaza",
		Vector3.new(0.3, ARENA.DistrictRadius * 2, ARENA.DistrictRadius * 2),
		CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Enum.Material.Slate,
		Color3.fromRGB(150, 150, 155),
		Enum.PartType.Cylinder
	)

	-- Perimeter walls around the whole map (no roof)
	local half = WorldConfig.GroundSize / 2
	local wallHeight, wallThickness = WorldConfig.WallHeight, WorldConfig.WallThickness
	local wallColor = Color3.fromRGB(95, 95, 105)
	local wallLength = WorldConfig.GroundSize + wallThickness * 2
	for _, side in ipairs({ -1, 1 }) do
		makePart(world, "BoundaryWallZ" .. side, Vector3.new(wallLength, wallHeight, wallThickness), CFrame.new(center + Vector3.new(0, wallHeight / 2, side * (half + wallThickness / 2))), Enum.Material.Concrete, wallColor)
		makePart(world, "BoundaryWallX" .. side, Vector3.new(wallThickness, wallHeight, WorldConfig.GroundSize), CFrame.new(center + Vector3.new(side * (half + wallThickness / 2), wallHeight / 2, 0)), Enum.Material.Concrete, wallColor)
	end

	buildBeatGameCourse(world)
	buildBeatGameSign(world)

	-- Normal shop kiosk, facing the arena
	local shopPosition = center + WorldConfig.Shop.Position
	buildKiosk(world, CFrame.lookAt(shopPosition, Vector3.new(center.X, shopPosition.Y, center.Z)) * CFrame.Angles(0, math.pi, 0), "SHOP", Color3.fromRGB(60, 120, 220), "normal")

	-- Color Shop kiosk on the other side of the ring: sells the current sky event's color skin
	local colorShopPosition = center + WorldConfig.ColorShop.Position
	buildKiosk(world, CFrame.lookAt(colorShopPosition, Vector3.new(center.X, colorShopPosition.Y, center.Z)) * CFrame.Angles(0, math.pi, 0), "COLOR SHOP", Color3.fromRGB(200, 60, 200), "color")

	for i = 1, GYM.Count do
		local gymPosition = WorldConfig.GetGymCFrame(i).Position
		local toCenter = (center - gymPosition).Unit
		local doorPosition = gymPosition + toCenter * (GYM.Depth / 2)
		local plazaEdge = center - toCenter * (ARENA.DistrictRadius - 2)
		local midpoint = (doorPosition + plazaEdge) / 2
		makePart(
			world,
			"Path" .. i,
			Vector3.new(14, 0.2, (doorPosition - plazaEdge).Magnitude),
			CFrame.lookAt(midpoint, doorPosition) + Vector3.new(0, 0.1, 0),
			Enum.Material.Concrete,
			Color3.fromRGB(120, 120, 125)
		)

		buildGym(world, i)
	end

	-- Player spawns between the paths, spread out so 90 players don't all land in one spot
	for i = 1, GYM.Count do
		local angle = (i - 0.5) * (2 * math.pi / GYM.Count)
		local position = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * WorldConfig.SpawnRadius + Vector3.new(0, 0.5, 0)
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "Spawn" .. i
		spawnLocation.Size = Vector3.new(10, 1, 10)
		spawnLocation.CFrame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Material = Enum.Material.SmoothPlastic
		spawnLocation.Color = Color3.fromRGB(230, 230, 230)
		spawnLocation.Parent = world
	end

	return world
end

buildWorld()
