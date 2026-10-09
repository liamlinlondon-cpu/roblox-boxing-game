local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FighterStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FighterStats"))

local events = ReplicatedStorage:WaitForChild("Events")
local arenaEvent = events:WaitForChild("ArenaAction")
local matchResultEvent = events:WaitForChild("MatchResult")
local stateEvent = events:WaitForChild("StateUpdate")

local ARENA_FOLDER = "BoxingArena"
local PLAYER_CHARACTER_FOLDER = "PlayerCharacters"

local playerMatchData = {}

local function getMatchData(player)
	if not playerMatchData[player] then
		playerMatchData[player] = {
			character = nil,
			opponent = nil,
			inMatch = false,
			playerHealth = 100,
			opponentHealth = 100,
		}
	end
	return playerMatchData[player]
end

local function createFighterCharacter(name, spawnPosition, color)
	local character = Instance.new("Model")
	character.Name = name
	character.PrimaryPart = nil

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Shape = Enum.PartType.Cube
	torso.Size = Vector3.new(1, 1.5, 0.6)
	torso.Color = color
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = false
	torso.CFrame = spawnPosition + Vector3.new(0, 1, 0)
	torso.Parent = character

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.8, 0.8, 0.8)
	head.Color = color
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = torso.CFrame + Vector3.new(0, 1.2, 0)
	head.Parent = character

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Shape = Enum.PartType.Cube
	leftArm.Size = Vector3.new(0.4, 1.5, 0.4)
	leftArm.Color = color
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.CFrame = torso.CFrame + Vector3.new(-0.8, 0.2, 0)
	leftArm.Parent = character

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Shape = Enum.PartType.Cube
	rightArm.Size = Vector3.new(0.4, 1.5, 0.4)
	rightArm.Color = color
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.CFrame = torso.CFrame + Vector3.new(0.8, 0.2, 0)
	rightArm.Parent = character

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Shape = Enum.PartType.Cube
	leftLeg.Size = Vector3.new(0.4, 1.5, 0.4)
	leftLeg.Color = color
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.CFrame = torso.CFrame + Vector3.new(-0.3, -1.5, 0)
	leftLeg.Parent = character

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"
	rightLeg.Shape = Enum.PartType.Cube
	rightLeg.Size = Vector3.new(0.4, 1.5, 0.4)
	rightLeg.Color = color
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.CFrame = torso.CFrame + Vector3.new(0.3, -1.5, 0)
	rightLeg.Parent = character

	character.PrimaryPart = torso
	character:SetPrimaryPartCFrame(spawnPosition + Vector3.new(0, 1, 0))

	return character, torso, head, leftArm, rightArm, leftLeg, rightLeg
end

local function playPunchAnimation(torso, rightArm, duration)
	local startCFrame = rightArm.CFrame
	local punchCFrame = torso.CFrame + Vector3.new(2, 0.5, 0)

	for i = 1, 10 do
		rightArm.CFrame = startCFrame:Lerp(punchCFrame, i / 10)
		wait(duration / 10)
	end

	wait(0.1)

	for i = 1, 10 do
		rightArm.CFrame = punchCFrame:Lerp(startCFrame, i / 10)
		wait(duration / 10)
	end
end

local function playKickAnimation(torso, rightLeg, duration)
	local startCFrame = rightLeg.CFrame
	local kickCFrame = torso.CFrame + Vector3.new(1.5, -0.5, 0)

	for i = 1, 10 do
		rightLeg.CFrame = startCFrame:Lerp(kickCFrame, i / 10)
		wait(duration / 10)
	end

	wait(0.1)

	for i = 1, 10 do
		rightLeg.CFrame = kickCFrame:Lerp(startCFrame, i / 10)
		wait(duration / 10)
	end
end

local function playBlockAnimation(torso, leftArm, rightArm, duration)
	local leftArmStart = leftArm.CFrame
	local rightArmStart = rightArm.CFrame
	local blockPos = torso.CFrame + Vector3.new(0, 0.5, 0.5)

	for i = 1, 5 do
		leftArm.CFrame = leftArmStart:Lerp(blockPos, i / 5)
		rightArm.CFrame = rightArmStart:Lerp(blockPos, i / 5)
		wait(duration / 5)
	end

	wait(0.3)

	for i = 1, 5 do
		leftArm.CFrame = blockPos:Lerp(leftArmStart, i / 5)
		rightArm.CFrame = blockPos:Lerp(rightArmStart, i / 5)
		wait(duration / 5)
	end
