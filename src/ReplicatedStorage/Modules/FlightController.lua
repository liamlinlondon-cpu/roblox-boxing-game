-- Client-side flying, shared by the owner's /fly (FlyClient) and the Magic Carpet (CarpetClient).
-- Controls: WASD / thumbstick flies where the camera looks, Space goes up, Q (or Ctrl) goes down.
-- Only one flight runs at a time; starting a new one stops the old one.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlightController = {}

-- Roblox's own default sit animations (usable in any game)
local SIT_ANIMATIONS = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}

local flight = nil -- { connection, attachment, velocity, align, humanoid, sitTrack } while flying

function FlightController.IsFlying()
	return flight ~= nil
end

function FlightController.Stop()
	if not flight then
		return
	end
	local current = flight
	flight = nil
	current.connection:Disconnect()
	current.velocity:Destroy()
	current.align:Destroy()
	current.attachment:Destroy()
	if current.sitTrack then
		current.sitTrack:Stop(0.2)
	end
	if current.humanoid.Parent then
		current.humanoid.PlatformStand = false
		current.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

-- options.speed: studs per second (default 60); options.sit: play the sitting pose (Magic Carpet)
function FlightController.Start(character, options)
	FlightController.Stop()
	options = options or {}
	local speed = options.speed or 60
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
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

	local sitTrack = nil
	if options.sit then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = SIT_ANIMATIONS[humanoid.RigType] or SIT_ANIMATIONS[Enum.HumanoidRigType.R15]
			sitTrack = animator:LoadAnimation(animation)
			sitTrack.Looped = true
			sitTrack.Priority = Enum.AnimationPriority.Action
			sitTrack:Play(0.2)
		end
	end

	local connection = RunService.RenderStepped:Connect(function()
		if not root.Parent or humanoid.Health <= 0 then
			FlightController.Stop()
			return
		end
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

		velocity.VectorVelocity = (move + Vector3.new(0, vertical, 0)) * speed
		align.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
	end)

	flight = {
		connection = connection,
		attachment = attachment,
		velocity = velocity,
		align = align,
		humanoid = humanoid,
		sitTrack = sitTrack,
	}
end

return FlightController
