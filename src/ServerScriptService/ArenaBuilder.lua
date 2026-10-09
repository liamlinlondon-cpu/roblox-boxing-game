local Workspace = game:GetService("Workspace")

local ARENA_NAME = "BoxingArena"

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

local function makeSpawn(parent, name, position, teamColor)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Position = position
	spawn.Size = Vector3.new(1, 1, 1)
	spawn.Anchored = true
	spawn.Transparency = 0.3
	spawn.CanCollide = false
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = teamColor
	spawn.Neutral = false
	spawn.Parent = parent
	return spawn
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

	-- Main floor platform (2x2 arena)
	local platform = makePart(
		arena,
		"Platform",
		Vector3.new(2.8, 0.5, 2.8),
		CFrame.new(0, -0.25, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(45, 45, 45)
	)

	-- Fight floor
	local ringFloor = makePart(
		arena,
		"RingFloor",
		Vector3.new(2.2, 0.2, 2.2),
		CFrame.new(0, 0.1, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(25, 25, 25)
	)

	-- Corner posts
	local cornerPositions = {
		Vector3.new(-1.1, 1.5, -1.1),
		Vector3.new(1.1, 1.5, -1.1),
		Vector3.new(-1.1, 1.5, 1.1),
		Vector3.new(1.1, 1.5, 1.1),
	}

	for i, pos in ipairs(cornerPositions) do
		makePart(arena, "Post" .. i, Vector3.new(0.2, 3, 0.2), CFrame.new(pos), Enum.Material.Metal, Color3.fromRGB(255, 255, 255))
	end

	-- Ropes around the ring
	local ropeColor = Color3.fromRGB(255, 255, 255)
	local topRope = makePart(arena, "TopRope", Vector3.new(2.2, 0.1, 0.1), CFrame.new(0, 2.4, -1.1), Enum.Material.SmoothPlastic, ropeColor)
	local bottomRope = makePart(arena, "BottomRope", Vector3.new(2.2, 0.1, 0.1), CFrame.new(0, 2.4, 1.1), Enum.Material.SmoothPlastic, ropeColor)
	local leftRope = makePart(arena, "LeftRope", Vector3.new(0.1, 0.1, 2.2), CFrame.new(-1.1, 2.4, 0), Enum.Material.SmoothPlastic, ropeColor)
	local rightRope = makePart(arena, "RightRope", Vector3.new(0.1, 0.1, 2.2), CFrame.new(1.1, 2.4, 0), Enum.Material.SmoothPlastic, ropeColor)

	-- Ring corners for red and blue fighters
	local redSpawn = makeSpawn(arena, "RedSpawn", Vector3.new(-0.6, 1.5, 0.7), Color3.fromRGB(255, 60, 60))
	local blueSpawn = makeSpawn(arena, "BlueSpawn", Vector3.new(0.6, 1.5, -0.7), Color3.fromRGB(60, 60, 255))

	-- Center marker
	local centerMarker = makePart(arena, "CenterMarker", Vector3.new(0.15, 0.1, 0.15), CFrame.new(0, 0.2, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(255, 215, 0))
	centerMarker.CanCollide = false

	-- Red and blue corner pads
	local redPad = makePart(arena, "RedPad", Vector3.new(0.5, 0.1, 0.5), CFrame.new(-1, 0.2, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(255, 100, 100))
	redPad.CanCollide = false
	local bluePad = makePart(arena, "BluePad", Vector3.new(0.5, 0.1, 0.5), CFrame.new(1, 0.2, -1), Enum.Material.SmoothPlastic, Color3.fromRGB(100, 100, 255))
	bluePad.CanCollide = false

	-- Lighting for arena atmosphere
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(120, 120, 120)
	lighting.Brightness = 2.5
	lighting.ColorShift_Top = Color3.fromRGB(80, 80, 80)
	lighting.ColorShift_Bottom = Color3.fromRGB(20, 20, 20)

	return arena
end

buildArena()
