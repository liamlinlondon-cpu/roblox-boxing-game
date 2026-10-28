-- Disco party: the owner types /disco (or presses Disco in the VIP ADMIN panel) and the sky turns into a
-- disco: night, a giant spinning disco ball high above the world, and colored lights sweeping left and
-- right over everything (the map, the buildings, the hill). /disco again turns it off. The server only
-- flips the "DiscoParty" attribute on ReplicatedStorage; DiscoClient builds and moves the lights.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Admins = require(script.Parent:WaitForChild("Admins"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = eventsFolder:WaitForChild("Announcement")

ReplicatedStorage:SetAttribute("DiscoParty", false)

local function toggleDisco(player)
	if not Admins.HasVipPanel(player) then
		return nil
	end
	local on = not ReplicatedStorage:GetAttribute("DiscoParty")
	-- When it started, for the Disco skin's short sale in the Color Shop (StoreService)
	ReplicatedStorage:SetAttribute("DiscoStartedAt", on and workspace:GetServerTimeNow() or nil)
	ReplicatedStorage:SetAttribute("DiscoParty", on)
	if on then
		announcementEvent:FireAllClients("🪩 " .. player.DisplayName .. " started a DISCO PARTY!")
		return "🪩 Disco party started! Press again (or type /disco) to stop it."
	end
	announcementEvent:FireAllClients("🪩 The disco party is over.")
	return "Disco party stopped."
end

-- VIP ADMIN panel button
local adminDisco = Instance.new("RemoteFunction")
adminDisco.Name = "AdminDisco"
adminDisco.Parent = eventsFolder
adminDisco.OnServerInvoke = toggleDisco

-- /disco from the VIP ADMIN panel's COMMANDS tab
task.spawn(function()
	game:GetService("ServerStorage"):WaitForChild("OtherChatCommand").Event:Connect(function(player, alias)
		if alias == "disco" then
			toggleDisco(player)
		end
	end)
end)

-- /disco in chat
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local command = Instance.new("TextChatCommand")
	command.Name = "DiscoCommand"
	command.PrimaryAlias = "/disco"
	command.Parent = TextChatService
	command.Triggered:Connect(function(textSource)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if player then
			toggleDisco(player)
		end
	end)
else
	local function listen(player)
		player.Chatted:Connect(function(message)
			if string.match(string.lower(message), "^/disco%f[%W]") then
				toggleDisco(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in ipairs(Players:GetPlayers()) do
		listen(player)
	end
end
