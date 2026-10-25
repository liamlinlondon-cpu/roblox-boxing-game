-- Flying for the owner's /fly command. The server (AdminCommandService) only turns flying on for
-- admins; FlightController does the flying (WASD to fly, Space up, Q or Ctrl down).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FlightController"))
local flyEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AdminFly")

local player = Players.LocalPlayer

local FLY_SPEED = 60 -- studs per second

local flyEnabled = false

local function startFlying(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and flyEnabled then
		FlightController.Start(character, { speed = FLY_SPEED })
	end
end

flyEvent.OnClientEvent:Connect(function(enabled)
	flyEnabled = enabled
	if enabled and player.Character then
		startFlying(player.Character)
	else
		FlightController.Stop()
	end
end)

-- Keep flying after respawning until /fly is used again
player.CharacterAdded:Connect(function(character)
	FlightController.Stop()
	if flyEnabled then
		startFlying(character)
	end
end)
