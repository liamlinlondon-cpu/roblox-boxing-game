-- Walk through walls (/walls, owner only; AdminCommandService sets the player's "WalkThroughWalls"
-- attribute). While it's on, the character's body parts don't bump into anything, so walls, buildings
-- and the map edge can be walked straight through. The Humanoid still stands on floors, so you don't fall
-- through the ground. Turned off, the body is solid again.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local saved = {} -- [part] = its CanCollide before walking through walls

local function restore()
	for part, canCollide in pairs(saved) do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end
	table.clear(saved)
end

-- The Humanoid sets some parts back to solid every frame, so this runs every physics step
RunService.Stepped:Connect(function()
	local character = player.Character
	if not player:GetAttribute("WalkThroughWalls") or not character then
		if next(saved) then
			restore()
		end
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			if saved[part] == nil then
				saved[part] = true
			end
			part.CanCollide = false
		end
	end
end)

player.CharacterAdded:Connect(function()
	table.clear(saved) -- the old body is gone
end)
