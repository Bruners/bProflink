local ADDON_NAME = ...

local ADDON_PREFIX = "Profession Link: "
local MAX_CHAT_LENGTH = 255
local SPAM_TABLE_MAX_ENTRIES = 200
local WHISPER_MISSING_PREFIX = "I don't have "

local DEFAULTS = {
	customText = "no fee, tips are welcome",
	whisperDelay = 3,
	guildDelay = 3,
}

-- Detect client flavor via TOC interface build number (Retail >= 10.0, Forever 1.60.x).
local interfaceVersion = GetBuildInfo and select(4, GetBuildInfo()) or nil
local IS_FOREVER = interfaceVersion ~= nil and interfaceVersion >= 16000 and interfaceVersion < 20000
local IS_RETAIL = interfaceVersion ~= nil and interfaceVersion >= 100000

-- Resolve WoW 12.0+ (Retail Midnight & Forever) namespaced APIs with fallbacks for older builds.
local SendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage
local InChatMessagingLockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
local GetSpellTradeSkillLink = C_Spell and C_Spell.GetSpellTradeSkillLink
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local GetSpellBookItemTradeSkillLink = C_SpellBook and C_SpellBook.GetSpellBookItemTradeSkillLink
local GetTradeSkillListLink = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillListLink
local GetBaseProfessionInfo = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo
local LegacyGetTradeSkillListLink = _G.GetTradeSkillListLink
local LegacyGetTradeSkillLine = _G.GetTradeSkillLine
local LegacyGetSpellLink = _G.GetSpellLink
local IsSecretValue = _G.issecretvalue

-- Supported crafting, gathering, and secondary professions (Apprentice spell IDs plus optional journal/trade-skill linkSpellIDs).
local ALL_PROFESSIONS = {
	{ name = "Alchemy", spellID = 2259, alias = "alch" },
	{ name = "Blacksmithing", spellID = 2018, alias = "bs" },
	{ name = "Enchanting", spellID = 7411, alias = "ench" },
	{ name = "Engineering", spellID = 4036, alias = "eng" },
	{ name = "Herbalism", spellID = 2366, linkSpellIDs = { 193290 }, alias = "herb" },
	{ name = "Inscription", spellID = 45357, alias = "insc", retailOnly = true },
	{ name = "Jewelcrafting", spellID = 25229, alias = "jc", retailOnly = true },
	{ name = "Leatherworking", spellID = 2108, alias = "lw" },
	{ name = "Mining", spellID = 2575, linkSpellIDs = { 2656 }, alias = "mine" },
	{ name = "Skinning", spellID = 8613, linkSpellIDs = { 194174 }, alias = "skin" },
	{ name = "Tailoring", spellID = 3908, alias = "tail" },
	{ name = "Archaeology", spellID = 78670, alias = "arch", retailOnly = true },
	{ name = "Cooking", spellID = 2550, alias = "cook" },
	{ name = "First Aid", spellID = 3273, alias = "fa", excludeRetail = true },
	{ name = "Fishing", spellID = 7620, linkSpellIDs = { 271990, 131474 }, alias = "fish" },
}

local PROFESSIONS = {}
local PROFESSION_BY_NAME = {}
for _, entry in ipairs(ALL_PROFESSIONS) do
	local excluded = (entry.retailOnly and IS_FOREVER) or (entry.excludeRetail and IS_RETAIL)
	if not excluded then
		table.insert(PROFESSIONS, entry)
		PROFESSION_BY_NAME[entry.name] = entry
	end
end

