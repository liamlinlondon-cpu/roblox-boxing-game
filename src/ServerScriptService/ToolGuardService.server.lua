-- No outside tools: ban hammers, jetpacks, food and anything else from the Toolbox (or handed out by
-- old scripts) are cheating, e.g. a hammer that kills everyone in the boxing arena. Any tool that shows
-- up in a player's backpack or hands is deleted straight away, unless it's one of this game's own tools
-- (ALLOWED_TOOLS, given by StoreService). Tools put in the StarterPack are deleted too.

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local ALLOWED_TOOLS = {
	["Magic Carpet"] = true, -- StoreService
}

local function check(item)
	if item:IsA("Tool") and not ALLOWED_TOOLS[item.Name] then
		task.defer(function()
			if item.Parent then
				item:Destroy()
			end
		end)
	end
end

local function guard(container)
	for _, item in ipairs(container:GetChildren()) do
		check(item)
	end
	container.ChildAdded:Connect(check)
end

local function watchPlayer(player)
	-- The backpack and the character are made new on every respawn
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			guard(child)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		guard(backpack)
	end
	player.CharacterAdded:Connect(guard) -- a held tool sits in the character
	if player.Character then
		guard(player.Character)
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		guard(starterGear)
	end
end

guard(StarterPack)
Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
