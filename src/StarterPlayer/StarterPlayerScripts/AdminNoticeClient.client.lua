-- Shows replies to admin chat commands (/ban, /unban) as a private system message in chat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local noticeEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AdminNotice")

noticeEvent.OnClientEvent:Connect(function(text)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage("[Admin] " .. text)
			return
		end
	end
	-- Legacy chat
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", { Text = "[Admin] " .. text })
	end)
end)
