--[[
AOUtil
]]

---------------------------------------------------------
-- Util

SLASH_RELOADUI1 = "/rl"
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = "/fs"
SlashCmdList.FRAMESTK = function()
	LoadAddOn('Blizzard_DebugTools')
	FrameStackTooltip_Toggle()
end

SLASH_FRAMEHBS1 = "/hbs"
SlashCmdList.FRAMEHBS = function()
	Aviana_FullScreenFlasher:Hide()
end

for i = 1, NUM_CHAT_WINDOWS do
	_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false)
end

SLASH_TEST1 = "/test"
SlashCmdList.TEST = function()
end

---------------------------------------------------------

local EnteringWorldEventFrame = CreateFrame("FRAME", "AOUtilEventFrame")

local function EnteringWorldEventHandler(self, event, ...)
end

EnteringWorldEventFrame:SetScript("OnEvent", EnteringWorldEventHandler);
EnteringWorldEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
