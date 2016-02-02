
local AddonMessageEventFrame = CreateFrame("FRAME", "AODialogEventFrame")

local function AddonMessageEventHandler(self, event, MSG, _, Type, Sender)
	if (event == "CHAT_MSG_ADDON" and Sender == UnitName("player")) then
		local pattern, m
		pattern = "([a-zA-Z]+),(.*)"
		m = strmatch(MSG, pattern)
		if not m then return end
		local _, _, prefix, MSG = strfind(MSG, pattern)


		if (prefix == "AOI") then
			-- prefix,type,id,icon,title,desc,x,y
			AOIcons:HandleAddonMessage(MSG)

		elseif (prefix == "AON") then
			-- prefix,isNew
			AONewChar:HandleAddonMessage(MSG)

		elseif (prefix == "AONFT") then
			HandleAONFTAddonMessage(MSG)
		elseif (prefix == "AONF") then
			HandleAONFAddonMessage(MSG)

		elseif (prefix == "AONGT") then
			HandleAONGTAddonMessage(MSG)
		elseif (prefix == "AONG") then
			HandleAONGAddonMessage(MSG)
		elseif (prefix == "AONGC") then
			HandleAONGCAddonMessage(MSG)
		elseif (prefix == "AONGR") then
			HandleAONGRAddonMessage(MSG)

		elseif (prefix == "AOF") then
			HandleAOFAddonMessage(MSG)

		elseif (prefix == "AOG") then
			HandleAOGAddonMessage(MSG)

		elseif (prefix == "AOR") then
			HandleAORAddonMessage(MSG)

		elseif (prefix == "AOGM") then
			HandleAOGMAddonMessage(MSG)
		end
	end
end

AddonMessageEventFrame:RegisterEvent("CHAT_MSG_ADDON")
AddonMessageEventFrame:SetScript("OnEvent", AddonMessageEventHandler);

local function LoadReputationNames()
	if (ReputationListScrollFrame) then
		Aviana_ReputationIdByName = {}
		local numFactions = GetNumFactions();
		if ( not FauxScrollFrame_Update(ReputationListScrollFrame, numFactions, NUM_FACTIONS_DISPLAYED, REPUTATIONFRAME_FACTIONHEIGHT ) ) then
			ReputationListScrollFrameScrollBar:SetValue(0);
		end
		local factionOffset = FauxScrollFrame_GetOffset(ReputationListScrollFrame);
		for i=1, NUM_FACTIONS_DISPLAYED, 1 do
			local factionIndex = factionOffset + i;
			if ( factionIndex <= numFactions ) then
				local name = GetFactionInfo(factionIndex);
				Aviana_ReputationIdByName[name] = factionIndex
			end
		end
	end
end

function HandleAOFAddonMessage(MSG)
	local pattern, m
	pattern = "^(.*),([0-9])$"
	m = strmatch(MSG, pattern)
	if not m then return end

	local _, _, MSG, canCreateFactionRaid = strfind(MSG, pattern)

	pattern = "^([0-9]+)$"
	m = strmatch(MSG, pattern)
	if m then
		local _, _, repListID = strfind(MSG, pattern)
		repListID = tonumber(repListID)
		Aviana_RepresentedFactionIndex = 0
		Aviana_WaitingForRepresentedFaction = false
	else
		pattern = "^\(.*)$"
		m = strmatch(MSG, pattern)
		if m then
			local _, _, name = strfind(MSG, pattern)
			if ( not Aviana_ReputationIdByName ) then
				LoadReputationNames()
			end
			if ( Aviana_ReputationIdByName ) then
				factionIndex = Aviana_ReputationIdByName[name]
				if ( factionIndex ) then
					Aviana_RepresentedFactionIndex = factionIndex
					Aviana_WaitingForRepresentedFaction = false
				end
			end
		end
	end

	canCreateFactionRaid = tonumber(canCreateFactionRaid)
	if (canCreateFactionRaid ~= 0 ) then
		Aviana_CanCreateFactionRaid = true
	else
		Aviana_CanCreateFactionRaid = false
	end

	ReputationFrame_Update()
	RaidFrame_Update()
end

function HandleAOGAddonMessage(MSG)
	local pattern, m
	pattern = "^([0-9])$"
	m = strmatch(MSG, pattern)
	if not m then return end

	local _, _, canCreateGuildRaid = strfind(MSG, pattern)

	canCreateGuildRaid = tonumber(canCreateGuildRaid)
	if (canCreateGuildRaid ~= 0 ) then
		Aviana_CanCreateGuildRaid = true
	else
		Aviana_CanCreateGuildRaid = false
	end

	RaidFrame_Update()
end

function HandleAORAddonMessage(MSG)
	local pattern, m
	pattern = "^([0-9]),([0-9]+),(.*)$"
	m = strmatch(MSG, pattern)
	if not m then return end

	local _, _, raidType, actorId, actorName = strfind(MSG, pattern)
	raidType = tonumber(raidType)
	actorId = tonumber(actorId)

	Aviana_RaidType = raidType
	RaidFrameTypeAndNameText:SetText(actorName)
	--if ( raidType ~= 0 ) then
	--	RaidFrameTypeAndName:Show()
	--	if ( raidType == 1 ) then
	--		RaidFrameTypeAndNameText:SetText(string.format(RAID_TYPE_FACTION, actorName))
	--	elseif ( raidType == 2 ) then
	--		RaidFrameTypeAndNameText:SetText(string.format(RAID_TYPE_GUILD, actorName))
	--	end
	--else
	--	RaidFrameTypeAndName:Hide()
	--end

	RaidFrame_Update()
end

function HandleAOGMAddonMessage(MSG)
	local pattern, m
	pattern = "^([0-9])$"
	m = strmatch(MSG, pattern)
	if not m then return end

	local _, _, isGM = strfind(MSG, pattern)
	isGM = tonumber(isGM)
	if ( isGM ~= 0 ) then
		Aviana_GM = true
	else
		Aviana_GM = false
	end

	RaidFrame_Update()
end
