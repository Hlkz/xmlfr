
MAX_RAID_MEMBERS = 40;
NUM_RAID_GROUPS = 8;
MEMBERS_PER_RAID_GROUP = 5;
MAX_RAID_INFOS = 20;

function RaidFrame_OnLoad(self)
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("RAID_ROSTER_UPDATE");
	self:RegisterEvent("UPDATE_INSTANCE_INFO");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED");
	self:RegisterEvent("PARTY_LEADER_CHANGED");
	self:RegisterEvent("VOICE_STATUS_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("READY_CHECK");
	self:RegisterEvent("READY_CHECK_CONFIRM");
	self:RegisterEvent("READY_CHECK_FINISHED");
	self:RegisterEvent("PARTY_LFG_RESTRICTED");

	-- Update party frame visibility
	RaidOptionsFrame_UpdatePartyFrames();
	RaidFrame_Update();

	RaidFrame.hasRaidInfo = nil;
end

function RaidFrame_OnEvent(self, event, ...)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		RequestRaidInfo();
	elseif ( event == "PLAYER_LOGIN" ) then
		if ( GetNumRaidMembers() > 0 ) then
			RaidFrame_LoadUI();
			RaidFrame_Update();
		end
	elseif ( event == "RAID_ROSTER_UPDATE" ) then
		RaidFrame_LoadUI();
		RaidFrame_Update();
		RaidPullout_RenewFrames();
	elseif ( event == "READY_CHECK" or
		 event == "READY_CHECK_CONFIRM" ) then
		if ( RaidFrame:IsShown() and RaidGroupFrame_Update ) then
			RaidGroupFrame_Update();
		end
	elseif ( event == "READY_CHECK_FINISHED" ) then
		if ( RaidFrame:IsShown() and RaidGroupFrame_ReadyCheckFinished ) then
			RaidGroupFrame_ReadyCheckFinished();
		end
	elseif ( event == "UPDATE_INSTANCE_INFO" ) then
		if ( not RaidFrame.hasRaidInfo ) then
			-- Set flag
			RaidFrame.hasRaidInfo = 1;
			return;
		end
	elseif ( event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_LEADER_CHANGED" or
		event == "VOICE_STATUS_UPDATE" or event == "PARTY_LFG_RESTRICTED" ) then
		RaidFrame_Update();
	end
end

function RaidFrame_Update()
	-- If not in a raid hide all the UI and just display raid explanation text
	if ( GetNumRaidMembers() == 0 ) then
		RaidFrameConvertToRaidButton:Show();
		CreateFactionRaidCheck:Show()
		CreateGuildRaidCheck:Show()
		if ( Aviana_GM or ( GetPartyMember(1) and IsPartyLeader() and not HasLFGRestrictions() ) ) then
			RaidFrameConvertToRaidButton:Enable();
			if ( Aviana_CanCreateFactionRaid ) then
				CreateFactionRaidCheck:Enable()
				CreateFactionRaidCheckText:SetTextColor(CreateFactionRaidCheckText:GetFontObject():GetTextColor());
			else
				CreateFactionRaidCheck:Disable()
				CreateFactionRaidCheckText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
			end
			if ( Aviana_CanCreateGuildRaid ) then
				CreateGuildRaidCheck:Enable()
				CreateGuildRaidCheckText:SetTextColor(CreateGuildRaidCheckText:GetFontObject():GetTextColor());
			else
				CreateGuildRaidCheck:Disable()
				CreateGuildRaidCheckText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
			end
		else
			RaidFrameConvertToRaidButton:Disable();
			CreateFactionRaidCheck:Disable()
			CreateFactionRaidCheckText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
			CreateGuildRaidCheck:Disable()
			CreateGuildRaidCheckText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
		end
		RaidFrameNotInRaid:Show();
	else
		RaidFrameConvertToRaidButton:Hide();
		CreateFactionRaidCheck:Hide()
		CreateGuildRaidCheck:Hide()
		RaidFrameNotInRaid:Hide();
	end

	if ( RaidGroupFrame_Update ) then
		RaidGroupFrame_Update();
	end

	if ( Aviana_RepresentedFactionIndex == -1 and not Aviana_WaitingForRepresentedFaction ) then
		SendChatMessage(".rpz ?", "GUILD")
		Aviana_WaitingForRepresentedFaction = true
	end
end

-- Function for raid options
function RaidOptionsFrame_UpdatePartyFrames()
	if ( HIDE_PARTY_INTERFACE == "1" and GetNumRaidMembers() > 0) then
		HidePartyFrame();
	else
		HidePartyFrame();
		ShowPartyFrame();
	end
	UpdatePartyMemberBackground();
end

function ConvertToRaid2()
	if ( Aviana_CanCreateFactionRaid and CreateFactionRaidCheck:GetChecked() ) then
		SendChatMessage(".raid 1", "GUILD")
	elseif ( Aviana_CanCreateGuildRaid and CreateGuildRaidCheck:GetChecked() ) then
		SendChatMessage(".raid 2", "GUILD")
	else
		SendChatMessage(".raid", "GUILD")
		--ConvertToRaid()
	end
end

function CreateFactionRaidCheck_OnClick()
	if ( CreateFactionRaidCheck:GetChecked() and CreateGuildRaidCheck:GetChecked() ) then
		CreateGuildRaidCheck:SetChecked(nil)
	end
end

function CreateGuildRaidCheck_OnClick()
	if ( CreateGuildRaidCheck:GetChecked() and CreateFactionRaidCheck:GetChecked() ) then
		CreateFactionRaidCheck:SetChecked(nil)
	end
end

