local profList = {
	["!bs"] = "Blacksmithing",
	["!blacksmithing"] = "Blacksmithing",
	["!blacksmith"] = "Blacksmithing",
	["!jc"] = "Jewelcrafting",
	["!jewelcrafting"] = "Jewelcrafting",
	["!enchanting"] = "Enchanting",
	["!enc"] = "Enchanting",
	["!tail"] = "Tailoring",
	["!tailoring"] = "Tailoring",
	["!alc"] = "Alchemy",
	["!alchemy"] = "Alchemy",
	["!eng"] = "Engineering",
	["!engineering"] = "Engineering",
	["!ins"] = "Inscription",
	["!inscription"] = "Inscription",
	["!lw"] = "Leatherworking",
	["!leatherworking"] = "Leatherworking",
}
-- Custom text to send when sending to a channel
local customText = " no fee, tips are welcome"
-- guildDelay/whisperDelay wait time before sending guild/whisper
local guildDelay, whisperDelay = 3, 3
-- Store time sent and who requested the link
local spamTable = {}

local f = CreateFrame("Frame", "bProfLink", nil)

f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

function f:CHAT_MSG_WHISPER(event, msg, author, ...)
	if(author == UnitName("player")) then return end

	for k,v in pairs(profList) do
		if msg:lower() == k then
			local currentTime = GetTime()
			if not spamTable[author] or currentTime > (spamTable[author]+whisperDelay) then
				local spell = select(2,GetSpellLink(v))
				if spell then
					SendChatMessage(spell, "WHISPER", nil, author)
					spamTable[author] = currentTime
				else
					SendChatMessage("I dont have " .. v, "WHISPER", nil, author)
				end
				break
			end
		end
	end
end

function f:CHAT_MSG_GUILD(event, msg, author, ...)
	if(author == UnitName("player")) then return end

	for k,v in pairs(profList) do
		if msg:lower() == k then
			local currentTime = GetTime()
			if not spamTable[author] or currentTime > (spamTable[author]+guildDelay) then
				local spell = select(2,GetSpellLink(v))
				if spell then
					SendChatMessage(spell, "GUILD", nil)
					spamTable[author] = currentTime
				end
				break
			end
		end
	end
end

f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_GUILD")

SLASH_BLIB_PROF1 = '/pf'

--sneak some code from instancefuuuuuu
SlashCmdList['BLIB_PROF'] = function(arg1)
	local type = ChatFrameEditBox:GetAttribute"chatType"
	local prof
	for link, spell in pairs(profList) do
		if(arg1:lower() == link:sub(2)) then
			prof = spell
			break
		end
	end

	if prof then
		if(type == "WHISPER") then
			SendChatMessage(select(2,GetSpellLink(prof)), type, nil, ChatFrameEditBox:GetAttribute"tellTarget")
		elseif ( type == "CHANNEL") then
			SendChatMessage(select(2,GetSpellLink(prof)) .. customText, type, nil, ChatFrameEditBox:GetAttribute"channelTarget")
		else
			SendChatMessage(select(2,GetSpellLink(prof)), type)
		end
	end
end
