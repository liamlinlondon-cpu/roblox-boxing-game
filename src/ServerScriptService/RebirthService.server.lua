-- Rebirths (see FighterStats.RebirthRequirement). The ♻ button (RebirthClient) asks for the player's
-- rebirth info and asks to rebirth. Rebirthing needs the next rebirth's strength, kick and max stamina;
-- it resets those three, wins and the beat the game count to a new player's values (money stays), adds +1x to
-- training gains for good, and gives a walk
-- speed and jump boost (+15, doubling each rebirth). Max 5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))
local Catalog = require(Modules:WaitForChild("Catalog"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local matchResultEvent = eventsFolder:WaitForChild("MatchResult")

local rebirthFunction = Instance.new("RemoteFunction")
rebirthFunction.Name = "Rebirth"
rebirthFunction.Parent = eventsFolder

local function sendStats(player)
	local data = FighterStats.GetPlayerData(player)
	matchResultEvent:FireClient(player, {
		type = "stats",
		money = data.money,
		strength = data.strength,
		kick = data.kick,
		luck = data.luck,
		bodyStage = data.bodyStage,
		health = data.health,
		stamina = data.stamina,
		maxStamina = data.maxStamina,
		arenaWins = data.arenaWins,
		gameBeats = data.gameBeats,
		rebirths = data.rebirths,
	})
end

-- What the panel shows: rebirths done, the next requirements and the player's current numbers
local function rebirthInfo(data)
	local rebirths = data.rebirths or 0
	return {
		rebirths = rebirths,
		speedBoost = FighterStats.RebirthSpeedBoost(rebirths),
		nextSpeedBoost = FighterStats.RebirthSpeedBoost(rebirths + 1),
		max = FighterStats.MaxRebirths,
		multiplier = FighterStats.RebirthMultiplier(data),
		nextRequirement = rebirths < FighterStats.MaxRebirths and FighterStats.RebirthRequirement(rebirths + 1) or nil,
		strength = data.strength,
		kick = data.kick,
		stamina = data.maxStamina,
	}
end

-- Walk speed and jump power with the player's rebirth boost
local function applySpeedBoost(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local boost = FighterStats.RebirthSpeedBoost(FighterStats.GetPlayerData(player).rebirths)
	-- The owner's admin panel can set speed and jump directly; those win over the rebirth boost
	-- Capped at MaxMoveValue: the doubling boost would soon be too fast for Roblox to move a character
	local cap = FighterStats.MaxMoveValue
	humanoid.WalkSpeed = player:GetAttribute("AdminWalkSpeed") or math.min(FighterStats.BaseWalkSpeed + boost, cap)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = player:GetAttribute("AdminJumpPower") or math.min(FighterStats.BaseJumpPower + boost, cap)
end

local function meets(data, requirement)
	return data.strength >= requirement.strength and data.kick >= requirement.kick and data.maxStamina >= requirement.stamina
end

local function rebirth(player)
	local data = FighterStats.GetPlayerData(player)
	local rebirths = data.rebirths or 0
	if rebirths >= FighterStats.MaxRebirths then
		return false, "You've reached the max of " .. FighterStats.MaxRebirths .. " rebirths!"
	end
	if data.isInMatch then
		return false, "Finish your arena match first."
	end
	local requirement = FighterStats.RebirthRequirement(rebirths + 1)
	if not meets(data, requirement) then
		return false, "You don't have enough strength, kick and stamina yet."
	end

	-- Back to a new player's strength, kick, stamina, wins and beat the game count.
	-- Money, items, skins, treadmills, luck and upgrades stay.
	local fresh = FighterStats.CreatePlayerData()
	data.strength = fresh.strength
	data.kick = fresh.kick
	data.maxStamina = fresh.maxStamina
	data.stamina = fresh.stamina
	data.arenaWins = fresh.arenaWins
	data.arenaLosses = fresh.arenaLosses
	data.gameBeats = fresh.gameBeats
	data.bodyStage = FighterStats.GetStageFromStrength(data.strength)
	data.rebirths = rebirths + 1
	applySpeedBoost(player)
	sendStats(player)
	return true, "Rebirth " .. data.rebirths .. " done! Training now gives " .. FighterStats.RebirthMultiplier(data)
		.. "x, and you have +" .. Catalog.FormatNumber(FighterStats.RebirthSpeedBoost(data.rebirths)) .. " speed and jump (up to "
		.. FighterStats.MaxMoveValue .. ")."
end

rebirthFunction.OnServerInvoke = function(player, action)
	local data = FighterStats.GetPlayerData(player)
	if action == "rebirth" then
		local ok, message = rebirth(player)
		return { ok = ok, message = message, info = rebirthInfo(data) }
	end
	return { info = rebirthInfo(data) }
end

-- The speed boost comes back with every new character, and once saved progress has loaded
local function watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applySpeedBoost(player)
	end)
	if player.Character then
		applySpeedBoost(player)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
script.Parent:WaitForChild("PlayerDataService"):WaitForChild("DataLoaded").Event:Connect(applySpeedBoost)

-- ==================== 2 MILLION REWARD ====================
-- The first time a player has 2 million strength, kick and stamina at once, they get 1,000 money
-- (games can't give out real Robux). Once per player; /reset lets them earn it again.
local MILESTONE = 2000000
local MILESTONE_REWARD = 1000
local announcementEvent = eventsFolder:WaitForChild("Announcement")

task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = FighterStats.GetPlayerData(player)
			if not data.milestoneRewarded and data.strength >= MILESTONE and data.kick >= MILESTONE and data.maxStamina >= MILESTONE then
				data.milestoneRewarded = true
				data.money += MILESTONE_REWARD
				sendStats(player)
				announcementEvent:FireClient(player, "🎉 2 million strength, kick and stamina! +1,000 money")
			end
		end
	end
end)

-- ==================== TELEPORT ====================
-- Once a player's rebirth speed boost goes past the speed cap (about rebirth 8), they can teleport by
-- pressing T: TeleportClient sends where their mouse points. Anywhere inside the map is allowed, but not
-- past the wall (so the parkour can't be skipped). The owner can always teleport, to anywhere.
local Admins = require(script.Parent:WaitForChild("Admins"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local TELEPORT_COOLDOWN = 0.75
local MAP_INSIDE = WorldConfig.GroundSize / 2 - 2 -- just inside the wall
local lastTeleport = {}

local function canTeleport(player)
	if Admins.IsOwner(player) then
		return true
	end
	local boost = FighterStats.RebirthSpeedBoost(FighterStats.GetPlayerData(player).rebirths)
	return FighterStats.BaseWalkSpeed + boost > FighterStats.MaxMoveValue
end

local teleportFunction = Instance.new("RemoteFunction")
teleportFunction.Name = "Teleport"
teleportFunction.Parent = eventsFolder

-- No target: "may I teleport?"; with a target: teleport there if allowed
-- Pointing at the side of something (a wall, a building) means "go on top of it": find the highest
-- surface in that spot by looking straight down from high above
-- fromAbove: the target only says where on the map (from the VIP ADMIN panel's map); land on whatever is
-- highest there
local function landingSpot(player, target, normal, fromAbove)
	local inside
	if fromAbove then
		inside = target
	elseif typeof(normal) ~= "Vector3" or math.abs(normal.Y) >= 0.5 then
		return target -- pointing at the floor or a roof: land right there
	else
		inside = target - normal.Unit * 1.5 -- step into the wall so the downward look hits its top
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = Workspace:Raycast(Vector3.new(inside.X, inside.Y + 600, inside.Z), Vector3.new(0, -700, 0), params)
	return result and result.Position or target
end

teleportFunction.OnServerInvoke = function(player, target, normal, fromAbove)
	if not canTeleport(player) then
		return false, "Teleporting unlocks when your rebirth speed goes past " .. FighterStats.MaxMoveValue .. "."
	end
	if target == nil then
		return true
	end
	if typeof(target) ~= "Vector3" or target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return false, "Point at the ground to teleport."
	end
	target = landingSpot(player, target, normal, fromAbove == true)
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < TELEPORT_COOLDOWN then
		return false, nil
	end
	local offset = target - WorldConfig.Arena.Center
	-- Everyone stays inside the map, except the owner, who can teleport anywhere (parkour included)
	local isOwner = Admins.IsOwner(player)
	if not isOwner and (math.abs(offset.X) > MAP_INSIDE or math.abs(offset.Z) > MAP_INSIDE) then
		return false, "You can't teleport outside the map (no skipping the parkour)."
	end
	if not isOwner and (offset.Y > 500 or offset.Y < -50) then
		return false, "Point at the ground to teleport."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or FighterStats.GetPlayerData(player).isInMatch then
		return false, nil
	end
	lastTeleport[player] = now
	character:PivotTo(CFrame.new(target + Vector3.new(0, 4, 0)) * (character:GetPivot() - character:GetPivot().Position))
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)
