local profList = {
	["!bs"] = "Blacksmithing",
	["!blacksmithing"] = "Blacksmithing",
	["!jc"] = "Jewelcrafting",
	["!jewelcrafting"] = "Jewelcrafting",
	["!enchanting"] = "Enchanting",
	["!tailoring"] = "Tailoring",
	["!alchemy"] = "Alchemy",
	["!engineering"] = "Engineering",
	["!inscription"] = "Inscription",
	["!lw"] = "Leatherworking",
	["!leatherworking"] = "Leatherworking",
	["!mining"] = "Mining",
}
-- Custom text to send when sending to a channel
local customText = " no fee, tips are welcome"

-- Text to send when someone tries to request a profession you don't have
local whisperText = "I dont have "

-- Text to print when you try to send a profession you don't have to a channel
local channelLinkText = "You don't seem to have that profession"

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
		if msg:lower() == k or msg:sub(0,4) == k:sub(0,4) then
			local currentTime = GetTime()
			if not spamTable[author] or currentTime > (spamTable[author]+whisperDelay) then
				local spell = select(2,GetSpellLink(v))
				if spell then
					SendChatMessage(spell, "WHISPER", nil, author)
					spamTable[author] = currentTime
				else
					SendChatMessage(whisperText .. v, "WHISPER", nil, author)
				end
				break
			end
		end
	end
end

function f:CHAT_MSG_GUILD(event, msg, author, ...)
	if(author == UnitName("player")) then return end

	for k,v in pairs(profList) do
		if msg:lower() == k or msg:sub(0,3) == k:sub(0,3) then
			local currentTime = GetTime()
			if not spamTable[author] or currentTime > (spamTable[author]+guildDelay) then
				local spellCheck = select(2,GetSpellLink(v))
				if spellCheck then
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
			local spellCheck = select(2,GetSpellLink(spell))
			if spellCheck then
				prof = spell
				break
			end
		end
	end

	if prof then
		if(type == "WHISPER") then
			SendChatMessage(select(2,GetSpellLink(prof)), type, nil, ChatFrameEditBox:GetAttribute"tellTarget")
		elseif ( type == "CHANNEL")then
			SendChatMessage(select(2,GetSpellLink(prof)) .. customText, type, nil, ChatFrameEditBox:GetAttribute"channelTarget")
		else
			SendChatMessage(select(2,GetSpellLink(prof)), type)
		end
	else
		print("|cFF37FDFCb|rProflink: " .. channelLinkText)
	end
end
