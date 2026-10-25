-- The owner's stat search box in the bottom-left corner. Type "Bob strength" (or "/Bob strength") and
-- press Enter to see that player's strength next to the box; kick, money and stamina work the same,
-- and just a name shows everything. The box only appears for the owner, and the server
-- (AdminCommandService) checks again on every search.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lookupFunction = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AdminLookup")

local player = Players.LocalPlayer

-- Ask the server whether this is the owner; everyone else never gets the box
local ok, isOwner = pcall(lookupFunction.InvokeServer, lookupFunction)
if not ok or isOwner ~= true then
	return
end

local GOLD = Color3.fromRGB(255, 215, 0)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminLookupGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local searchBox = Instance.new("TextBox")
searchBox.Name = "StatSearch"
searchBox.AnchorPoint = Vector2.new(0, 1)
searchBox.Size = UDim2.new(0, 290, 0, 32)
searchBox.Position = UDim2.new(0, 16, 1, -16)
searchBox.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
searchBox.BackgroundTransparency = 0.15
searchBox.BorderSizePixel = 2
searchBox.BorderColor3 = GOLD
searchBox.ClearTextOnFocus = false
searchBox.PlaceholderText = "Name above head + stat (e.g. Bob strength)"
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.GothamBold
searchBox.TextSize = 14
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.Parent = screenGui

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.Parent = searchBox

-- The answer appears to the right of the box
local result = Instance.new("TextLabel")
result.Name = "StatResult"
result.AnchorPoint = Vector2.new(0, 1)
result.AutomaticSize = Enum.AutomaticSize.XY
result.Size = UDim2.new(0, 0, 0, 32)
result.Position = UDim2.new(0, 316, 1, -16)
result.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
result.BackgroundTransparency = 0.15
result.BorderSizePixel = 2
result.BorderColor3 = GOLD
result.TextColor3 = GOLD
result.Font = Enum.Font.GothamBold
result.TextSize = 14
result.TextXAlignment = Enum.TextXAlignment.Left
result.Visible = false
result.Parent = screenGui

local resultPadding = Instance.new("UIPadding")
resultPadding.PaddingLeft = UDim.new(0, 8)
resultPadding.PaddingRight = UDim.new(0, 8)
resultPadding.PaddingTop = UDim.new(0, 8)
resultPadding.PaddingBottom = UDim.new(0, 8)
resultPadding.Parent = result

searchBox.FocusLost:Connect(function(enterPressed)
	if not enterPressed or searchBox.Text == "" then
		return
	end
	local answered, answer = pcall(lookupFunction.InvokeServer, lookupFunction, searchBox.Text)
	result.Text = answered and type(answer) == "string" and answer or "Search failed. Try again."
	result.Visible = true
end)
