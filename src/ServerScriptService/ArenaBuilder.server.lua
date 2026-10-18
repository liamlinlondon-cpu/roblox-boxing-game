local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local ARENA_NAME = "BoxingArena"
local ARENA = WorldConfig.Arena

local function makePart(parent, name, size, cframe, material, color)
	local part = Instance.new("Part")
	part.Name = name
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

local function clearArena()
	local existing = Workspace:FindFirstChild(ARENA_NAME)
	if existing then
		existing:Destroy()
	end
end

local function buildArena()
	clearArena()

	local arena = Instance.new("Folder")
	arena.Name = ARENA_NAME
	arena.Parent = Workspace

	local center = ARENA.Center
	local half = ARENA.RingSize / 2
	local canvasTop = ARENA.RingHeight
	local platformHalf = half + 3

	-- Raised ring base with the canvas on top
	makePart(
		arena,
		"Platform",
		Vector3.new(platformHalf * 2, canvasTop - 0.4, platformHalf * 2),
		CFrame.new(center + Vector3.new(0, (canvasTop - 0.4) / 2, 0)),
		Enum.Material.Concrete,
		Color3.fromRGB(45, 45, 45)
	)
	makePart(
		arena,
		"RingFloor",
		Vector3.new(ARENA.RingSize + 2, 0.4, ARENA.RingSize + 2),
		CFrame.new(center + Vector3.new(0, canvasTop - 0.2, 0)),
		Enum.Material.Fabric,
		Color3.fromRGB(30, 60, 140)
	)

	-- Corner posts: red corner at (-x, +z), blue corner at (+x, -z)
	local corners = {
		{ name = "RedPost", offset = Vector3.new(-half, 0, half), color = Color3.fromRGB(220, 40, 40) },
		{ name = "BluePost", offset = Vector3.new(half, 0, -half), color = Color3.fromRGB(40, 70, 220) },
		{ name = "NeutralPost1", offset = Vector3.new(half, 0, half), color = Color3.fromRGB(240, 240, 240) },
		{ name = "NeutralPost2", offset = Vector3.new(-half, 0, -half), color = Color3.fromRGB(240, 240, 240) },
	}
	for _, corner in ipairs(corners) do
		makePart(
			arena,
			corner.name,
			Vector3.new(1, ARENA.PostHeight, 1),
			CFrame.new(center + corner.offset + Vector3.new(0, canvasTop + ARENA.PostHeight / 2, 0)),
			Enum.Material.Metal,
			corner.color
		)
	end

	-- Three rope levels. Ropes don't collide so players can climb in and out through them.
	local ropeLevels = {
		{ height = 2, color = Color3.fromRGB(220, 40, 40) },
		{ height = 3.5, color = Color3.fromRGB(245, 245, 245) },
		{ height = 5, color = Color3.fromRGB(40, 70, 220) },
	}
	for level, rope in ipairs(ropeLevels) do
		local y = canvasTop + rope.height
		local sides = {
			{ "North", Vector3.new(ARENA.RingSize, 0.3, 0.3), Vector3.new(0, y, -half) },
			{ "South", Vector3.new(ARENA.RingSize, 0.3, 0.3), Vector3.new(0, y, half) },
			{ "West", Vector3.new(0.3, 0.3, ARENA.RingSize), Vector3.new(-half, y, 0) },
			{ "East", Vector3.new(0.3, 0.3, ARENA.RingSize), Vector3.new(half, y, 0) },
		}
		for _, side in ipairs(sides) do
			local part = makePart(arena, "Rope" .. level .. side[1], side[2], CFrame.new(center + side[3]), Enum.Material.Fabric, rope.color)
			part.CanCollide = false
		end
	end

	-- Steps up to the ring on the north and south sides
	for _, direction in ipairs({ 1, -1 }) do
		for step = 1, 3 do
			local height = (canvasTop - 0.4) * step / 4
			local z = direction * (platformHalf + (4 - step) * 2 - 1)
			makePart(
				arena,
				"Step" .. step,
				Vector3.new(6, height, 2),
				CFrame.new(center + Vector3.new(0, height / 2, z)),
				Enum.Material.Concrete,
				Color3.fromRGB(70, 70, 70)
			)
		end
	end

	-- Fighter spawn points used by CharacterAnimationService. These are plain parts (not SpawnLocations)
	-- so players joining the server don't spawn inside the ring.
	local redSpawn = makePart(arena, "RedSpawn", Vector3.new(2, 0.2, 2), CFrame.new(center + Vector3.new(-half + 4, canvasTop + 1.3, half - 4)))
	local blueSpawn = makePart(arena, "BlueSpawn", Vector3.new(2, 0.2, 2), CFrame.new(center + Vector3.new(half - 4, canvasTop + 1.3, -half + 4)))
	for _, spawnPart in ipairs({ redSpawn, blueSpawn }) do
		spawnPart.Transparency = 1
		spawnPart.CanCollide = false
	end

	-- Center marker and corner pads on the canvas
	local centerMarker = makePart(arena, "CenterMarker", Vector3.new(2, 0.1, 2), CFrame.new(center + Vector3.new(0, canvasTop + 0.05, 0)), Enum.Material.Neon, Color3.fromRGB(255, 215, 0))
	centerMarker.CanCollide = false
	local redPad = makePart(arena, "RedPad", Vector3.new(4, 0.1, 4), CFrame.new(center + Vector3.new(-half + 3, canvasTop + 0.05, half - 3)), Enum.Material.SmoothPlastic, Color3.fromRGB(255, 100, 100))
	redPad.CanCollide = false
	local bluePad = makePart(arena, "BluePad", Vector3.new(4, 0.1, 4), CFrame.new(center + Vector3.new(half - 3, canvasTop + 0.05, -half + 3)), Enum.Material.SmoothPlastic, Color3.fromRGB(100, 100, 255))
	bluePad.CanCollide = false

	-- Corner buttons outside the ring: step on a button (hold E) to enter that corner. When both corners
	-- are taken by different players the match starts in 3 seconds (ArenaService).
	for _, button in ipairs({
		{ team = "red", x = -4, color = Color3.fromRGB(220, 40, 40), label = "RED CORNER" },
		{ team = "blue", x = 4, color = Color3.fromRGB(40, 70, 220), label = "BLUE CORNER" },
	}) do
		local part = makePart(arena, button.team .. "Button", Vector3.new(3, 0.6, 3), CFrame.new(center + Vector3.new(button.x, 0.3, 24)), Enum.Material.Neon, button.color)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter " .. button.label
		prompt.ObjectText = "Boxing ring"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Team", button.team)
		prompt.Parent = part
		CollectionService:AddTag(prompt, "ArenaButton")
	end

	-- Spectator bleachers between the six gym paths, each facing the ring
	local gymCount = WorldConfig.Gyms.Count
	for i = 1, gymCount do
		local angle = (i - 0.5) * (2 * math.pi / gymCount)
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		for tier = 1, 4 do
			local height = tier * 1.5
			local position = center + direction * (26 + (tier - 0.5) * 3.5) + Vector3.new(0, height / 2, 0)
			makePart(
				arena,
				"Bleacher" .. i .. "_" .. tier,
				Vector3.new(16 + tier * 3, height, 3.5),
				CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)),
				Enum.Material.WoodPlanks,
				Color3.fromRGB(110, 80, 55)
			)
		end
	end

	-- Light towers aimed at the ring
	for i = 1, 4 do
		local angle = (i - 0.5) * (math.pi / 2)
		local base = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * 44
		makePart(arena, "LightPole" .. i, Vector3.new(1.5, 24, 1.5), CFrame.new(base + Vector3.new(0, 12, 0)), Enum.Material.Metal, Color3.fromRGB(90, 90, 90))
		local headPosition = base + Vector3.new(0, 24.5, 0)
		local head = makePart(
			arena,
			"LightHead" .. i,
			Vector3.new(4, 2, 1),
			CFrame.lookAt(headPosition, center + Vector3.new(0, canvasTop, 0)),
			Enum.Material.Neon,
			Color3.fromRGB(255, 250, 220)
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 50
		spot.Range = 60
		spot.Brightness = 5
		spot.Parent = head
	end

	-- Lighting for arena atmosphere
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(120, 120, 120)
	lighting.Brightness = 2.5
	lighting.ColorShift_Top = Color3.fromRGB(80, 80, 80)
	lighting.ColorShift_Bottom = Color3.fromRGB(20, 20, 20)

	return arena
end

buildArena()
