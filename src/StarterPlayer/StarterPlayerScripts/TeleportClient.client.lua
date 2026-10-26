-- Teleporting for players whose rebirth speed went past the speed cap (and the owner): press T to jump
-- to wherever the mouse points. RebirthService decides who may and where (inside the map only, except
-- for the owner). A small hint shows once it's unlocked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local events = ReplicatedStorage:WaitForChild("Events")
local teleportFunction = events:WaitForChild("Teleport")
local matchResultEvent = events:WaitForChild("MatchResult")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Size = UDim2.new(0, 330, 0, 28)
hint.Position = UDim2.new(0.5, 0, 1, -8)
hint.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
hint.BackgroundTransparency = 0.3
hint.TextColor3 = Color3.fromRGB(150, 220, 255)
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.Text = "⚡ Press T to teleport to your mouse"
hint.Visible = false
hint.Parent = screenGui

local unlocked = false
local messageToken = 0

local function checkUnlocked()
	local ok, allowed = pcall(teleportFunction.InvokeServer, teleportFunction)
	unlocked = ok and allowed == true
	hint.Visible = unlocked
end

local function showMessage(text)
	messageToken += 1
	local token = messageToken
	hint.Text = text
	task.delay(2.5, function()
		if messageToken == token then
			hint.Text = "⚡ Press T to teleport to your mouse"
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not unlocked or input.KeyCode ~= Enum.KeyCode.T then
		return
	end
	if not mouse.Target then
		showMessage("Point at the ground to teleport.")
		return
	end
	local ok, allowed, message = pcall(teleportFunction.InvokeServer, teleportFunction, mouse.Hit.Position)
	if ok and not allowed and message then
		showMessage(message)
	end
end)

-- Rebirths change who may teleport, and they always come with a stats update. Stats arrive many times a
-- second while training, so ask the server at most every 2 seconds.
local lastCheck = 0
checkUnlocked()
matchResultEvent.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.type == "stats" and os.clock() - lastCheck > 2 then
		lastCheck = os.clock()
		checkUnlocked()
	end
end)
