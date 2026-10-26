-- Beat the game (the course is built by WorldBuilder):
--   * the lava outside the east wall kills anyone who touches it
--   * the yellow and blue pads on the hill are decoys ("Not this one!")
--   * the red portal on top of the hill teleports you into the room inside the front building
--   * pressing the red button there shows the "YOU BEAT THE GAME!" screen (BeatGameClient), then sends
--     you back to the map
-- Pads and the portal react each time you step in, with no cooldown.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local beatGameEvent = Instance.new("RemoteEvent")
beatGameEvent.Name = "BeatGame"
beatGameEvent.Parent = ReplicatedStorage:WaitForChild("Events")

local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")

-- Refreshes the player's stats panel (it shows how many times they beat the game)
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

local RETURN_AFTER_WIN_SECONDS = 8 -- how long the win screen shows before respawning in the map

-- Touches keep arriving many times a second while someone stands in a pad, so a touch only counts as
-- stepping in if that player hadn't touched it for a moment (they stepped off and came back)
local STEP_OFF_SECONDS = 0.5
local lastTouch = {} -- [player] = { [part] = os.clock() of the latest touch }

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid
	end
	return nil
end

local function steppedIn(player, part)
	local touches = lastTouch[player] or {}
	lastTouch[player] = touches
	local now = os.clock()
	local isNew = not touches[part] or now - touches[part] > STEP_OFF_SECONDS
	touches[part] = now
	return isNew
end

local function hookTag(tag, onTouch)
	local function hook(part)
		part.Touched:Connect(function(hit)
			local player, humanoid = playerFromHit(hit)
			if player then
				onTouch(part, player, humanoid)
			end
		end)
	end
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		hook(part)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

-- Lava: touching the ground outside the map kills
hookTag("KillFloor", function(_, _, humanoid)
	humanoid.Health = 0
end)

-- Decoy pads
hookTag("BeatGamePad", function(pad, player)
	if steppedIn(player, pad) then
		beatGameEvent:FireClient(player, "wrong")
	end
end)

-- Red portal: teleport into the room with the red button
hookTag("BeatGamePortal", function(portal, player)
	if not steppedIn(player, portal) then
		return
	end
	local arrival = CollectionService:GetTagged("BeatGameArrival")[1]
	if arrival and player.Character then
		player.Character:PivotTo(arrival.CFrame)
	end
end)

-- Red button: win the game (counted in gameBeats), then go back to the map
local winning = {} -- [player] = true between pressing the button and being sent back

local function hookButton(prompt)
	prompt.Triggered:Connect(function(player)
		if winning[player] then
			return
		end
		winning[player] = true
		local data = FighterStats.GetPlayerData(player)
		data.gameBeats = (data.gameBeats or 0) + 1
		sendStats(player)
		beatGameEvent:FireClient(player, "won")
		task.delay(RETURN_AFTER_WIN_SECONDS, function()
			winning[player] = nil
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
end
for _, prompt in ipairs(CollectionService:GetTagged("BeatGameButton")) do
	hookButton(prompt)
end
CollectionService:GetInstanceAddedSignal("BeatGameButton"):Connect(hookButton)

Players.PlayerRemoving:Connect(function(player)
	lastTouch[player] = nil
	winning[player] = nil
end)
