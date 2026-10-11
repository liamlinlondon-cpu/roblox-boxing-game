-- VIP bidding panel. Opens from a gym's VIP board or elevator pad; all rules are enforced by VipAuctionService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldConfig"))
local auctionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("VipAuction")

local player = Players.LocalPlayer
local VIP = WorldConfig.Vip

local GOLD = Color3.fromRGB(255, 215, 0)
local BUTTON_COLOR = Color3.fromRGB(75, 110, 180)

local latestState = nil
local openGymId = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VipAuctionGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, size, position, textColor, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.Font = font or Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function makeButton(parent, size, position, text, color)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color or BUTTON_COLOR
	button.BorderSizePixel = 2
	button.BorderColor3 = GOLD
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = parent
	return button
end

-- ==================== PANEL ====================
local panel = Instance.new("Frame")
panel.Name = "VipPanel"
panel.Size = UDim2.new(0.44, 0, 0.66, 0)
panel.Position = UDim2.new(0.28, 0, 0.17, 0)
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
panel.BorderSizePixel = 2
panel.BorderColor3 = GOLD
panel.Visible = false
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 380)
sizeConstraint.Parent = panel

local title = makeLabel(panel, UDim2.new(0.8, 0, 0.09, 0), UDim2.new(0.04, 0, 0.02, 0), GOLD, Enum.Font.GothamBlack)
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = makeButton(panel, UDim2.new(0.1, 0, 0.08, 0), UDim2.new(0.88, 0, 0.02, 0), "X", Color3.fromRGB(150, 40, 40))
closeButton.Activated:Connect(function()
	panel.Visible = false
	openGymId = nil
end)

local infoLabel = makeLabel(panel, UDim2.new(0.92, 0, 0.06, 0), UDim2.new(0.04, 0, 0.12, 0))
local statusLabel = makeLabel(panel, UDim2.new(0.92, 0, 0.1, 0), UDim2.new(0.04, 0, 0.19, 0), Color3.fromRGB(120, 255, 140))
statusLabel.TextWrapped = true

local tierRow = Instance.new("Frame")
tierRow.Size = UDim2.new(0.92, 0, 0.09, 0)
tierRow.Position = UDim2.new(0.04, 0, 0.31, 0)
tierRow.BackgroundTransparency = 1
tierRow.Parent = panel

local tierLayout = Instance.new("UIListLayout")
tierLayout.FillDirection = Enum.FillDirection.Horizontal
tierLayout.Padding = UDim.new(0.02, 0)
tierLayout.Parent = tierRow

