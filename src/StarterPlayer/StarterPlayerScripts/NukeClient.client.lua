-- What everyone sees during a server nuke (NukeService):
--   countdown  a big red countdown at the top and the screen edges flashing red
--   boom       a white flash, a giant fireball in the middle of the map, a mushroom cloud rising, a
--              shockwave racing across the ground, the camera shaking, and fires burning all over the
--              map (roofs and the hill too). After a while it all clears and the world is back to normal.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))
local nukeEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Nuke")
local player = Players.LocalPlayer

local GROUND_ZERO = WorldConfig.Arena.Center
local FIRE_COUNT = 40

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NukeGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 30
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Red warning around the edges of the screen
local warning = Instance.new("Frame")
warning.Size = UDim2.fromScale(1, 1)
warning.BackgroundTransparency = 1
warning.Visible = false
warning.Parent = screenGui
local warningRing = Instance.new("UIStroke")
warningRing.Color = Color3.fromRGB(255, 0, 0)
warningRing.Thickness = 30
warningRing.Parent = warning

local countdownLabel = Instance.new("TextLabel")
countdownLabel.AnchorPoint = Vector2.new(0.5, 0)
countdownLabel.Size = UDim2.new(0, 520, 0, 90)
countdownLabel.Position = UDim2.new(0.5, 0, 0, 70)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3 = Color3.fromRGB(255, 40, 40)
countdownLabel.TextStrokeTransparency = 0
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextScaled = true
countdownLabel.Visible = false
countdownLabel.Parent = screenGui

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 5
flash.Parent = screenGui

local countdownToken = 0
local effects = nil -- { folder, tint } of the explosion on screen, so /none can clear it early

local function stopCountdown()
	countdownToken += 1
	warning.Visible = false
	countdownLabel.Visible = false
end

local function startCountdown(seconds)
	countdownToken += 1
	local token = countdownToken
	warning.Visible = true
	countdownLabel.Visible = true
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while countdownToken == token do
			local left = math.max(0, math.ceil(endsAt - os.clock()))
			countdownLabel.Text = "☢️ NUKE IN " .. left .. " ☢️"
			-- Flash the red edges faster as it gets close
			local speed = left <= 3 and 10 or 4
			warningRing.Transparency = 0.2 + 0.6 * (0.5 + 0.5 * math.sin(os.clock() * speed))
			if left <= 0 then
				break
			end
			task.wait()
		end
		if countdownToken == token then
			stopCountdown()
		end
	end)
end

-- ==================== THE EXPLOSION ====================
local function effectPart(parent, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function tween(object, seconds, goal, style)
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function smoke(parent, size, rate)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(90, 80, 75), Color3.fromRGB(40, 38, 36))
	emitter.Size = NumberSequence.new(size, size * 1.8)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(5, 15)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

local function shakeCamera(seconds)
	local endsAt = os.clock() + seconds
	RunService:BindToRenderStep("NukeShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = endsAt - os.clock()
		if left <= 0 then
			RunService:UnbindFromRenderStep("NukeShake")
			return
		end
		local strength = math.min(1, left / seconds) * 1.2
		local camera = Workspace.CurrentCamera
		camera.CFrame *= CFrame.Angles(
			math.rad((math.random() - 0.5) * 4 * strength),
			math.rad((math.random() - 0.5) * 4 * strength),
			0
		) + Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end)
end

-- Fires all over the map, on whatever is there (ground, roofs, the hill)
local function lightFires(folder)
	local half = WorldConfig.GroundSize / 2 - 10
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	for _ = 1, FIRE_COUNT do
		local x = GROUND_ZERO.X + (math.random() * 2 - 1) * half
		local z = GROUND_ZERO.Z + (math.random() * 2 - 1) * half
		local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
		local spot = hit and hit.Position or Vector3.new(x, 0, z)
		local ember = effectPart(folder, Vector3.new(4, 0.4, 4), CFrame.new(spot + Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 90, 20))
		local fire = Instance.new("Fire")
		fire.Size = math.random(8, 16)
		fire.Heat = 15
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
		fire.Parent = ember
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 110, 40)
		glow.Range = 20
		glow.Brightness = 2
		glow.Parent = ember
		smoke(ember, 6, 2)
	end
