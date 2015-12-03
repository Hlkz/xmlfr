
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
			return
		end

		if (prefix == "AON") then
			-- prefix,isNew
			AONewChar:HandleAddonMessage(MSG)
			return
		end

		if (prefix == "AOF") then
			HandleAOFAddonMessage(MSG)
			return
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
	pattern = "^([0-9]+)$"
	m = strmatch(MSG, pattern)

	if m then
		local _, _, repListID = strfind(MSG, pattern)
		repListID = tonumber(repListID)
		Aviana_RepresentedFactionIndex = 0
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
				end
			end
		end
	end
	ReputationFrame_Update()
end
