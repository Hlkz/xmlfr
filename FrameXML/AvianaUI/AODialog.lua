
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
	end
end

AddonMessageEventFrame:RegisterEvent("CHAT_MSG_ADDON")
AddonMessageEventFrame:SetScript("OnEvent", AddonMessageEventHandler);
