
-- AOF
Aviana_RepresentedFactionIndex = -1
Aviana_WaitingForRepresentedFaction = false
-- AOI
Aviana_IsLeaveWorldMapAllowed = false
Aviana_OnClickScripts = false

function ToggleWorldMapFrame()
	if Aviana_IsLeaveWorldMapAllowed then
		ToggleFrame(WorldMapFrame)
	end
end

Aviana_FullScreenFlasher = CreateFrame("Frame", "AWFlash")
local flasher = Aviana_FullScreenFlasher
flasher:SetToplevel(true)
flasher:SetFrameStrata("FULLSCREEN_DIALOG")
flasher:SetAllPoints(UIParent)
flasher:EnableMouse(false)
flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
local t = flasher.texture
t:SetTexture(0, 0, 0)
t:SetAllPoints(UIParent)
flasher:Show()