end

local function playFrontFlipAnimation(torso, head, leftArm, rightArm, leftLeg, rightLeg)
	local startPos = torso.Position
	local flipEndPos = startPos + Vector3.new(2, 0, 0)
	local duration = 0.8

	-- Launch upward and forward
	for i = 1, 12 do
		local progress = i / 12
		local upwardBias = math.sin(progress * math.pi) * 1.5
		local newPos = startPos:Lerp(flipEndPos, progress) + Vector3.new(0, upwardBias, 0)
		torso.CFrame = CFrame.new(newPos) * CFrame.Angles(progress * math.pi * 2.5, 0, 0)
		head.CFrame = torso.CFrame + Vector3.new(0, 1.2, 0)
		leftLeg.CFrame = torso.CFrame + Vector3.new(-0.3, -1.5, 0) * CFrame.Angles(progress * math.pi * 2.5, 0, 0)
		rightLeg.CFrame = torso.CFrame + Vector3.new(0.3, -1.5, 0) * CFrame.Angles(progress * math.pi * 2.5, 0, 0)
		leftArm.CFrame = torso.CFrame + Vector3.new(-0.8, 0.2, 0) * CFrame.Angles(progress * math.pi * 2.5, 0, 0)
		rightArm.CFrame = torso.CFrame + Vector3.new(0.8, 0.2, 0) * CFrame.Angles(progress * math.pi * 2.5, 0, 0)
		wait(duration / 12)
	end

	-- Land on back (face up)
	wait(0.2)

	local backPos = flipEndPos + Vector3.new(0, 0, 0)
	torso.CFrame = CFrame.new(backPos) * CFrame.Angles(math.pi, 0, 0)
	head.CFrame = torso.CFrame + Vector3.new(0, 1.2, 0)
	leftArm.CFrame = torso.CFrame + Vector3.new(-0.8, 0.2, 0)
	rightArm.CFrame = torso.CFrame + Vector3.new(0.8, 0.2, 0)
	leftLeg.CFrame = torso.CFrame + Vector3.new(-0.3, -1.5, 0)
	rightLeg.CFrame = torso.CFrame + Vector3.new(0.3, -1.5, 0)

	-- Stay down for a moment
	wait(0.5)

	-- Get back up
	for i = 1, 8 do
		local progress = i / 8
		torso.CFrame = CFrame.new(backPos) * CFrame.Angles(math.pi * (1 - progress), 0, 0)
		head.CFrame = torso.CFrame + Vector3.new(0, 1.2, 0)
		leftArm.CFrame = torso.CFrame + Vector3.new(-0.8, 0.2, 0)
		rightArm.CFrame = torso.CFrame + Vector3.new(0.8, 0.2, 0)
		leftLeg.CFrame = torso.CFrame + Vector3.new(-0.3, -1.5, 0)
		rightLeg.CFrame = torso.CFrame + Vector3.new(0.3, -1.5, 0)
		wait(0.1)
	end
end

local function playKneeAnimation(torso, rightLeg, duration)
	local startCFrame = rightLeg.CFrame
	local kneeCFrame = torso.CFrame + Vector3.new(0.5, 0.5, 0)

	for i = 1, 8 do
		rightLeg.CFrame = startCFrame:Lerp(kneeCFrame, i / 8)
		wait(duration / 8)
	end

	wait(0.1)

	for i = 1, 8 do
		rightLeg.CFrame = kneeCFrame:Lerp(startCFrame, i / 8)
		wait(duration / 8)
	end
end

