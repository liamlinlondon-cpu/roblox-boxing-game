local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("Events")
local flowEvent = events:WaitForChild("FlowAction")
local stateEvent = events:WaitForChild("StateUpdate")
local matchResultEvent = events:WaitForChild("MatchResult")
local shopActionEvent = events:WaitForChild("ShopAction")
local arenaEvent = events:WaitForChild("ArenaAction")

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameScreenGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ==================== HOME SCREEN ====================
local homeFrame = Instance.new("Frame")
homeFrame.Name = "HomeFrame"
homeFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
homeFrame.Position = UDim2.new(0.075, 0, 0.075, 0)
homeFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
homeFrame.BorderSizePixel = 2
homeFrame.BorderColor3 = Color3.fromRGB(255, 215, 0)
homeFrame.Parent = screenGui

local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0.12, 0)
homeTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
homeTitle.Text = "BOXING GAME"
homeTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
homeTitle.Font = Enum.Font.GothamBlack
homeTitle.TextScaled = true
homeTitle.Parent = homeFrame

local homeStatFrame = Instance.new("Frame")
homeStatFrame.Size = UDim2.new(0.9, 0, 0.3, 0)
homeStatFrame.Position = UDim2.new(0.05, 0, 0.18, 0)
homeStatFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
homeStatFrame.BorderSizePixel = 1
homeStatFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
homeStatFrame.Parent = homeFrame

local homeMoneyLabel = Instance.new("TextLabel")
homeMoneyLabel.Size = UDim2.new(1, 0, 0.2, 0)
homeMoneyLabel.BackgroundTransparency = 1
homeMoneyLabel.Text = "Robux: 0"
homeMoneyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
homeMoneyLabel.Font = Enum.Font.GothamBold
homeMoneyLabel.TextScaled = true
homeMoneyLabel.Parent = homeStatFrame

local homeStrengthLabel = Instance.new("TextLabel")
homeStrengthLabel.Size = UDim2.new(1, 0, 0.2, 0)
homeStrengthLabel.Position = UDim2.new(0, 0, 0.2, 0)
homeStrengthLabel.BackgroundTransparency = 1
homeStrengthLabel.Text = "Strength: 0"
homeStrengthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
homeStrengthLabel.Font = Enum.Font.GothamBold
homeStrengthLabel.TextScaled = true
homeStrengthLabel.Parent = homeStatFrame

local homeKickLabel = Instance.new("TextLabel")
homeKickLabel.Size = UDim2.new(1, 0, 0.2, 0)
homeKickLabel.Position = UDim2.new(0, 0, 0.4, 0)
homeKickLabel.BackgroundTransparency = 1
homeKickLabel.Text = "Kick: 0"
homeKickLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
homeKickLabel.Font = Enum.Font.GothamBold
homeKickLabel.TextScaled = true
homeKickLabel.Parent = homeStatFrame

local homeLuckLabel = Instance.new("TextLabel")
homeLuckLabel.Size = UDim2.new(1, 0, 0.2, 0)
homeLuckLabel.Position = UDim2.new(0, 0, 0.6, 0)
homeLuckLabel.BackgroundTransparency = 1
homeLuckLabel.Text = "Luck: 1"
homeLuckLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
homeLuckLabel.Font = Enum.Font.GothamBold
homeLuckLabel.TextScaled = true
homeLuckLabel.Parent = homeStatFrame

local homeStageLabel = Instance.new("TextLabel")
homeStageLabel.Size = UDim2.new(1, 0, 0.2, 0)
homeStageLabel.Position = UDim2.new(0, 0, 0.8, 0)
homeStageLabel.BackgroundTransparency = 1
homeStageLabel.Text = "Stage: Skinny Bones"
homeStageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
homeStageLabel.Font = Enum.Font.GothamBold
homeStageLabel.TextScaled = true
homeStageLabel.Parent = homeStatFrame

local function createMainButton(parent, name, text, position, callback)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.24, 0, 0.12, 0)
	btn.Position = position
	btn.Text = text
	btn.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BorderSizePixel = 2
	btn.BorderColor3 = Color3.fromRGB(255, 215, 0)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Parent = parent
	btn.MouseButton1Click:Connect(callback)
	return btn
end

createMainButton(homeFrame, "GymBtn", "GYM", UDim2.new(0.08, 0, 0.58, 0), function()
	flowEvent:FireServer("gym")
end)

createMainButton(homeFrame, "ShopBtn", "SHOP", UDim2.new(0.38, 0, 0.58, 0), function()
	flowEvent:FireServer("shop")
end)

createMainButton(homeFrame, "ArenaBtn", "ARENA", UDim2.new(0.68, 0, 0.58, 0), function()
	flowEvent:FireServer("arena")
end)

