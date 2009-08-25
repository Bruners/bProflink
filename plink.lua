profList = {
	["!bs"] = "Blacksmithing",
	["!blacksmithing"] = "Blacksmithing",
	["!blacksmith"] = "Blacksmithing",
	["!jc"] = "Jewelcrafting",
	["!jewelcrafting"] = "Jewelcrafting",
	["!enchanting"] = "Enchanting",
	["!enc"] = "Enchanting",
	["!tail"] = "Tailoring",
	["!tailoring"] = "Tailoring",
}
local customTxt = " no fee, tips are welcome"
local f = CreateFrame("Frame", "blib", nil)

f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)


function f:CHAT_MSG_WHISPER(event, msg, author, ...)
	for k,v in pairs(profList) do
		if msg == k then
			local spell = select(2,GetSpellLink(v)) 
			if spell then
				SendChatMessage(spell, "WHISPER", nil, author)
			else
				SendChatMessage("i dont have " .. v, "WHISPER", nil, author)
			end
			break
		end
	end
end

function f:CHAT_MSG_GUILD(event, msg, author, ...)
	for k,v in pairs(profList) do
		if msg == k then
			local spell = select(2,GetSpellLink(v))
			if spell then
				SendChatMessage(spell, "GUILD", nil)
			end
			break
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
	if arg1 == "bs" then
		prof = "Blacksmithing"
	elseif arg1 == "jc" then
		prof = "Jewelcrafting"
	else
		return
	end
	if prof then
		if(type == "WHISPER") then
			SendChatMessage(select(2,GetSpellLink(prof)), type, nil, ChatFrameEditBox:GetAttribute"tellTarget")
		elseif ( type == "CHANNEL") then
			SendChatMessage(select(2,GetSpellLink(prof)) .. customTxt, type, nil, ChatFrameEditBox:GetAttribute"channelTarget")
		else
			SendChatMessage(select(2,GetSpellLink(prof)), type)
		end
	end
end