local function spawnArenaCharacters(player)
	local matchData = getMatchData(player)
	local arena = Workspace:FindFirstChild(ARENA_FOLDER)

	if not arena then
		warn("Arena not found!")
		return
	end

	local redSpawn = arena:FindFirstChild("RedSpawn")
	local blueSpawn = arena:FindFirstChild("BlueSpawn")

	if not redSpawn or not blueSpawn then
		warn("Spawn points not found!")
		return
	end

	-- Player character (red)
	local playerCharacter, playerTorso, playerHead, playerLeftArm, playerRightArm, playerLeftLeg, playerRightLeg =
		createFighterCharacter("PlayerFighter", redSpawn.Position, Color3.fromRGB(255, 100, 100))
	playerCharacter.Parent = arena

	-- Opponent character (blue)
	local opponentCharacter, opponentTorso, opponentHead, opponentLeftArm, opponentRightArm, opponentLeftLeg, opponentRightLeg =
		createFighterCharacter("OpponentFighter", blueSpawn.Position, Color3.fromRGB(100, 100, 255))
	opponentCharacter.Parent = arena

	matchData.character = playerCharacter
	matchData.opponent = opponentCharacter
	matchData.playerTorso = playerTorso
	matchData.playerHead = playerHead
	matchData.playerRightArm = playerRightArm
	matchData.playerRightLeg = playerRightLeg
	matchData.playerLeftArm = playerLeftArm
	matchData.playerLeftLeg = playerLeftLeg
	matchData.opponentTorso = opponentTorso
	matchData.opponentHead = opponentHead
	matchData.opponentRightArm = opponentRightArm
	matchData.opponentRightLeg = opponentRightLeg
	matchData.opponentLeftArm = opponentLeftArm
	matchData.opponentLeftLeg = opponentLeftLeg
	matchData.inMatch = true

	return playerCharacter, opponentCharacter
end

local function playAttackAnimation(player, actionType)
	local matchData = getMatchData(player)

	if not matchData.character or not matchData.opponent then
		return
	end

	if actionType == "punch" then
		playPunchAnimation(matchData.playerTorso, matchData.playerRightArm, 0.2)
		playPunchAnimation(matchData.opponentTorso, matchData.opponentRightArm, 0.15)
	elseif actionType == "kick" then
		playKickAnimation(matchData.playerTorso, matchData.playerRightLeg, 0.25)
		playFrontFlipAnimation(matchData.opponentTorso, matchData.opponentHead, matchData.opponentLeftArm, 
			matchData.opponentRightArm, matchData.opponentLeftLeg, matchData.opponentRightLeg)
	elseif actionType == "combo" then
		playPunchAnimation(matchData.playerTorso, matchData.playerRightArm, 0.15)
		wait(0.05)
		playPunchAnimation(matchData.playerTorso, matchData.playerLeftArm, 0.15)
		playPunchAnimation(matchData.opponentTorso, matchData.opponentRightArm, 0.15)
		wait(0.1)
		playPunchAnimation(matchData.opponentTorso, matchData.opponentLeftArm, 0.15)
	elseif actionType == "block" then
		playBlockAnimation(matchData.playerTorso, matchData.playerLeftArm, matchData.playerRightArm, 0.3)
	elseif actionType == "knee" then
		playKneeAnimation(matchData.playerTorso, matchData.playerRightLeg, 0.25)
		playFrontFlipAnimation(matchData.opponentTorso, matchData.opponentHead, matchData.opponentLeftArm, 
			matchData.opponentRightArm, matchData.opponentLeftLeg, matchData.opponentRightLeg)
	end
end

local function cleanupMatch(player)
	local matchData = getMatchData(player)

	if matchData.character then
		matchData.character:Destroy()
	end

	if matchData.opponent then
		matchData.opponent:Destroy()
	end

	matchData.inMatch = false
	matchData.character = nil
	matchData.opponent = nil
end

-- Arena action handler
arenaEvent.OnServerEvent:Connect(function(player, action)
	if action == "start_match" then
		spawnArenaCharacters(player)
		wait(3)
		matchResultEvent:FireClient(player, {
			type = "countdown",
			number = 3,
		})
		wait(1)
		matchResultEvent:FireClient(player, {
			type = "countdown",
			number = 2,
		})
		wait(1)
		matchResultEvent:FireClient(player, {
			type = "countdown",
			number = 1,
		})
		wait(1)
		matchResultEvent:FireClient(player, {
			type = "match_started",
			opponentName = "Bot Boxer",
			opponentHealth = 100,
		})
	elseif action == "punch" or action == "kick" or action == "combo" or action == "knee" then
		playAttackAnimation(player, action)
	elseif action == "block" then
		playAttackAnimation(player, action)
	elseif action == "go_home" then
		cleanupMatch(player)
		matchResultEvent:FireClient(player, {
			type = "go_home",
		})
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupMatch(player)
	playerMatchData[player] = nil
end)
