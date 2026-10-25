-- The "YOU BEAT THE GAME!" screen: the screen fades to black, the words appear in red and red confetti
-- falls all around. Shown when the player steps into the red pad on the finish hill (BeatGameService).
-- The blue and yellow pads only show a short "Not this one!" message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local beatGameEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("BeatGame")

local player = Players.LocalPlayer

local SHOW_SECONDS = 8
local CONFETTI_SECONDS = 6

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BeatGameGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true -- cover the whole screen, top bar included
screenGui.DisplayOrder = 100
screenGui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("TextButton") -- a button so a click closes it early
overlay.Name = "Victory"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.AutoButtonColor = false
overlay.Text = ""
overlay.ClipsDescendants = true
overlay.Visible = false
overlay.Parent = screenGui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Size = UDim2.fromScale(0.8, 0.2)
title.Position = UDim2.fromScale(0.5, 0.45)
title.BackgroundTransparency = 1
title.Text = "YOU BEAT THE GAME!"
title.TextColor3 = Color3.fromRGB(255, 30, 30)
title.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.ZIndex = 3
title.Parent = overlay

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Size = UDim2.fromScale(0.6, 0.05)
subtitle.Position = UDim2.fromScale(0.5, 0.57)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Click anywhere to continue"
subtitle.TextColor3 = Color3.fromRGB(200, 60, 60)
subtitle.Font = Enum.Font.GothamBold
subtitle.TextScaled = true
subtitle.ZIndex = 3
subtitle.Parent = overlay

-- Short message for the wrong pads
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.new(0, 320, 0, 40)
toast.Position = UDim2.new(0.5, 0, 0, 150)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.Text = "Not this one! Try another pad."
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = screenGui

local showToken = 0

local function spawnConfetti()
	local piece = Instance.new("Frame")
	piece.BorderSizePixel = 0
	piece.Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 18))
	piece.BackgroundColor3 = Color3.fromRGB(math.random(200, 255), math.random(0, 60), math.random(0, 60))
	local startX = math.random()
	piece.Position = UDim2.fromScale(startX, -0.05)
	piece.Rotation = math.random(0, 360)
	piece.ZIndex = 2
	piece.Parent = overlay

	local fallTime = 2.5 + math.random() * 2
	local fall = TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Linear), {
		Position = UDim2.fromScale(startX + (math.random() - 0.5) * 0.2, 1.05),
		Rotation = piece.Rotation + math.random(180, 720),
	})
	fall:Play()
	fall.Completed:Once(function()
		piece:Destroy()
	end)
end

local function hideVictory()
	showToken += 1
	local fade = TweenInfo.new(0.6)
	TweenService:Create(overlay, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(subtitle, fade, { TextTransparency = 1 }):Play()
	task.delay(0.6, function()
		if not overlay:GetAttribute("Showing") then
			overlay.Visible = false
		end
	end)
	overlay:SetAttribute("Showing", false)
end

local function showVictory()
	showToken += 1
	local token = showToken
	overlay:SetAttribute("Showing", true)
	overlay.Visible = true
	title.TextTransparency = 1
	title.TextStrokeTransparency = 1
	subtitle.TextTransparency = 1

	local fade = TweenInfo.new(0.8)
	TweenService:Create(overlay, fade, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(title, fade, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	TweenService:Create(subtitle, fade, { TextTransparency = 0 }):Play()

	-- Red confetti raining down all around the words
	task.spawn(function()
		local stopAt = os.clock() + CONFETTI_SECONDS
		while os.clock() < stopAt and showToken == token do
			for _ = 1, 4 do
				spawnConfetti()
			end
			task.wait(0.08)
		end
	end)

	task.delay(SHOW_SECONDS, function()
		if showToken == token then
			hideVictory()
		end
	end)
end

overlay.Activated:Connect(hideVictory)

beatGameEvent.OnClientEvent:Connect(function(kind)
	if kind == "won" then
		showVictory()
	elseif kind == "wrong" then
		toast.Visible = true
		task.delay(2.5, function()
			toast.Visible = false
		end)
	end
end)
