-- Makes every Magic Carpet (StoreService, tagged "MagicCarpet") wave in the air like it's blowing in the
-- wind: a ripple runs from the front of the carpet to the back, each cloth piece bobbing up and down and
-- tilting with the ripple, and the whole carpet sways a little side to side. Only moves things on this
-- screen; the carpet's pieces hang on Welds whose resting spot is saved as "BaseC0".

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WAVE_HEIGHT = 0.35 -- how far the cloth bobs up and down (studs)
local WAVE_SPEED = 5 -- how fast the ripple runs
local WAVE_LENGTH = 0.9 -- how tight the ripple is (bigger = more waves along the carpet)
local SWAY = math.rad(4) -- side to side sway

local carpets = {} -- [model] = { welds }

local function track(model)
	local welds = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Weld") and item:GetAttribute("BaseC0") then
			table.insert(welds, item)
		end
	end
	table.sort(welds, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	carpets[model] = welds
end

CollectionService:GetInstanceAddedSignal("MagicCarpet"):Connect(function(model)
	task.defer(track, model) -- let its pieces arrive first
end)
CollectionService:GetInstanceRemovedSignal("MagicCarpet"):Connect(function(model)
	carpets[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("MagicCarpet")) do
	track(model)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local sway = math.sin(t * 1.3) * SWAY
	for model, welds in pairs(carpets) do
		if not model.Parent then
			carpets[model] = nil
			continue
		end
		for i, weld in ipairs(welds) do
			local base = weld:GetAttribute("BaseC0")
			if base and weld.Parent then
				-- The ripple: higher toward the back, where the wind flaps it most
				local phase = t * WAVE_SPEED - i * WAVE_LENGTH
				local strength = 0.4 + 0.6 * (i / #welds)
				local lift = math.sin(phase) * WAVE_HEIGHT * strength
				local tilt = math.cos(phase) * WAVE_HEIGHT * strength * 0.8
				weld.C0 = base * CFrame.new(0, lift, 0) * CFrame.Angles(tilt, 0, sway)
			end
		end
	end
end)
