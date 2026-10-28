-- The Disco skin (StoreService marks the wearer's character with the "DiscoSkin" attribute): the body
-- shines every color, each body part a little ahead of the next so the rainbow runs over them, and
-- colored spotlights spin around the wearer like a disco ball, lighting up everything nearby.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPOTLIGHTS = 6
local BODY_PARTS = {
	"Head", "UpperTorso", "LowerTorso", "Torso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local shining = {} -- [character] = { parts, root, holder, lights, glow }

local function stopShining(character)
	local entry = shining[character]
	if entry then
		entry.holder:Destroy()
		for _, spot in ipairs(entry.lights) do
			spot.attachment:Destroy()
		end
		shining[character] = nil
	end
end

local function startShining(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if shining[character] or not root then
		return
	end
	local parts = {}
	for index, name in ipairs(BODY_PARTS) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, { part = part, offset = index / #BODY_PARTS })
		end
	end
	-- The glow sits in one attachment and each spotlight in its own (all named DiscoSkinLights)
	local holder = Instance.new("Attachment")
	holder.Name = "DiscoSkinLights"
	holder.Parent = root
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 2
	glow.Parent = holder
	local lights = {}
	for i = 1, SPOTLIGHTS do
		local spot = Instance.new("Attachment")
		spot.Parent = root
		spot.Name = "DiscoSkinLights"
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 30
		light.Angle = 35
		light.Brightness = 6
		light.Parent = spot
		table.insert(lights, { attachment = spot, light = light, phase = (i - 1) / SPOTLIGHTS })
	end
	shining[character] = { parts = parts, holder = holder, lights = lights, glow = glow }
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for character, entry in pairs(shining) do
		if not character.Parent then
			shining[character] = nil
			continue
		end
		-- The rainbow running over the body
		for _, item in ipairs(entry.parts) do
			item.part.Color = Color3.fromHSV((t * 0.5 + item.offset) % 1, 0.9, 1)
		end
		entry.glow.Color = Color3.fromHSV((t * 0.5) % 1, 0.8, 1)
		-- Spotlights spinning around like a disco ball, tilted up and down a little
		for _, spot in ipairs(entry.lights) do
			local angle = (t * 1.5 + spot.phase) * math.pi * 2 / 1.5
			local tilt = math.sin(t * 2 + spot.phase * 6) * 0.4
			spot.attachment.CFrame = CFrame.Angles(0, angle + spot.phase * math.pi * 2, 0) * CFrame.Angles(tilt, 0, 0)
			spot.light.Color = Color3.fromHSV((t * 0.4 + spot.phase) % 1, 1, 1)
		end
	end
end)

-- Watch every character for the DiscoSkin attribute (it comes and goes as skins are worn)
local function watchCharacter(character)
	local function update()
		if character:GetAttribute("DiscoSkin") then
			startShining(character)
		else
			stopShining(character)
		end
	end
	character:GetAttributeChangedSignal("DiscoSkin"):Connect(update)
	character:WaitForChild("HumanoidRootPart", 10)
	update()
end

local function watchPlayer(other)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		task.spawn(watchCharacter, other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end
