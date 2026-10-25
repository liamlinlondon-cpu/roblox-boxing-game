-- Magic Carpet riding. Equipping the "Magic Carpet" tool (given by StoreService) makes the player sit and
-- fly with FlightController: WASD to fly, Space up, Q down. Unequipping it lands. Flying it outside the
-- map needs the Carpet Parkour Pass.

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

-- Riding outside the map without the Carpet Parkour Pass kills you (StoreService); explain why
local StarterGui = game:GetService("StarterGui")
local carpetNotice = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CarpetNotice")
carpetNotice.OnClientEvent:Connect(function()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "No Carpet Parkour Pass",
			Text = "Buy the Carpet Parkour Pass (10,000 money) in the shop to fly over the parkour.",
			Duration = 6,
		})
	end)
end)

-- The tool sits in the Backpack (a child of the player) until it's equipped
player.DescendantAdded:Connect(hookTool)
for _, descendant in ipairs(player:GetDescendants()) do
	hookTool(descendant)
end
