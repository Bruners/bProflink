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
-- Custom text to send when sending to a channel, should make this changeable ingame
local customTxt = " no fee, tips are welcome"
-- wGTime/wWTime wait time before sending guild/whisper
local wGTime, wWTime = 10, 10
-- sGTime/sWTime the time we broadcasted to guild/whisper
local sGTime, sWTime = nil

local f = CreateFrame("Frame", "bProfLink", nil)

f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

function f:CHAT_MSG_WHISPER(event, msg, author, ...)
	if(author == UnitName("player")) then return end

	for k,v in pairs(profList) do
		if msg:lower() == k then
			local cTime = GetTime() -- current time
			if not sWTime or cTime > (sWTime+wWTime) then
				local spell = select(2,GetSpellLink(v))
				if spell then
					SendChatMessage(spell, "WHISPER", nil, author)
					sWTime = cTime
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
			local cTime = GetTime() -- current time
			if not sGTime or cTime > (sGTime+wGTime) then
				local spell = select(2,GetSpellLink(v))
				if spell then
					SendChatMessage(spell, "GUILD", nil)
					sGTime = cTime
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
			SendChatMessage(select(2,GetSpellLink(prof)) .. customTxt, type, nil, ChatFrameEditBox:GetAttribute"channelTarget")
		else
			SendChatMessage(select(2,GetSpellLink(prof)), type)
		end
	end
end