end

local function explode(fireSeconds)
	stopCountdown()
	local folder = Instance.new("Folder")
	folder.Name = "NukeEffects"
	folder.Parent = Workspace

	-- White flash that fades away
	flash.BackgroundTransparency = 0
	tween(flash, 2.5, { BackgroundTransparency = 1 })

	-- An orange tint over the world that fades
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "NukeTint"
	tint.TintColor = Color3.fromRGB(255, 170, 110)
	tint.Brightness = 0.3
	tint.Parent = Lighting
	tween(tint, 8, { TintColor = Color3.new(1, 1, 1), Brightness = 0 })

	shakeCamera(3)

	-- The fireball
	local fireball = effectPart(folder, Vector3.new(20, 20, 20), CFrame.new(GROUND_ZERO), Color3.fromRGB(255, 200, 80), Enum.Material.Neon, Enum.PartType.Ball)
	tween(fireball, 1.5, { Size = Vector3.new(260, 260, 260), Color = Color3.fromRGB(255, 90, 20) })
	task.delay(1.5, function()
		tween(fireball, 3, { Transparency = 1, Size = Vector3.new(300, 300, 300) })
	end)
	local blastLight = Instance.new("PointLight")
	blastLight.Range = 60
	blastLight.Brightness = 10
	blastLight.Color = Color3.fromRGB(255, 160, 60)
	blastLight.Parent = fireball

	-- The shockwave racing across the ground
	local wave = effectPart(folder, Vector3.new(2, 10, 10), CFrame.new(GROUND_ZERO + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 230, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	wave.Transparency = 0.3
	tween(wave, 2.5, { Size = Vector3.new(2, 1600, 1600), Transparency = 1 })

	-- The mushroom cloud: a stem rising from the ground with a big round cap on top
	local stem = effectPart(folder, Vector3.new(10, 40, 40), CFrame.new(GROUND_ZERO + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
	local cap = effectPart(folder, Vector3.new(40, 30, 40), CFrame.new(GROUND_ZERO + Vector3.new(0, 20, 0)), Color3.fromRGB(255, 140, 50), Enum.Material.Neon, Enum.PartType.Ball)
	task.delay(0.8, function()
		tween(stem, 4, { Size = Vector3.new(260, 60, 60), CFrame = CFrame.new(GROUND_ZERO + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 90, 80) })
		tween(cap, 4, { Size = Vector3.new(220, 110, 220), CFrame = CFrame.new(GROUND_ZERO + Vector3.new(0, 280, 0)), Color = Color3.fromRGB(120, 95, 85) })
		stem.Material = Enum.Material.SmoothPlastic
		cap.Material = Enum.Material.SmoothPlastic
		smoke(cap, 40, 15)
		smoke(stem, 25, 8)
	end)

	lightFires(folder)

	-- Back to normal: the cloud drifts away and the fires go out
	task.delay(fireSeconds - 4, function()
		tween(stem, 4, { Transparency = 1 })
		tween(cap, 4, { Transparency = 1 })
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("Fire") or item:IsA("ParticleEmitter") then
				item.Enabled = false
			elseif item:IsA("BasePart") then
				tween(item, 4, { Transparency = 1 })
			end
		end
	end)
	effects = { folder = folder, tint = tint }
	task.delay(fireSeconds, function()
		folder:Destroy()
		tint:Destroy()
	end)
end

nukeEvent.OnClientEvent:Connect(function(kind, value)
	if kind == "countdown" then
		startCountdown(tonumber(value) or 10)
	elseif kind == "cancel" then
		stopCountdown()
	elseif kind == "boom" then
		explode(tonumber(value) or 20)
	elseif kind == "clear" then
		-- /none: the fire, smoke and cloud go away now
		stopCountdown()
		RunService:UnbindFromRenderStep("NukeShake")
		flash.BackgroundTransparency = 1
		if effects then
			effects.folder:Destroy()
			effects.tint:Destroy()
			effects = nil
		end
	end
end)
