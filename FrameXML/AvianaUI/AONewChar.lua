--[[
AONewChar
]]

---------------------------------------------------------
-- Addon declaration
AONewChar = {} -- LibStub("AceAddon-3.0"):NewAddon("AONewChar", "AceConsole-3.0", "AceEvent-3.0")
local AONewChar = AONewChar

function AONewChar:HandleAddonMessage(MSG)
	local pattern, m
	pattern = "^([0-9]+)$"
	m = strmatch(MSG, pattern)

	if m then
		local _, _, isNew = strfind(MSG, pattern)
		isNew = tonumber(isNew)
		if isNew == 1 then
			Aviana_IsLeaveWorldMapAllowed = false
			Aviana_OnClickScripts = true
			AOIcons:UpdateWorldMap()
			_G["WorldMapFrameCloseButton"]:Hide()
			_G["WorldMapFrameSizeDownButton"]:Hide()
			WorldMapFrame:Show()
			Aviana_FullScreenFlasher:Hide()
		else
			Aviana_IsLeaveWorldMapAllowed = true
			Aviana_OnClickScripts = false
			AOIcons:UpdateWorldMap()
			_G["WorldMapFrameCloseButton"]:Show()
			_G["WorldMapFrameSizeDownButton"]:Show()
			WorldMapFrame:Hide()
			Aviana_FullScreenFlasher:Hide()
		end
	end
end
