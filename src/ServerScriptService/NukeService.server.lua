-- Server nuke: the owner types /nuke (or presses SERVER NUKE in the VIP ADMIN panel). Everyone gets a
-- 10-second countdown with flashing red warnings, then a giant nuclear explosion goes off in the middle of the map:
-- everyone except the owner (and whoever launched it) dies and respawns, fires burn around the map for a little while, and then
-- everything goes back to normal. Right after the blast the sky turns Fiery for a minute (a sky event
-- whose Fiery skin, with a fiery aura, is sold in the Color Shop meanwhile). /nuke again during the
-- countdown calls it off. NukeClient draws it all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Admins = require(script.Parent:WaitForChild("Admins"))
local startSkyEvent = script.Parent:WaitForChild("SkyEventService"):WaitForChild("StartSkyEvent")

local COUNTDOWN = 10
local FIRE_SECONDS = 20 -- how long the fires burn after the blast

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = eventsFolder:WaitForChild("Announcement")

-- Server -> clients: ("countdown", seconds), ("cancel"), ("boom", fireSeconds)
local nukeEvent = Instance.new("RemoteEvent")
nukeEvent.Name = "Nuke"
nukeEvent.Parent = eventsFolder

local state = "idle" -- "idle", "countdown" or "boom"
local token = 0

local function blast(owner) -- owner: whoever launched it (the owner, or someone with the VIP ADMIN panel)
	state = "boom"
	local myToken = token
	nukeEvent:FireAllClients("boom", FIRE_SECONDS)
	-- The shockwave reaches everyone a moment after the flash
	task.wait(0.6)
	for _, player in ipairs(Players:GetPlayers()) do
		if not Admins.IsOwner(player) and player ~= owner then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	end
	announcementEvent:FireAllClients("☢️ " .. owner.DisplayName .. " NUKED THE SERVER!")
	-- The sky burns: a Fiery sky event for a minute, with the Fiery skin in the Color Shop
	task.delay(3, function()
		if token ~= myToken then
			return -- /none stopped everything
		end
		startSkyEvent:Invoke("fiery")
		announcementEvent:FireAllClients("🔥 FIERY SKY! Get the Fiery skin in the Color Shop for 1 minute!")
	end)
	task.wait(FIRE_SECONDS)
	if token == myToken then
		state = "idle"
	end
end

local function nuke(player)
	if not Admins.HasVipPanel(player) then
		return nil
	end
	if state == "countdown" then
		token += 1
		state = "idle"
		nukeEvent:FireAllClients("cancel")
		announcementEvent:FireAllClients("☢️ The nuke was called off.")
		return "Nuke called off."
	elseif state == "boom" then
		return "The last nuke is still burning. Wait a bit."
	end

	state = "countdown"
	token += 1
	local myToken = token
	nukeEvent:FireAllClients("countdown", COUNTDOWN)
	announcementEvent:FireAllClients("☢️ NUKE INCOMING! " .. COUNTDOWN .. " seconds!")
	task.spawn(function()
		task.wait(COUNTDOWN)
		if token == myToken and state == "countdown" then
			blast(player)
		end
	end)
	return "☢️ Nuke launched! " .. COUNTDOWN .. " seconds... press again to call it off."
end

-- /none (SkyEventService) stops everything: calls off a countdown, or clears the fire and smoke of a
-- nuke that already went off (the Fiery sky is cleared by /none itself)
local stopNuke = Instance.new("BindableFunction")
stopNuke.Name = "StopNuke"
stopNuke.Parent = script
stopNuke.OnInvoke = function()
	if state == "idle" then
		return false
	end
	token += 1
	nukeEvent:FireAllClients(state == "countdown" and "cancel" or "clear")
	state = "idle"
	return true
end

-- VIP ADMIN panel button
local adminNuke = Instance.new("RemoteFunction")
adminNuke.Name = "AdminNuke"
adminNuke.Parent = eventsFolder
adminNuke.OnServerInvoke = nuke

-- /nuke from the VIP ADMIN panel's COMMANDS tab
task.spawn(function()
	ServerStorage:WaitForChild("OtherChatCommand").Event:Connect(function(player, alias)
		if alias == "nuke" then
			nuke(player)
		end
	end)
end)

-- /nuke in chat (hidden from chat like every command, by ChatCommandFilter)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local command = Instance.new("TextChatCommand")
	command.Name = "NukeCommand"
	command.PrimaryAlias = "/nuke"
	command.Parent = TextChatService
	command.Triggered:Connect(function(textSource)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if player then
			nuke(player)
		end
	end)
else
	local function listen(player)
		player.Chatted:Connect(function(message)
			if string.match(string.lower(message), "^/nuke%f[%W]") then
				nuke(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in ipairs(Players:GetPlayers()) do
		listen(player)
	end
end