-- ==================== GYM SCREEN ====================
local gymFrame = Instance.new("Frame")
gymFrame.Name = "GymFrame"
gymFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
gymFrame.Position = UDim2.new(0.075, 0, 0.075, 0)
gymFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
gymFrame.BorderSizePixel = 2
gymFrame.BorderColor3 = Color3.fromRGB(255, 215, 0)
gymFrame.Visible = false
gymFrame.Parent = screenGui

local gymTitle = Instance.new("TextLabel")
gymTitle.Size = UDim2.new(1, 0, 0.12, 0)
gymTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
gymTitle.Text = "GYM - TRAIN YOUR STRENGTH"
gymTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
gymTitle.Font = Enum.Font.GothamBlack
gymTitle.TextScaled = true
gymTitle.Parent = gymFrame

local gymInfo = Instance.new("TextLabel")
gymInfo.Size = UDim2.new(0.9, 0, 0.25, 0)
gymInfo.Position = UDim2.new(0.05, 0, 0.18, 0)
gymInfo.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
gymInfo.Text = "Each training session adds +50 strength.\nYour health will be restored to 100.\nTrain hard and prepare for the arena!"
gymInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
gymInfo.Font = Enum.Font.GothamBold
gymInfo.TextScaled = true
gymInfo.TextWrapped = true
gymInfo.Parent = gymFrame

local gymTrainBtn = Instance.new("TextButton")
gymTrainBtn.Size = UDim2.new(0.45, 0, 0.15, 0)
gymTrainBtn.Position = UDim2.new(0.275, 0, 0.52, 0)
gymTrainBtn.Text = "TRAIN (+50 STR)"
gymTrainBtn.BackgroundColor3 = Color3.fromRGB(75, 110, 180)
gymTrainBtn.BorderSizePixel = 2
gymTrainBtn.BorderColor3 = Color3.fromRGB(255, 215, 0)
gymTrainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gymTrainBtn.Font = Enum.Font.GothamBlack
gymTrainBtn.TextScaled = true
gymTrainBtn.Parent = gymFrame
gymTrainBtn.MouseButton1Click:Connect(function()
	flowEvent:FireServer("gym")
end)

local gymBackBtn = Instance.new("TextButton")
gymBackBtn.Size = UDim2.new(0.45, 0, 0.15, 0)
gymBackBtn.Position = UDim2.new(0.275, 0, 0.72, 0)
gymBackBtn.Text = "BACK"
gymBackBtn.BackgroundColor3 = Color3.fromRGB(110, 70, 70)
gymBackBtn.BorderSizePixel = 2
gymBackBtn.BorderColor3 = Color3.fromRGB(255, 215, 0)
gymBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gymBackBtn.Font = Enum.Font.GothamBlack
gymBackBtn.TextScaled = true
gymBackBtn.Parent = gymFrame
gymBackBtn.MouseButton1Click:Connect(function()
	flowEvent:FireServer("home")
end)

-- ==================== SHOP SCREEN ====================
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
shopFrame.Position = UDim2.new(0.075, 0, 0.075, 0)
shopFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
shopFrame.BorderSizePixel = 2
shopFrame.BorderColor3 = Color3.fromRGB(255, 215, 0)
shopFrame.Visible = false
shopFrame.Parent = screenGui

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0.12, 0)
shopTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
shopTitle.Text = "SHOP"
shopTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.TextScaled = true
shopTitle.Parent = shopFrame

local shopStatus = Instance.new("TextLabel")
shopStatus.Size = UDim2.new(0.9, 0, 0.08, 0)
shopStatus.Position = UDim2.new(0.05, 0, 0.16, 0)
shopStatus.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
shopStatus.Text = "Buy upgrades to increase your power"
shopStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
shopStatus.Font = Enum.Font.GothamBold
shopStatus.TextScaled = true
shopStatus.Parent = shopFrame

local function createShopButton(name, text, position, action, arg)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.25, 0, 0.1, 0)
	btn.Position = position
	btn.BackgroundColor3 = Color3.fromRGB(75, 110, 180)
	btn.BorderSizePixel = 2
	btn.BorderColor3 = Color3.fromRGB(255, 215, 0)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Parent = shopFrame
	btn.MouseButton1Click:Connect(function()
		if arg then
			shopActionEvent:FireServer(action, arg)
		else
			shopActionEvent:FireServer(action)
		end
	end)
	return btn
end

