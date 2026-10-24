-- Luck badge in the bottom-right corner, shown from 2x luck. Its look gets fancier with each luck level:
--   2x bronze, 4x silver, 8x gold, 16x glittery bronze, 32x glittery silver, 64x glittery gold,
--   max luck (99) rainbow, 2x max luck (200) glittery rainbow.
-- "Glittery" = a shine sweeping across the badge plus little sparkles. Updated from the stats messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Catalog"))
local matchResultEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MatchResult")
local flowEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FlowAction")

local player = Players.LocalPlayer

-- Highest first; a luck value uses the first tier it reaches
local TIERS = {
	{ min = Catalog.VipMaxLuck, style = "rainbow", glitter = true, caption = "2x MAX LUCK" },
	{ min = Catalog.MaxLuck, style = "rainbow", caption = "MAX LUCK" },
	{ min = 64, style = "gold", glitter = true },
	{ min = 32, style = "silver", glitter = true },
	{ min = 16, style = "bronze", glitter = true },
	{ min = 8, style = "gold" },
	{ min = 4, style = "silver" },
	{ min = 2, style = "bronze" },
}

-- dark, base, highlight
local METALS = {
	bronze = { Color3.fromRGB(120, 66, 24), Color3.fromRGB(205, 127, 50), Color3.fromRGB(255, 205, 150) },
	silver = { Color3.fromRGB(110, 110, 122), Color3.fromRGB(192, 192, 200), Color3.fromRGB(255, 255, 255) },
	gold = { Color3.fromRGB(170, 110, 5), Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 248, 180) },
}

local function metalSequence(metal)
	local dark, base, light = metal[1], metal[2], metal[3]
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.35, base),
		ColorSequenceKeypoint.new(0.5, light),
		ColorSequenceKeypoint.new(0.65, base),
		ColorSequenceKeypoint.new(1, dark),
	})
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 150, 30)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 210, 80)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(50, 120, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(160, 70, 230)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
})

-- ==================== BADGE ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LuckBadgeGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local badge = Instance.new("Frame")
badge.Name = "LuckBadge"
badge.AnchorPoint = Vector2.new(1, 1)
badge.Size = UDim2.new(0, 130, 0, 64)
badge.Position = UDim2.new(1, -16, 1, -16)
badge.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
badge.BackgroundTransparency = 0.15
badge.Visible = false
badge.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = badge

local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Parent = badge

local amountLabel = Instance.new("TextLabel")
amountLabel.Size = UDim2.new(1, -12, 0.62, 0)
amountLabel.Position = UDim2.new(0, 6, 0, 4)
amountLabel.BackgroundTransparency = 1
amountLabel.TextColor3 = Color3.new(1, 1, 1)
amountLabel.Font = Enum.Font.GothamBlack
amountLabel.TextScaled = true
amountLabel.Parent = badge

local textGradient = Instance.new("UIGradient")
textGradient.Parent = amountLabel

local captionLabel = Instance.new("TextLabel")
captionLabel.Size = UDim2.new(1, -12, 0.26, 0)
captionLabel.Position = UDim2.new(0, 6, 0.68, 0)
captionLabel.BackgroundTransparency = 1
captionLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
captionLabel.Font = Enum.Font.GothamBold
captionLabel.TextScaled = true
captionLabel.Parent = badge

local currentTier = nil

local function tierFor(luck)
	for _, tier in ipairs(TIERS) do
		if luck >= tier.min then
			return tier
		end
	end
	return nil
end

local function setLuck(luck)
	local tier = tierFor(luck)
	currentTier = tier
	badge.Visible = tier ~= nil
	if not tier then
		return
	end
	amountLabel.Text = (luck == math.huge and "∞" or Catalog.FormatNumber(luck)) .. "x"
	captionLabel.Text = tier.caption or "LUCK"
	if tier.style == "rainbow" then
		textGradient.Color = RAINBOW
	else
		local metal = METALS[tier.style]
		textGradient.Color = metalSequence(metal)
		stroke.Color = metal[2]
	end
	textGradient.Offset = Vector2.zero
	textGradient.Rotation = 0
end

-- ==================== ANIMATION ====================
-- Glitter sweeps the shine across the text; rainbow tiers slide the colors and cycle the border.
RunService.RenderStepped:Connect(function()
	local tier = currentTier
	if not tier or not badge.Visible then
		return
	end
	local t = os.clock()
	if tier.style == "rainbow" then
		local speed = tier.glitter and 0.9 or 0.35
		textGradient.Offset = Vector2.new((t * speed) % 2 - 1, 0)
		stroke.Color = Color3.fromHSV((t * speed * 0.5) % 1, 0.8, 1)
	elseif tier.glitter then
		textGradient.Offset = Vector2.new((t * 0.8) % 2.4 - 1.2, 0)
	end
end)

-- Sparkles pop up around glittery badges
local function sparkle()
	local star = Instance.new("TextLabel")
	star.BackgroundTransparency = 1
	star.Text = "✦"
	star.Font = Enum.Font.GothamBold
	star.TextScaled = true
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Size = UDim2.new(0, 6, 0, 6)
	star.Position = UDim2.new(math.random(), 0, math.random(), 0)
	star.ZIndex = 3
	if currentTier.style == "rainbow" then
		star.TextColor3 = Color3.fromHSV(math.random(), 0.7, 1)
	else
		star.TextColor3 = METALS[currentTier.style][3]
	end
	star.Parent = badge

	local grow = TweenService:Create(star, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 16, 0, 16),
		Rotation = 45,
	})
	grow:Play()
	grow.Completed:Once(function()
		local fade = TweenService:Create(star, TweenInfo.new(0.4), { TextTransparency = 1, Size = UDim2.new(0, 6, 0, 6) })
		fade:Play()
		fade.Completed:Once(function()
			star:Destroy()
		end)
	end)
end

task.spawn(function()
	while true do
		task.wait(0.22)
		if currentTier and currentTier.glitter and badge.Visible then
			sparkle()
		end
	end
end)

matchResultEvent.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.type == "stats" and type(data.luck) == "number" then
		setLuck(data.luck)
	end
end)

-- The first stats message can arrive before this script connects, so ask for a fresh copy
flowEvent:FireServer("request_stats")
