-- Builds everything around the arena: ground, plaza, paths, player spawns and the ring of gyms.
-- Each gym has a free ground floor and a VIP second floor reached only by the VIP elevator pad
-- (VipAuctionService decides who may use it). Station training is handled in FlowService.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

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

local function buildStation(model, gymCFrame, gymIndex, name, x, floorTop, z, isVip)
	local padColor = isVip and GOLD or Color3.fromRGB(70, 70, 80)
	local pad = makePart(model, name, Vector3.new(6, 0.4, 6), gymCFrame * CFrame.new(x, floorTop + 0.2, z), Enum.Material.Fabric, padColor)
	pad:SetAttribute("Vip", isVip)

	-- Vertical punching bag hanging from the ceiling at the back edge of the pad
	local bagZ = z + 3.5
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

	local amount = isVip and GYM.VipTrainAmount or GYM.FreeTrainAmount
	addPrompt(pad, "Train (+" .. amount .. " strength)", isVip and "VIP Punching Bag" or "Punching Bag", "GymStation", {
		GymId = gymIndex,
		Vip = isVip,
	})
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
	local vipSign = makePart(model, "VipSign", Vector3.new(30, 4, 0.4), at(0, 2 * F - 3, -D / 2 - 0.25), Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25))
	addSign(vipSign, Enum.NormalId.Front, "VIP FLOOR", GOLD)

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

	-- Ground floor: free stations in two rows of five
	local xs = { -24, -12, 0, 12, 24 }
	local stationCount = 0
	for _, z in ipairs({ -6, 8 }) do
		for _, x in ipairs(xs) do
			stationCount += 1
			if stationCount <= GYM.FreeStations then
				buildStation(model, gymCFrame, index, "Station" .. stationCount, x, 1, z, false)
			end
		end
	end

	-- VIP floor: gold carpet and one row of VIP stations
	local carpet = makePart(model, "VipCarpet", Vector3.new(W - 4, 0.1, D - 4), at(0, F + 1.05, 0), Enum.Material.Fabric, Color3.fromRGB(120, 20, 30))
	carpet.CanCollide = false
	for i = 1, math.min(GYM.VipStations, #xs) do
		buildStation(model, gymCFrame, index, "VipStation" .. i, xs[i], F + 1, -2, true)
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
