-- The disco party (DiscoService): while ReplicatedStorage's "DiscoParty" attribute is on, it's night, a
-- giant mirror disco ball spins high above the world, rays of light turn around it in the sky, and colored
-- spotlights sweep left and right across the whole world. Each spotlight's beam comes down from the ball
-- and lands on whatever is below it (the ground, a gym roof, a parkour building, the hill), lighting it up.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))

local BALL_SIZE = 44
local BALL_HEIGHT = 260
local SPOT_COUNT = 24 -- lights sweeping over the world
local SKY_RAYS = 12 -- rays turning around the ball in the sky
local SWEEP = 70 -- how far each light sweeps left and right (studs)

local party = nil -- everything built for the current party

local function newPart(parent, name, size, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function beam(parent, from, to, width0, width1, transparency)
	local b = Instance.new("Beam")
	b.Attachment0 = from
	b.Attachment1 = to
	b.Width0 = width0
	b.Width1 = width1
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 1
	b.Transparency = NumberSequence.new(transparency, transparency + 0.3)
	b.Parent = parent
	return b
end

-- The world from the west wall to the end of the parkour lava
local function worldBounds()
	local half = WorldConfig.GroundSize / 2
	local maxX = 770
	local world = Workspace:FindFirstChild("BoxingWorld")
	local course = world and world:FindFirstChild("BeatGameCourse")
	local lava = course and course:FindFirstChild("Lava")
	if lava then
		maxX = lava.Position.X + lava.Size.X / 2
	end
	return -half, maxX, -half, half
end

local function startParty()
	if party then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DiscoParty"
	folder.Parent = Workspace

	-- Night, so the lights stand out (the old values come back afterwards)
	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(35, 25, 50)
	Lighting.OutdoorAmbient = Color3.fromRGB(45, 30, 70)

	local minX, maxX, minZ, maxZ = worldBounds()
	local center = Vector3.new((minX + maxX) / 2, BALL_HEIGHT, (minZ + maxZ) / 2)

	-- The disco ball: mirror-shiny, with a glow and twinkles
	local ball = newPart(folder, "DiscoBall", Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE), Enum.PartType.Ball)
	ball.Material = Enum.Material.Foil
	ball.Color = Color3.fromRGB(220, 225, 235)
	ball.Reflectance = 0.6
	ball.CFrame = CFrame.new(center)
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 3
	glow.Parent = ball
	local twinkles = Instance.new("ParticleEmitter")
	twinkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	twinkles.Rate = 40
	twinkles.Lifetime = NumberRange.new(0.4, 0.9)
	twinkles.Speed = NumberRange.new(0)
	twinkles.Size = NumberSequence.new(3, 0)
	twinkles.LightEmission = 1
	twinkles.Shape = Enum.ParticleEmitterShape.Sphere
	twinkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	twinkles.Parent = ball
	local ballCenter = Instance.new("Attachment")
	ballCenter.Parent = ball

	-- Rays turning around the ball in the sky
	local skyRays = {}
	for i = 1, SKY_RAYS do
		local holder = newPart(folder, "SkyRay", Vector3.new(1, 1, 1))
		holder.Transparency = 1
		local tip = Instance.new("Attachment")
		tip.Parent = holder
		local ray = beam(holder, ballCenter, tip, 3, 40, 0.55)
		table.insert(skyRays, { part = holder, beam = ray, phase = (i - 1) / SKY_RAYS * math.pi * 2, tilt = (i % 3 - 1) * 0.35 })
	end

	-- Spotlights sweeping over the world, spread out in a grid so every part of it gets some
	local spots = {}
	local columns = math.ceil(math.sqrt(SPOT_COUNT * (maxX - minX) / (maxZ - minZ)))
	local rows = math.ceil(SPOT_COUNT / columns)
	for i = 1, SPOT_COUNT do
		local column = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local home = Vector3.new(
			minX + (column + 0.5) / columns * (maxX - minX),
			0,
			minZ + (row + 0.5) / rows * (maxZ - minZ)
		)
		local spot = newPart(folder, "DiscoSpot", Vector3.new(1, 1, 1))
		spot.Transparency = 1
		local landing = Instance.new("Attachment")
		landing.Parent = spot
		local light = Instance.new("PointLight")
		light.Range = 55
		light.Brightness = 6
		light.Shadows = false
		light.Parent = spot
		local ray = beam(spot, ballCenter, landing, 1.5, 22, 0.45)
		table.insert(spots, {
			part = spot,
			light = light,
			beam = ray,
			home = home,
			speed = 0.5 + (i % 4) * 0.15,
			phase = i * 1.7,
			hue = (i - 1) / SPOT_COUNT,
		})
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }

	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		ball.CFrame = CFrame.new(center) * CFrame.Angles(0, t * 0.8, 0)

		for _, ray in ipairs(skyRays) do
			local angle = ray.phase + t * 0.6
			local direction = Vector3.new(math.cos(angle), ray.tilt + 0.15 * math.sin(t + ray.phase), math.sin(angle))
			ray.part.Position = center + direction.Unit * 700
			ray.beam.Color = ColorSequence.new(Color3.fromHSV((t * 0.15 + ray.phase / 6) % 1, 0.8, 1))
		end

		-- Each light swings left and right (and drifts a little forward and back), then lands on whatever
		-- is under it: the ground, a roof or the hill
		for _, spot in ipairs(spots) do
			local swing = math.sin(t * spot.speed + spot.phase) * SWEEP
			local drift = math.cos(t * spot.speed * 0.6 + spot.phase) * SWEEP * 0.4
			local x = math.clamp(spot.home.X + swing, minX, maxX)
			local z = math.clamp(spot.home.Z + drift, minZ, maxZ)
			local hit = Workspace:Raycast(Vector3.new(x, BALL_HEIGHT - 30, z), Vector3.new(0, -(BALL_HEIGHT + 50), 0), params)
			local ground = hit and hit.Position or Vector3.new(x, 0, z)
			spot.part.Position = ground + Vector3.new(0, 6, 0)
			local color = Color3.fromHSV((spot.hue + t * 0.1) % 1, 0.85, 1)
			spot.light.Color = color
			spot.beam.Color = ColorSequence.new(color)
		end
	end)

	party = { folder = folder, connection = connection, saved = saved }
end

local function stopParty()
	if not party then
		return
	end
	party.connection:Disconnect()
	party.folder:Destroy()
	for property, value in pairs(party.saved) do
		Lighting[property] = value
	end
	party = nil
end

local function update()
	if ReplicatedStorage:GetAttribute("DiscoParty") then
		startParty()
	else
		stopParty()
	end
end

update()
ReplicatedStorage:GetAttributeChangedSignal("DiscoParty"):Connect(update)
