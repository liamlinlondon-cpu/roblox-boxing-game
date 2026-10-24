-- Flying for the owner's /fly command. The server (AdminCommandService) only turns flying on for
-- admins; this script then moves the character: WASD/thumbstick to fly where the camera looks,
-- Space to go up, Q or Ctrl to go down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local flyEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AdminFly")

local player = Players.LocalPlayer

local FLY_SPEED = 60 -- studs per second

local flyEnabled = false
local flight = nil -- { connection, attachment, velocity, align, humanoid } while flying

local function stopFlight()
	if not flight then
		return
	end
	flight.connection:Disconnect()
	flight.velocity:Destroy()
	flight.align:Destroy()
	flight.attachment:Destroy()
	if flight.humanoid.Parent then
		flight.humanoid.PlatformStand = false
		flight.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	flight = nil
end

local function startFlight(character)
	stopFlight()
	local humanoid = character:WaitForChild("Humanoid", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not root or not flyEnabled then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FlyAttachment"
	attachment.Parent = root

	-- Drives the character's velocity directly, which also cancels gravity
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	-- Keeps the character upright and facing where the camera faces
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.Parent = root

	humanoid.PlatformStand = true

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.01 then
			flatLook = Vector3.new(0, 0, -1)
		end
		flatLook = flatLook.Unit

		-- MoveDirection is the walk input (WASD / thumbstick), already relative to the camera
		local move = humanoid.MoveDirection
		local vertical = 0
		if move.Magnitude > 0 then
			-- Tilt with the camera: looking up while moving forward climbs, looking down dives
			vertical = look.Y * move:Dot(flatLook)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			vertical += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			vertical -= 1
		end

		velocity.VectorVelocity = (move + Vector3.new(0, vertical, 0)) * FLY_SPEED
		align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
	end)

	flight = {
		connection = connection,
		attachment = attachment,
		velocity = velocity,
		align = align,
		humanoid = humanoid,
	}
end

flyEvent.OnClientEvent:Connect(function(enabled)
	flyEnabled = enabled
	if enabled and player.Character then
		startFlight(player.Character)
	else
		stopFlight()
	end
end)

-- Keep flying after respawning until /fly is used again
player.CharacterAdded:Connect(function(character)
	stopFlight()
	if flyEnabled then
		startFlight(character)
	end
end)