local TRIGGER_TO_PROFESSION = {
	alch = "Alchemy",
	alchemy = "Alchemy",
	bs = "Blacksmithing",
	blacksmith = "Blacksmithing",
	blacksmithing = "Blacksmithing",
	ench = "Enchanting",
	enchant = "Enchanting",
	enchanting = "Enchanting",
	eng = "Engineering",
	engi = "Engineering",
	engineer = "Engineering",
	engineering = "Engineering",
	herb = "Herbalism",
	herbalism = "Herbalism",
	herbing = "Herbalism",
	insc = "Inscription",
	inscr = "Inscription",
	scribe = "Inscription",
	inscription = "Inscription",
	jc = "Jewelcrafting",
	jewel = "Jewelcrafting",
	jewelcraft = "Jewelcrafting",
	jewelcrafting = "Jewelcrafting",
	lw = "Leatherworking",
	leather = "Leatherworking",
	leatherworking = "Leatherworking",
	mine = "Mining",
	mining = "Mining",
	smelt = "Mining",
	smelting = "Mining",
	skin = "Skinning",
	skinning = "Skinning",
	tail = "Tailoring",
	tailor = "Tailoring",
	tailoring = "Tailoring",
	arch = "Archaeology",
	archaeology = "Archaeology",
	archeology = "Archaeology",
	cook = "Cooking",
	cooking = "Cooking",
	fa = "First Aid",
	firstaid = "First Aid",
	["first aid"] = "First Aid",
	fish = "Fishing",
	fishing = "Fishing",
}

local spamTable = {}
local spamCount = 0

--- Trims leading and trailing whitespace from a string.
-- @param str string|nil Input text
-- @return string Trimmed text (empty string if nil)
local function Trim(str)
	if type(str) ~= "string" then
		return ""
	end
	if _G.strtrim then
		return _G.strtrim(str)
	end
	return str:match("^%s*(.-)%s*$") or ""
end

--- Prints a message prefixed with the addon title.
-- @param msg string Message to display in the local chat frame
local function Print(msg)
	print(ADDON_PREFIX .. tostring(msg))
end

--- Returns the initialized SavedVariables table, populating missing defaults.
-- Checks `== nil` explicitly so intentionally cleared strings (e.g. `""`) persist.
-- @return table ProfessionLinkDB table
local function GetDB()
	if type(ProfessionLinkDB) ~= "table" then
		ProfessionLinkDB = {}
	end
	for key, defaultValue in pairs(DEFAULTS) do
		if ProfessionLinkDB[key] == nil then
			ProfessionLinkDB[key] = defaultValue
		end
	end
	return ProfessionLinkDB
end

--- Resolves a localized spell name by its spell ID.
-- @param spellID number Spell ID
-- @return string|nil Localized spell name, or nil if unavailable
local function GetSpellNameByID(spellID)
	if GetSpellName then
		local name = GetSpellName(spellID)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	if GetSpellInfo then
		local info = GetSpellInfo(spellID)
		if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			return info.name
		end
	end
	return nil
end

--- Resolves the client-localized name of a profession via its Apprentice spell ID.
-- @param profEntry table Entry from PROFESSIONS
-- @return string Localized profession name (falls back to English name)
local function GetLocalizedProfessionName(profEntry)
	return GetSpellNameByID(profEntry.spellID) or profEntry.name
end