createShopButton("StrBtn", "2x Strength\n213 Robux", UDim2.new(0.08, 0, 0.3, 0), "buy_strength")
createShopButton("KickBtn", "3x Kick\n299 Robux", UDim2.new(0.38, 0, 0.3, 0), "buy_kick")
createShopButton("LuckBtn", "Luck +1", UDim2.new(0.68, 0, 0.3, 0), "buy_luck")

createShopButton("RedSkinBtn", "Red Skin\n75 Robux", UDim2.new(0.08, 0, 0.48, 0), "buy_skin", "red")
createShopButton("BlueSkinBtn", "Blue Skin\n75 Robux", UDim2.new(0.38, 0, 0.48, 0), "buy_skin", "blue")
createShopButton("YellowSkinBtn", "Yellow Skin\n75 Robux", UDim2.new(0.68, 0, 0.48, 0), "buy_skin", "yellow")

local shopBackBtn = Instance.new("TextButton")
shopBackBtn.Size = UDim2.new(0.25, 0, 0.1, 0)
shopBackBtn.Position = UDim2.new(0.375, 0, 0.67, 0)
shopBackBtn.Text = "BACK"
shopBackBtn.BackgroundColor3 = Color3.fromRGB(110, 70, 70)
shopBackBtn.BorderSizePixel = 2
shopBackBtn.BorderColor3 = Color3.fromRGB(255, 215, 0)
shopBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
shopBackBtn.Font = Enum.Font.GothamBlack
shopBackBtn.TextScaled = true
shopBackBtn.Parent = shopFrame
shopBackBtn.MouseButton1Click:Connect(function()
	flowEvent:FireServer("home")
end)

-- ==================== ARENA SCREEN ====================
local arenaFrame = Instance.new("Frame")
arenaFrame.Name = "ArenaFrame"
arenaFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
arenaFrame.Position = UDim2.new(0.075, 0, 0.075, 0)
arenaFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
arenaFrame.BorderSizePixel = 2
arenaFrame.BorderColor3 = Color3.fromRGB(255, 215, 0)
arenaFrame.Visible = false
arenaFrame.Parent = screenGui

local arenaTitle = Instance.new("TextLabel")
arenaTitle.Size = UDim2.new(1, 0, 0.12, 0)
arenaTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
arenaTitle.Text = "BOXING ARENA"
arenaTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
arenaTitle.Font = Enum.Font.GothamBlack
arenaTitle.TextScaled = true
arenaTitle.Parent = arenaFrame

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(0.3, 0, 0.2, 0)
countdownLabel.Position = UDim2.new(0.35, 0, 0.4, 0)
countdownLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
countdownLabel.BackgroundTransparency = 0.35
countdownLabel.Text = "3"
countdownLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextScaled = true
countdownLabel.Visible = false
countdownLabel.Parent = arenaFrame

local arenaYourHealth = Instance.new("TextLabel")
arenaYourHealth.Size = UDim2.new(0.35, 0, 0.08, 0)
arenaYourHealth.Position = UDim2.new(0.08, 0, 0.18, 0)
arenaYourHealth.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
arenaYourHealth.Text = "Your Health: 100"
arenaYourHealth.TextColor3 = Color3.fromRGB(0, 255, 0)
arenaYourHealth.Font = Enum.Font.GothamBold
arenaYourHealth.TextScaled = true
arenaYourHealth.Parent = arenaFrame

local arenaEnemyHealth = Instance.new("TextLabel")
arenaEnemyHealth.Size = UDim2.new(0.35, 0, 0.08, 0)
arenaEnemyHealth.Position = UDim2.new(0.57, 0, 0.18, 0)
arenaEnemyHealth.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
arenaEnemyHealth.Text = "Opponent: 100"
arenaEnemyHealth.TextColor3 = Color3.fromRGB(255, 0, 0)
arenaEnemyHealth.Font = Enum.Font.GothamBold
arenaEnemyHealth.TextScaled = true
arenaEnemyHealth.Parent = arenaFrame

local arenaMessage = Instance.new("TextLabel")
arenaMessage.Size = UDim2.new(0.9, 0, 0.1, 0)
arenaMessage.Position = UDim2.new(0.05, 0, 0.28, 0)
arenaMessage.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
arenaMessage.Text = "Match starting..."
arenaMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
arenaMessage.Font = Enum.Font.GothamBold
arenaMessage.TextScaled = true
arenaMessage.Parent = arenaFrame

local function createArenaButton(name, text, position, action)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.17, 0, 0.09, 0)
	btn.Position = position
	btn.BackgroundColor3 = Color3.fromRGB(75, 110, 180)
	btn.BorderSizePixel = 2
	btn.BorderColor3 = Color3.fromRGB(255, 215, 0)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Parent = arenaFrame
	btn.MouseButton1Click:Connect(function()
		arenaEvent:FireServer(action)
	end)
	return btn