local tierButtons = {}
local tierWidth = (1 - 0.02 * (#VIP.Tiers - 1)) / #VIP.Tiers
for index, tier in ipairs(VIP.Tiers) do
	local button = makeButton(tierRow, UDim2.new(tierWidth, 0, 1, 0), UDim2.new(), "Bid " .. tier.robux .. " R$")
	button.LayoutOrder = index
	button.Activated:Connect(function()
		if openGymId then
			auctionEvent:FireServer("bid", openGymId, index)
		end
	end)
	tierButtons[index] = button
end

local cancelButton = makeButton(panel, UDim2.new(0.44, 0, 0.07, 0), UDim2.new(0.04, 0, 0.42, 0), "Cancel my bid", Color3.fromRGB(90, 90, 90))
cancelButton.Activated:Connect(function()
	auctionEvent:FireServer("cancel")
end)

local buyOpenButton = makeButton(panel, UDim2.new(0.44, 0, 0.07, 0), UDim2.new(0.52, 0, 0.42, 0), "", Color3.fromRGB(40, 140, 70))
buyOpenButton.Activated:Connect(function()
	if openGymId then
		auctionEvent:FireServer("buyOpenSlot", openGymId)
	end
end)

local bidsTitle = makeLabel(panel, UDim2.new(0.92, 0, 0.05, 0), UDim2.new(0.04, 0, 0.51, 0), GOLD)
bidsTitle.TextXAlignment = Enum.TextXAlignment.Left
bidsTitle.Text = "Bids for next session"

local bidsLabel = makeLabel(panel, UDim2.new(0.92, 0, 0.28, 0), UDim2.new(0.04, 0, 0.57, 0))
bidsLabel.TextScaled = false
bidsLabel.TextSize = 16
bidsLabel.TextXAlignment = Enum.TextXAlignment.Left
bidsLabel.TextYAlignment = Enum.TextYAlignment.Top
bidsLabel.Font = Enum.Font.Gotham

local noteLabel = makeLabel(panel, UDim2.new(0.92, 0, 0.08, 0), UDim2.new(0.04, 0, 0.89, 0), Color3.fromRGB(180, 180, 180), Enum.Font.Gotham)
noteLabel.TextWrapped = true
noteLabel.Text = string.format(
	"Top %d bids win the VIP floor for the next %d minutes. You only pay if you win. One bid at a time across all gyms.",
	VIP.SlotsPerGym,
	VIP.SessionSeconds // 60
)

-- ==================== TOAST ====================
local toast = makeLabel(screenGui, UDim2.new(0.5, 0, 0.05, 0), UDim2.new(0.25, 0, 0.02, 0))
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.Visible = false
local toastId = 0

local function showToast(text)
	toastId += 1
	local myId = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(5, function()
		if toastId == myId then
			toast.Visible = false
		end
	end)
end

-- ==================== REFRESH ====================
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function findMyBid()
	for gymId, gym in ipairs(latestState.gyms) do
		for rank, bid in ipairs(gym.bids) do
			if bid.userId == player.UserId then
				return gymId, rank, bid
			end
		end
	end
	return nil
end

local function refresh()
	if not latestState or not openGymId then
		return
	end
	local gym = latestState.gyms[openGymId]
	if not gym then
		return
	end

	title.Text = gym.name .. " · VIP Floor"
	infoLabel.Text = string.format(
		"Session ends in %s   ·   VIP slots used %d/%d",
		formatTime(latestState.sessionEndsAt - Workspace:GetServerTimeNow()),
		gym.vipCount,
		latestState.slots
	)

	local lines = {}
	if table.find(gym.vipUserIds, player.UserId) then
		table.insert(lines, "You are VIP here this session.")
	elseif table.find(gym.offerUserIds, player.UserId) then
		table.insert(lines, "You won a slot! Complete the purchase prompt.")
	end

	local bidGymId, bidRank, myBid = findMyBid()
	if not myBid then
		table.insert(lines, "No bid placed for next session.")
	elseif bidGymId == openGymId then
		local winning = bidRank <= latestState.slots and "winning" or "outbid"
		table.insert(lines, string.format("Your bid: %d R$ (rank #%d, %s)", myBid.robux, bidRank, winning))
	else
		table.insert(lines, string.format("Your bid is at %s. Bidding here moves it.", latestState.gyms[bidGymId].name))
	end
	statusLabel.Text = table.concat(lines, "\n")

	for index, button in ipairs(tierButtons) do
		local isMine = myBid and bidGymId == openGymId and myBid.tier == index
		button.BackgroundColor3 = isMine and Color3.fromRGB(190, 150, 20) or BUTTON_COLOR
	end
	cancelButton.Visible = myBid ~= nil

	buyOpenButton.Visible = gym.openSlots > 0
		and not table.find(gym.vipUserIds, player.UserId)
		and not table.find(gym.offerUserIds, player.UserId)
	buyOpenButton.Text = string.format("Join now · %d R$ (%d open)", VIP.Tiers[1].robux, gym.openSlots)

	local bidLines = {}
	for rank, bid in ipairs(gym.bids) do
		if rank > 10 then
			table.insert(bidLines, string.format("...and %d more", #gym.bids - 10))
			break
		end
		local marker = rank <= latestState.slots and "★" or "  "
		table.insert(bidLines, string.format("%s %d. %s: %d R$", marker, rank, bid.name, bid.robux))
	end
	bidsLabel.Text = #bidLines > 0 and table.concat(bidLines, "\n") or "No bids yet. Be the first!"
end

auctionEvent.OnClientEvent:Connect(function(kind, ...)
	if kind == "state" then
		latestState = ...
		refresh()
	elseif kind == "open" then
		local gymId, state = ...
		openGymId = gymId
		latestState = state or latestState
		panel.Visible = true
		refresh()
	elseif kind == "notice" then
		showToast(...)
	end
end)

auctionEvent:FireServer("requestState")

-- Keep the countdown ticking while the panel is open
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then
			refresh()
		end
	end
end)
