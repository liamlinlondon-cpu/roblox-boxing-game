-- Rebirths (see FighterStats.RebirthRequirements). The ♻ button (RebirthClient) asks for the player's
-- rebirth info and asks to rebirth. Rebirthing needs the next rebirth's strength, kick and max stamina;
-- it resets those three, wins and the beat the game count to a new player's values (money stays), adds +1x to
-- training gains for good, and gives a walk
-- speed and jump boost (+15, doubling each rebirth). Max 5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FighterStats = require(Modules:WaitForChild("FighterStats"))

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
		nextRequirement = FighterStats.RebirthRequirements[rebirths + 1],
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
	humanoid.WalkSpeed = player:GetAttribute("AdminWalkSpeed") or (FighterStats.BaseWalkSpeed + boost)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = player:GetAttribute("AdminJumpPower") or (FighterStats.BaseJumpPower + boost)
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
	local requirement = FighterStats.RebirthRequirements[rebirths + 1]
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
		.. "x, and you have +" .. FighterStats.RebirthSpeedBoost(data.rebirths) .. " speed and jump."
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