end

createArenaButton("PunchBtn", "PUNCH", UDim2.new(0.08, 0, 0.45, 0), "punch")
createArenaButton("KickBtn", "KICK", UDim2.new(0.28, 0, 0.45, 0), "kick")
createArenaButton("ComboBtn", "COMBO", UDim2.new(0.48, 0, 0.45, 0), "combo")
createArenaButton("BlockBtn", "BLOCK", UDim2.new(0.68, 0, 0.45, 0), "block")

createArenaButton("KneeBtn", "KNEE", UDim2.new(0.18, 0, 0.58, 0), "knee")
createArenaButton("HomeBtn", "HOME", UDim2.new(0.55, 0, 0.58, 0), "go_home")

-- ==================== RESULT SCREEN ====================
local resultFrame = Instance.new("Frame")
resultFrame.Name = "ResultFrame"
resultFrame.Size = UDim2.new(0.6, 0, 0.4, 0)
resultFrame.Position = UDim2.new(0.2, 0, 0.3, 0)
resultFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
resultFrame.Visible = false
resultFrame.Parent = screenGui

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, 0, 0.5, 0)
resultLabel.Text = ""
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.TextScaled = true
resultLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
resultLabel.Parent = resultFrame

local rewardLabel = Instance.new("TextLabel")
rewardLabel.Size = UDim2.new(1, 0, 0.25, 0)
rewardLabel.Position = UDim2.new(0, 0, 0.5, 0)
rewardLabel.Text = ""
rewardLabel.Font = Enum.Font.Gotham
rewardLabel.TextScaled = true
rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
rewardLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
rewardLabel.Parent = resultFrame

local continueBtn = Instance.new("TextButton")
continueBtn.Size = UDim2.new(0.6, 0, 0.2, 0)
continueBtn.Position = UDim2.new(0.2, 0, 0.75, 0)
continueBtn.Text = "CONTINUE"
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextScaled = true
continueBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
continueBtn.Parent = resultFrame
continueBtn.MouseButton1Click:Connect(function()
	resultFrame.Visible = false
	flowEvent:FireServer("home")
end)

-- ==================== STATE MANAGEMENT ====================
local currentLocation = "home"

local function setScreen(location)
	currentLocation = location
	homeFrame.Visible = (location == "home")
	gymFrame.Visible = (location == "gym")
	shopFrame.Visible = (location == "shop")
	arenaFrame.Visible = (location == "arena")
end

-- Listen for server state updates
stateEvent.OnClientEvent:Connect(function(data)
	if data.type == "location" then
		setScreen(data.location)
	end
end)

-- Listen for match events
matchResultEvent.OnClientEvent:Connect(function(data)
	if data.type == "stats" then
		homeMoneyLabel.Text = "Robux: " .. tostring(data.money)
		homeStrengthLabel.Text = "Strength: " .. tostring(data.strength)
		homeKickLabel.Text = "Kick: " .. tostring(data.kick)
		homeLuckLabel.Text = "Luck: " .. tostring(data.luck)
		homeStageLabel.Text = "Stage: " .. tostring(data.bodyStage)
	elseif data.type == "shop_result" then
		shopStatus.Text = data.message
		shopStatus.TextColor3 = data.success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
	elseif data.type == "countdown" then
		countdownLabel.Visible = true
		countdownLabel.Text = tostring(data.number)
	elseif data.type == "match_started" then
		countdownLabel.Visible = false
		arenaMessage.Text = "Fight: " .. data.opponentName
		arenaYourHealth.Text = "Your Health: 100"
		arenaEnemyHealth.Text = "Opponent: " .. tostring(data.opponentHealth)
	elseif data.type == "fight_update" then
		arenaYourHealth.Text = "Your Health: " .. tostring(data.playerHealth)
		arenaEnemyHealth.Text = "Opponent: " .. tostring(data.opponentHealth)
		arenaMessage.Text = "Hit for " .. tostring(math.floor(data.damageDealt)) .. " dmg. Took " .. tostring(math.floor(data.damageTaken)) .. "."
	elseif data.type == "win" then
		resultFrame.Visible = true
		resultLabel.Text = "YOU WIN!"
		resultLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		rewardLabel.Text = "Reward: +" .. tostring(data.moneyAward) .. " Robux"
	elseif data.type == "lose" then
		resultFrame.Visible = true
		resultLabel.Text = "YOU LOST!"
		resultLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
		rewardLabel.Text = "Try again next time!"
	elseif data.type == "block" then
		arenaMessage.Text = data.message
	elseif data.type == "go_home" then
		resultFrame.Visible = false
	end
end)

-- Start at home
setScreen("home")