--- Resolves a user trigger or slash argument to a supported profession entry.
-- @param rawInput string Trigger text without leading "!" or slash command argument
-- @return table|nil Entry from PROFESSIONS, or nil if unrecognized
local function ResolveProfession(rawInput)
	if type(rawInput) ~= "string" then
		return nil
	end

	local cleaned = Trim(rawInput):lower():gsub("[?!.,:;]+$", "")
	cleaned = Trim(cleaned)
	if cleaned == "" then
		return nil
	end

	local matchedName = TRIGGER_TO_PROFESSION[cleaned]
	if matchedName then
		return PROFESSION_BY_NAME[matchedName]
	end

	local firstWord = cleaned:match("^(%S+)")
	if firstWord then
		matchedName = TRIGGER_TO_PROFESSION[firstWord]
		if matchedName then
			return PROFESSION_BY_NAME[matchedName]
		end

		-- Match prefixes of 4+ characters to preserve legacy "!blac" / "!tail" behavior.
		if #firstWord >= 4 then
			for _, entry in ipairs(PROFESSIONS) do
				local englishLower = entry.name:lower()
				if englishLower:sub(1, #firstWord) == firstWord then
					return entry
				end
				local localizedLower = GetLocalizedProfessionName(entry):lower()
				if localizedLower:sub(1, #firstWord) == firstWord then
					return entry
				end
			end
		end
	end

	return nil
end

--- Retrieves the player's clickable trade skill hyperlink for a profession.
-- @param profEntry table Entry from PROFESSIONS
-- @return string|nil Trade skill hyperlink if learned, otherwise nil
local function GetProfessionTradeLink(profEntry)
	local candidateNames = {}
	local candidateSet = {}

	local function AddCandidateName(name)
		if type(name) == "string" and name ~= "" then
			local lower = name:lower()
			if not candidateSet[lower] then
				candidateSet[lower] = true
				table.insert(candidateNames, name)
			end
		end
	end

	AddCandidateName(GetLocalizedProfessionName(profEntry))
	if profEntry.linkSpellIDs then
		for _, linkSpellID in ipairs(profEntry.linkSpellIDs) do
			AddCandidateName(GetSpellNameByID(linkSpellID))
		end
	end
	AddCandidateName(profEntry.name)

	-- Tier 1: Direct C_Spell trade skill link lookup (11.0+ / Forever engine).
	if GetSpellTradeSkillLink then
		for _, name in ipairs(candidateNames) do
			local link = GetSpellTradeSkillLink(name)
			if type(link) == "string" and link ~= "" then
				return link
			end
		end
		local link = GetSpellTradeSkillLink(profEntry.spellID)
		if type(link) == "string" and link ~= "" then
			return link
		end
		if profEntry.linkSpellIDs then
			for _, linkSpellID in ipairs(profEntry.linkSpellIDs) do
				link = GetSpellTradeSkillLink(linkSpellID)
				if type(link) == "string" and link ~= "" then
					return link
				end
			end
		end
	end

	-- Tier 2: Spellbook scan via GetProfessions() + C_SpellBook.
	-- Iterate indices 1..6 explicitly instead of ipairs because unlearned slots are nil holes.
	if GetProfessions and GetProfessionInfo and GetSpellBookItemTradeSkillLink then
		local slots = { GetProfessions() }
		local spellBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "spell"

		for i = 1, 6 do
			local profIndex = slots[i]
			if profIndex then
				local profName, _, _, _, numAbilities, spellOffset = GetProfessionInfo(profIndex)
				if type(profName) == "string" and candidateSet[profName:lower()] and spellOffset then
					for offset = 1, (numAbilities or 1) do
						local link = GetSpellBookItemTradeSkillLink(spellOffset + offset, spellBank)
						if type(link) == "string" and link ~= "" then
							return link
						end
					end
				end
			end
		end
	end

	-- Tier 3: Open profession window fallback via C_TradeSkillUI (Retail) or legacy globals.
	-- Verify the open window actually matches the requested profession before returning its link.
	if GetTradeSkillListLink and GetBaseProfessionInfo then
		local baseInfo = GetBaseProfessionInfo()
		if baseInfo then
			local profLower = type(baseInfo.professionName) == "string" and baseInfo.professionName:lower() or nil
			local parentLower = type(baseInfo.parentProfessionName) == "string" and baseInfo.parentProfessionName:lower() or nil
			if (profLower and candidateSet[profLower]) or (parentLower and candidateSet[parentLower]) then
				local link = GetTradeSkillListLink()
				if type(link) == "string" and link ~= "" then
					return link
				end
			end
		end
	end
	if LegacyGetTradeSkillListLink and LegacyGetTradeSkillLine then
		local openName = LegacyGetTradeSkillLine()
		if type(openName) == "string" and candidateSet[openName:lower()] then
			local link = LegacyGetTradeSkillListLink()
			if type(link) == "string" and link ~= "" then
				return link
			end
		end
	end

	-- Tier 4: Legacy global GetSpellLink fallback.
	if LegacyGetSpellLink then
		for _, name in ipairs(candidateNames) do
			local _, link = LegacyGetSpellLink(name)
			if type(link) == "string" and link ~= "" then
				return link
			end
		end
	end

	return nil
end

--- Checks whether chat messaging is currently restricted by an encounter lockdown.
-- @return boolean True when outbound chat APIs are locked down
local function IsChatLockedDown()
	return InChatMessagingLockdown ~= nil and InChatMessagingLockdown() == true
end

--- Checks whether any passed value is a 12.0+ tainted secret value.
-- Inspecting or comparing secret values throws Lua errors during chat lockdown.
-- @param ... any Values to inspect
-- @return boolean True if any argument is a secret value
local function IsAnySecret(...)
	if not IsSecretValue then
		return false
	end
	for i = 1, select("#", ...) do
		if IsSecretValue(select(i, ...)) then
			return true
		end
	end
	return false
end

--- Determines whether an incoming chat author/GUID belongs to the local player.
-- @param author string Sender name from chat event
-- @param senderGUID string|nil Sender GUID from chat event
-- @return boolean True if the sender is the player
local function IsPlayerSelf(author, senderGUID)
	if senderGUID and UnitGUID then
		local playerGUID = UnitGUID("player")
		if playerGUID and senderGUID == playerGUID then
			return true
		end
	end

	if type(author) ~= "string" then
		return false
	end

	local playerName, playerRealm
	if UnitFullName then
		playerName, playerRealm = UnitFullName("player")
	elseif UnitName then
		playerName = UnitName("player")
	end

	if not playerName then
		return false
	end

	if author == playerName then
		return true
	end

	local normalizedRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or playerRealm
	if normalizedRealm and normalizedRealm ~= "" and author == (playerName .. "-" .. normalizedRealm) then
		return true
	end

	return false
end

--- Checks if an author is still within the cooldown window.
-- @param author string Sender name
-- @param delay number Cooldown duration in seconds
-- @param now number Current GetTime() timestamp
-- @return boolean True if throttled
local function IsThrottled(author, delay, now)
	local lastSent = spamTable[author]
	return lastSent ~= nil and now <= (lastSent + delay)
end

--- Records a sent reply timestamp and bounds memory usage on long sessions.
-- @param author string Sender name
-- @param now number Current GetTime() timestamp
local function MarkSent(author, now)
	if spamTable[author] == nil then
		spamCount = spamCount + 1
	end
	spamTable[author] = now

	if spamCount > SPAM_TABLE_MAX_ENTRIES then
		local db = GetDB()
		local maxDelay = math.max(db.whisperDelay or 3, db.guildDelay or 3)
		for key, timestamp in pairs(spamTable) do
			if now > (timestamp + maxDelay) then
				spamTable[key] = nil
				spamCount = spamCount - 1
			end
		end
	end
end

--- Sends a chat message safely, guarding against lockdown and missing APIs.
-- @param message string Message text
-- @param chatType string Chat channel type (e.g. "WHISPER", "GUILD", "CHANNEL")
-- @param target string|number|nil Target player name or channel ID
-- @return boolean True if dispatched
local function SafeSendChatMessage(message, chatType, target)
	if IsChatLockedDown() or not SendChatMessage or type(message) ~= "string" or message == "" then
		return false
	end
	SendChatMessage(message, chatType, nil, target)
	return true
end

--- Appends the configured custom channel text without ever truncating the hyperlink.
-- @param link string Profession trade skill hyperlink
-- @return string Formatted chat payload within MAX_CHAT_LENGTH bytes
local function BuildChannelPayload(link)
	local customText = Trim(GetDB().customText or "")
	if customText == "" then
		return link
	end

	local maxSuffix = MAX_CHAT_LENGTH - #link - 1
	if maxSuffix <= 0 then
		return link
	end

	return link .. " " .. customText:sub(1, maxSuffix)
end

--- Processes incoming whisper or guild chat profession link requests.
-- @param chatType string "WHISPER" or "GUILD"
-- @param delay number Per-author throttle duration in seconds
-- @param replyWhenMissing boolean Whether to reply when the player lacks the profession
-- @param msg string Chat message payload
-- @param author string Sender name
-- @param senderGUID string|nil Sender GUID
local function HandleChatRequest(chatType, delay, replyWhenMissing, msg, author, senderGUID)
	if IsChatLockedDown() or IsAnySecret(msg, author, senderGUID) then
		return
	end
	if type(msg) ~= "string" or type(author) ~= "string" or IsPlayerSelf(author, senderGUID) then
		return
	end

	local trimmed = Trim(msg)
	if trimmed:sub(1, 1) ~= "!" then
		return
	end

	local profEntry = ResolveProfession(trimmed:sub(2))
	if not profEntry then
		return
	end

	local now = GetTime()
	if IsThrottled(author, delay, now) then
		return
	end

	local target = (chatType == "WHISPER") and author or nil
	local link = GetProfessionTradeLink(profEntry)
	if link then
		if SafeSendChatMessage(link, chatType, target) then
			MarkSent(author, now)
		end
	elseif replyWhenMissing then
		local missingReply = WHISPER_MISSING_PREFIX .. GetLocalizedProfessionName(profEntry)
		if SafeSendChatMessage(missingReply, chatType, target) then
			MarkSent(author, now)
		end
	end
end

local frame = CreateFrame("Frame")
local eventHandlers = {}

function eventHandlers:ADDON_LOADED(loadedName)
	if loadedName ~= ADDON_NAME then
		return
	end
	GetDB()
	self:UnregisterEvent("ADDON_LOADED")
end

function eventHandlers:CHAT_MSG_WHISPER(msg, author, _, _, _, _, _, _, _, _, _, senderGUID)
	HandleChatRequest("WHISPER", GetDB().whisperDelay, true, msg, author, senderGUID)
end

function eventHandlers:CHAT_MSG_GUILD(msg, author, _, _, _, _, _, _, _, _, _, senderGUID)
	HandleChatRequest("GUILD", GetDB().guildDelay, false, msg, author, senderGUID)
end

frame:SetScript("OnEvent", function(self, event, ...)
	local handler = eventHandlers[event]
	if handler then
		handler(self, ...)
	end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_GUILD")

--- Prints command usage, active flavor professions, and current channel message.
local function PrintHelp()
	local db = GetDB()
	local currentMsg = Trim(db.customText or "")
	if currentMsg == "" then
		currentMsg = "(none)"
	end

	local profNames = {}
	for _, entry in ipairs(PROFESSIONS) do
		table.insert(profNames, entry.name:lower() .. " (" .. entry.alias .. ")")
	end

	Print("Usage:")
	print("  /pf <profession>  (or /pl, /proflink) - Link a profession in your active chat")
	print("  /pf msg <text>    - Set custom text appended when linking in channels")
	print("  /pf msg clear     - Clear custom channel text")
	print("  /pf help          - Show this help")
	print("  Professions: " .. table.concat(profNames, ", "))
	print("  Current channel text: " .. currentMsg)
end

--- Resolves the active or most recent chat edit box cleanly without legacy chatStyle assumptions.
-- @param explicitEditBox Frame|nil Edit box passed to the slash command handler
-- @return Frame|nil Resolved chat edit box
local function ResolveEditBox(explicitEditBox)
	if explicitEditBox then
		return explicitEditBox
	end
	if ChatEdit_GetActiveWindow then
		local active = ChatEdit_GetActiveWindow()
		if active then
			return active
		end
	end
	if ChatEdit_GetLastActiveWindow then
		local lastActive = ChatEdit_GetLastActiveWindow()
		if lastActive then
			return lastActive
		end
	end
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
		return DEFAULT_CHAT_FRAME.editBox
	end
	return nil
end

--- Sends a Battle.net whisper when the active chat target is BN_WHISPER.
-- @param target string BattleTag/presence target from editBox tellTarget
-- @param link string Profession trade skill hyperlink
-- @return boolean True if sent via Battle.net API
local function TrySendBNetWhisper(target, link)
	if type(target) ~= "string" or target == "" or not BNet_GetBNetIDAccount then
		return false
	end
	local bnetIDAccount = BNet_GetBNetIDAccount(target)
	if not bnetIDAccount then
		return false
	end
	if C_BattleNet and C_BattleNet.SendWhisper then
		C_BattleNet.SendWhisper(bnetIDAccount, link)
		return true
	end
	if BNSendWhisper then
		BNSendWhisper(bnetIDAccount, link)
		return true
	end
	return false
end

SLASH_PROFESSIONLINK1 = "/pf"
SLASH_PROFESSIONLINK2 = "/pl"
SLASH_PROFESSIONLINK3 = "/proflink"

SlashCmdList["PROFESSIONLINK"] = function(rawArgs, editBox)
	local trimmed = Trim(rawArgs)
	local lower = trimmed:lower()

	if trimmed == "" or lower == "help" then
		PrintHelp()
		return
	end

	if lower == "msg" then
		local currentMsg = Trim(GetDB().customText or "")
		Print("Current channel text: " .. (currentMsg ~= "" and currentMsg or "(none)"))
		return
	end

	local msgArg = trimmed:match("^[Mm][Ss][Gg]%s+(.+)$")
	if msgArg then
		local cleanedArg = Trim(msgArg)
		local cleanedLower = cleanedArg:lower()
		if cleanedLower == "clear" or cleanedLower == "none" then
			GetDB().customText = ""
			Print("Custom channel text cleared.")
		else
			GetDB().customText = cleanedArg
			Print("Custom channel text set to: " .. cleanedArg)
		end
		return
	end

	local profEntry = ResolveProfession(trimmed)
	if not profEntry then
		Print("Unknown profession \"" .. trimmed .. "\". Type /pf help for options.")
		return
	end

	if IsChatLockedDown() then
		Print("Cannot send profession links during chat messaging lockdown.")
		return
	end

	local link = GetProfessionTradeLink(profEntry)
	if not link then
		Print("You don't seem to have " .. GetLocalizedProfessionName(profEntry) .. ".")
		return
	end

	local eb = ResolveEditBox(editBox)
	local chatType = (eb and eb:GetAttribute("chatType")) or "SAY"

	if chatType == "WHISPER" then
		local target = eb and eb:GetAttribute("tellTarget")
		if type(target) == "string" and target ~= "" then
			SafeSendChatMessage(link, "WHISPER", target)
		else
			Print("No whisper target found. Open a whisper first or use another chat channel.")
		end
	elseif chatType == "BN_WHISPER" then
		local target = eb and eb:GetAttribute("tellTarget")
		if not TrySendBNetWhisper(target, link) then
			if ChatEdit_InsertLink then
				ChatEdit_InsertLink(link)
			else
				Print("Unable to send Battle.net whisper directly.")
			end
		end
	elseif chatType == "CHANNEL" then
		local target = eb and eb:GetAttribute("channelTarget")
		if (type(target) == "number" and target > 0) or (type(target) == "string" and Trim(target) ~= "") then
			SafeSendChatMessage(BuildChannelPayload(link), "CHANNEL", target)
		else
			Print("No channel target found. Select a chat channel first.")
		end
	else
		SafeSendChatMessage(link, chatType)
	end
end
