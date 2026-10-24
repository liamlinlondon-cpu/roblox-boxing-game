-- Keeps chat commands out of the chat: any message whose first word is one of the game's commands, or an
-- emote command (/e dance, /e floss, ...), is never delivered to anyone, including the person who typed
-- it. The commands themselves still run. Every TextChatCommand the game creates (sky events, admin
-- commands) is picked up automatically, so new commands are hidden without changing this script.

local TextChatService = game:GetService("TextChatService")

local hiddenCommands = {
	e = true, -- emotes: /e dance, /e floss, /e wave, ...
	emote = true,
}

local function addAliases(instance)
	if instance:IsA("TextChatCommand") then
		for _, alias in ipairs({ instance.PrimaryAlias, instance.SecondaryAlias }) do
			local word = string.match(string.lower(alias), "^/(%w+)$")
			if word then
				hiddenCommands[word] = true
			end
		end
	end
end

local function isCommand(text)
	local word = text and string.match(string.lower(text), "^%s*/(%w+)")
	return word ~= nil and hiddenCommands[word] == true
end

local function hookChannel(channel)
	if channel:IsA("TextChannel") then
		channel.ShouldDeliverCallback = function(message)
			return not isCommand(message.Text)
		end
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	for _, instance in ipairs(TextChatService:GetDescendants()) do
		addAliases(instance)
	end
	TextChatService.DescendantAdded:Connect(addAliases)

	local channels = TextChatService:WaitForChild("TextChannels")
	for _, channel in ipairs(channels:GetChildren()) do
		hookChannel(channel)
	end
	channels.ChildAdded:Connect(hookChannel)
end
