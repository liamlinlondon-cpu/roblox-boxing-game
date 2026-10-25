-- Magic Carpet riding. Equipping the "Magic Carpet" tool (given by StoreService) makes the player sit and
-- fly with FlightController: WASD to fly, Space up, Q down. Unequipping it lands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FlightController"))

local player = Players.LocalPlayer

local CARPET_TOOL_NAME = "Magic Carpet"
local CARPET_SPEED = 80 -- studs per second

local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool)
	if not tool:IsA("Tool") or tool.Name ~= CARPET_TOOL_NAME or hooked[tool] then
		return
	end
	hooked[tool] = true
	local riding = false
	tool.Equipped:Connect(function()
		riding = true
		FlightController.Start(player.Character, { speed = CARPET_SPEED, sit = true })
	end)
	local function land()
		if riding then
			riding = false
			FlightController.Stop()
		end
	end
	tool.Unequipped:Connect(land)
	tool.Destroying:Connect(land) -- e.g. the owner's /reset takes the carpet away
end

-- The tool sits in the Backpack (a child of the player) until it's equipped
player.DescendantAdded:Connect(hookTool)
for _, descendant in ipairs(player:GetDescendants()) do
	hookTool(descendant)
end
