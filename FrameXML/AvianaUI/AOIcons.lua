--[[
AOIcons
]]

---------------------------------------------------------
-- Addon declaration
AOIcons = LibStub("AceAddon-3.0"):NewAddon("AOIcons", "AceConsole-3.0", "AceEvent-3.0")
local AOIcons = AOIcons
local L = LibStub("AceLocale-3.0"):GetLocale("AvianaUI", false)

local Astrolabe = DongleStub("Astrolabe-0.4")

---------------------------------------------------------
-- Localize some globals
local floor = floor
local tconcat = table.concat
local pairs, next, type = pairs, next, type
local CreateFrame = CreateFrame
local GetCurrentMapContinent, GetCurrentMapZone = GetCurrentMapContinent, GetCurrentMapZone
local GetCurrentMapDungeonLevel = GetCurrentMapDungeonLevel
local GetRealZoneText = GetRealZoneText
local WorldMapButton, Minimap = WorldMapButton, Minimap


---------------------------------------------------------
-- xpcall safecall implementation, copied from AceAddon-3.0.lua
-- (included in distribution), with permission from nevcairiel
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end
	
		local function dispatch(func, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh)
		end
	
		return dispatch
	]]
	
	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", tconcat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})
Dispatchers[0] = function(func)
	return xpcall(func, errorhandler)
end

local function safecall(func, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, ...)
	end
end


---------------------------------------------------------
-- Our frames recycling code

AOI = {}
local MAX_AOI_TYPE = 10
local DEFAULT_POI_ICON_SIZE = 12
for i = 1, MAX_AOI_TYPE, 1 do
	AOI[i] = {}
end
local pinCache = {}
local minimapPins = {}
local worldmapPins = {}
local pinCount = 0

local function recyclePin(pin)
	pin:Hide()
	pinCache[pin] = true
end

local function clearAllPins(t)
	for coord, pin in pairs(t) do
		recyclePin(pin)
		t[coord] = nil
	end
end

local function getNewPin()
	local pin = next(pinCache)
	if pin then
		pinCache[pin] = nil -- remove it from the cache
		return pin
	end
	-- create a new pin
	pinCount = pinCount + 1
	pin = CreateFrame("Button", "AOIconsPin"..pinCount, WorldMapButton)
	pin:SetFrameLevel(5)
	pin:EnableMouse(true)
	pin:SetWidth(DEFAULT_POI_ICON_SIZE)
	pin:SetHeight(DEFAULT_POI_ICON_SIZE)
	pin:SetPoint("CENTER", WorldMapButton, "CENTER")

	--local texture = pin:CreateTexture(pin:GetName().."Texture", "BACKGROUND");
	local texture = pin:CreateTexture(nil, "BACKGROUND")
	pin.texture = texture
	texture:SetAllPoints(pin)
	texture:SetTexture("Interface\\Minimap\\POIIcons");
	pin:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
	pin:SetMovable(true)
	pin:Hide()
	return pin
end

---------------------------------------------------------
-- "Plugin" handling

local AOIHandler = {}
function AOIHandler:OnEnter(motion)
	WorldMapBlobFrame:SetScript("OnUpdate", nil) -- override default UI to hide the tooltip

	local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
	if ( self:GetCenter() > UIParent:GetCenter() ) then -- compare X coordinate
		tooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	local title = self.title
	local desc = self.desc
	if title == "" and desc == "" then title = L["(No Title)"] end
	if title == "" and desc ~= "" then title = desc  desc = nil end
	tooltip:SetText(title)
	tooltip:AddLine(desc, nil, nil, nil, true)
	tooltip:Show()
end

local Aviana_DropDownId = 0
local Aviana_DropDownTitle = ""

function AOIHandler_GenerateDropDownMenu(button, level)
	local info = {}
	if (not level) then return end
	for k in pairs(info) do info[k] = nil end
	if (level == 1) then
		-- Create the title of the menu
		info.isTitle      = 1
		info.text         = Aviana_DropDownTitle
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled     = nil
		info.isTitle      = nil

		if ( IsRaidLeader() and Aviana_RaidType > 0 ) then
			-- Attack node menu item
			info.text = L["AttackNode"]
			info.icon = nil
			info.func = function() AOIcons:AttackNode(Aviana_DropDownId) end
			info.arg1 = nil
			info.arg2 = nil
			UIDropDownMenu_AddButton(info, level)

			-- Defend node menu item
			info.text = L["DefendNode"]
			info.icon = nil
			info.func = function() AOIcons:DefendNode(Aviana_DropDownId) end
			info.arg1 = nil
			info.arg2 = nil
			UIDropDownMenu_AddButton(info, level)
		end

		if ( Aviana_GM ) then
			info.text = L["TeleportToNode"]
			info.icon = nil
			info.func = function() AOIcons:SendStartCommand(Aviana_DropDownId) end
			info.arg1 = nil
			info.arg2 = nil
			UIDropDownMenu_AddButton(info, level)
		end

		-- Close menu item
		-- info.text         = CLOSE
		-- info.icon         = nil
		-- info.func         = CloseDropDownMenus
		-- info.arg1         = nil
		-- info.arg2         = nil
		-- info.notCheckable = 1
		-- UIDropDownMenu_AddButton(info, level)
	end
end
local AOIHandler_AOIDropdownMenu = CreateFrame("Frame", "AOIHandler_AOIDropdownMenu")
AOIHandler_AOIDropdownMenu.displayMode = "MENU"
AOIHandler_AOIDropdownMenu.initialize = AOIHandler_GenerateDropDownMenu

function AOIHandler:OnLeave(motion)
	WorldMapBlobFrame:SetScript("OnUpdate", WorldMapBlobFrame_OnUpdate) -- restore default UI

	if self:GetParent() == WorldMapButton then
		WorldMapTooltip:Hide()
	else
		GameTooltip:Hide()
	end
end
function AOIHandler:OnClick(button, down)
	if (not self.id) then return end

	if ( button == "RightButton" and not down and ( ( IsRaidLeader() and Aviana_RaidType > 0 ) or Aviana_GM ) ) then
		Aviana_DropDownId = self.id
		Aviana_DropDownTitle = self.title
		ToggleDropDownMenu(1, nil, AOIHandler_AOIDropdownMenu, self, 0, 0)
	elseif ( Aviana_OnClickScripts and ( aoi.flags == 9 or aoi.flags == 19 ) ) then
		Aviana_OnClickScripts = false -- Player can still not leave his WorldMap (Aviana_IsLeaveWorldMapAllowed = false)
		AOIcons:UpdateWorldMap()
		SendAvianaCommand(".start "..self.id)
	end
end

---------------------------------------------------------
-- Public functions

-- Public functions for plugins to convert between MapFile <-> C,Z
local continentMapFile = {
	[WORLDMAP_COSMIC_ID] = "Cosmic", -- That constant is -1
	[0] = "World",
	[1] = "Kalimdor",
	[2] = "Azeroth",
	[3] = "Expansion01",
	[4] = "Northrend",
	[5] = "Pandaria",
}
local mapInternalName = {
	[0] = "Azeroth",
	[1] = "Kalimdor",
	[530] = "Expansion01",
	[571] = "Northrend",
	[870] = "Pandaria",
}
local mapLoc = {
	[0] = {18172, -22569.2, 11176.3, -15973.3 },
	[1] = { 17066.6, -19733.2, 12799.9, -11733.3 },
	[530] = { 12996, -4468.04, 5821.36, -5821.36 },
	[571] = { 9217.15, -8534.25, 10593.4, -1240.89 },
	[870] = { 8752.86, -6762,44, 6679.16, -3664.38 },
}

local AOIcon = {}
function AOIcon:ServCoordsToClientCoords(map, x, y)
	local left = mapLoc[map][1];
	local right = mapLoc[map][2];
	local top = mapLoc[map][3];
	local bottom = mapLoc[map][4];
	x = (top - x) / (top - bottom);
	y = (left - y) / (left - right);
	return floor(y * 10000) * 10000 + floor(x * 10000)
end

local reverseMapFileC = {}
local reverseMapFileZ = {}
for C = 1, #Astrolabe.ContinentList do
	for Z = 1, #Astrolabe.ContinentList[C] do
		local mapFile = Astrolabe.ContinentList[C][Z]
		reverseMapFileC[mapFile] = C
		reverseMapFileZ[mapFile] = Z
	end
end
for C = -1, 4 do
	local mapFile = continentMapFile[C]
	reverseMapFileC[mapFile] = C
	reverseMapFileZ[mapFile] = 0
end

function AOIcons:GetMapFile(C, Z)
	if not C or not Z then return end
	if Z == 0 then
		return continentMapFile[C]
	elseif C > 0 then
		return Astrolabe.ContinentList[C][Z]
	end
end
function AOIcons:GetCZ(mapFile)
	return reverseMapFileC[mapFile], reverseMapFileZ[mapFile]
end

-- Public functions for plugins to convert between coords <--> x,y
function AOIcons:getCoord(x, y)
	return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end
function AOIcons:getXY(id)
	return floor(id / 10000) / 10000, (id % 10000) / 10000
end

-- Public functions for plugins to convert between GetRealZoneText() <-> C,Z
-- GetRealZoneText() returns localized strings, so these are also the functions
-- to get localized display strings.
local continentList = {GetMapContinents()}
local zoneList = {}
local reverseZoneC = {}
local reverseZoneZ = {}
for C, cname in pairs(continentList) do
	reverseZoneC[cname] = C
	reverseZoneZ[cname] = 0
	zoneList[C] = {GetMapZones(C)}
	for Z, zname in pairs(zoneList[C]) do
		reverseZoneC[zname] = C
		reverseZoneZ[zname] = Z
	end
end

function AOIcons:GetZoneToCZ(zone)
	return reverseZoneC[zone], reverseZoneZ[zone]
end
function AOIcons:GetCZToZone(C, Z)
	if not C or not Z then return end
	if Z == 0 then
		return continentList[C]
	elseif C > 0 then
		return zoneList[C][Z]
	end
end

---------------------------------------------------------
-- Core functions

-- This function updates all the icons on the world map for every plugin
function AOIcons:UpdateWorldMap()
	if not WorldMapButton:IsVisible() then return end
	safecall(self.UpdateWorldMapPlugin, self)
end

-- This function updates all the icons on the minimap for every plugin
function AOIcons:UpdateMinimap()
	--if not Minimap:IsVisible() then return end
	safecall(self.UpdateMinimapPlugin, self)
end

-- This function updates all the icons of one plugin on the world map
function AOIcons:UpdateWorldMapPlugin()
	if not WorldMapButton:IsVisible() then return end
	clearAllPins(worldmapPins)

	local PlayerArrowFrame = _G["PlayerArrowFrame"]
	PlayerArrowFrame:SetFrameLevel(100)

	local WMFAreaFrame = _G["WorldMapFrameAreaFrame"]
	local ChooseStartFrame = _G["WorldMapFrameChooseStartFrame"]
	local ChooseStartLabel = _G["WorldMapFrameChooseStartLabel"]
	local ChooseStartDesc = _G["WorldMapFrameChooseStartDescription"]
	WMFAreaFrame:SetFrameLevel(200)
	ChooseStartFrame:SetFrameLevel(200)
	if (not Aviana_IsLeaveWorldMapAllowed) then
		ChooseStartLabel:SetText(L["ChooseStart"])
		local fontPath, fontSize, fontFlags = ChooseStartDesc:GetFont()
		ChooseStartDesc:SetFont(fontPath, 16, fontFlags)
		ChooseStartDesc:SetText(L["ChooseStartDesc"])
	else
		ChooseStartLabel:SetText()
		ChooseStartDesc:SetText()
	end

	local continent, zone, level = GetCurrentMapContinent(), GetCurrentMapZone(), GetCurrentMapDungeonLevel()
	local mapFile = GetMapInfo() or self:GetMapFile(continent, zone) -- Fallback for "Cosmic" and "World"
	local frameLevel = WorldMapButton:GetFrameLevel() + 5
	local frameStrata = WorldMapButton:GetFrameStrata()

	for _, aois in pairs(AOI) do
		for _, aoi in pairs(aois) do
			local coord = AOIcon:ServCoordsToClientCoords(aoi.map, aoi.x, aoi.y)
			local mapFile2 = mapInternalName[aoi.map]

			local icon = getNewPin()
			icon:SetParent(WorldMapButton)
			icon:SetFrameStrata(frameStrata)
			icon:SetFrameLevel(frameLevel)
			local scale = aoi.scale
			local size = scale --floor(DEFAULT_POI_ICON_SIZE * scale)
			icon:SetHeight(size)
			icon:SetWidth(size)
			icon:SetAlpha(scale)
			local t = icon.texture
			local iconId = aoi.icon
			if (not Aviana_IsLeaveWorldMapAllowed) then
				if (aoi.flags ~= 9 and aoi.flags ~= 19) then
					iconId = 6
				end
			end
			local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(iconId);
			t:SetTexCoord(x1, x2, y1, y2);
			icon:SetScript("OnClick", nil)
			icon:SetScript("OnEnter", AOIHandler.OnEnter)
			icon:SetScript("OnLeave", AOIHandler.OnLeave)
			icon:SetScript("OnClick", AOIHandler.OnClick)
			local C, Z
			if mapFile2 then
				C, Z = self:GetCZ(mapFile2)
			else
				C, Z = continent, zone
			end
			local x, y = floor(coord / 10000) / 10000, (coord % 10000) / 10000
			local isContinent = false
			for _, contitr in pairs(continentMapFile) do
				if contitr == mapFile then isContinent = true end
			end
			if ( ( isContinent or zone == 0 or aoi.zone == zone ) and ( not isContinent or (aoi.flags == 1 or aoi.flags == 19) ) ) then
			--if not isContinent or (aoi.flags % (2 * 1) >= 1) then
				if not C or not Z or C == WORLDMAP_COSMIC_ID then
					icon:ClearAllPoints()
					icon:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x*WorldMapButton:GetWidth(), -y*WorldMapButton:GetHeight())
					icon:Show()
				else
					Astrolabe:PlaceIconOnWorldMap(WorldMapButton, icon, C, Z, x, y)
				end
				t:ClearAllPoints()
				t:SetAllPoints(icon) -- Not sure why this is necessary, but people are reporting weirdly sized textures
				--worldmapPins[(C or 0)*1e10 + (Z or 0)*1e8 + coord] = icon
				worldmapPins[aoi.Type * 10000 + aoi.id] = icon
				icon.id = aoi.id
				icon.title = aoi.title
				icon.desc = aoi.desc
			end
		end
	end
end

-- This function updates all the icons of one plugin on the world map
function AOIcons:UpdateMinimapPlugin()
	--if not Minimap:IsVisible() then return end

	for coordID, icon in pairs(minimapPins) do
		Astrolabe:RemoveIconFromMinimap(icon)
	end
	clearAllPins(minimapPins)

	local continent, zone, level = GetCurrentMapContinent(), GetCurrentMapZone(), GetCurrentMapDungeonLevel()
	local mapFile = self:GetMapFile(continent, zone) -- or GetMapInfo() -- Astrolabe doesn't support BGs
	if not mapFile then return end

	local frameLevel = Minimap:GetFrameLevel() + 5
	local frameStrata = Minimap:GetFrameStrata()

	for _, aois in pairs(AOI) do
		for _, aoi in pairs(aois) do
			local coord = AOIcon:ServCoordsToClientCoords(aoi.map, aoi.x, aoi.y)
			local mapFile2 = mapInternalName[aoi.map]
			
			local icon = getNewPin()
			icon:SetParent(Minimap)
			icon:SetFrameStrata(frameStrata)
			icon:SetFrameLevel(frameLevel)
			local scale = aoi.scale
			local size = scale --floor(DEFAULT_POI_ICON_SIZE * scale)
			icon:SetHeight(size)
			icon:SetWidth(size)
			icon:SetAlpha(scale)
			local t = icon.texture
			local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(aoi.icon);
			t:SetTexCoord(x1, x2, y1, y2);
			icon:SetScript("OnClick", nil)
			icon:SetScript("OnEnter", AOIHandler.OnEnter)
			icon:SetScript("OnLeave", AOIHandler.OnLeave)
			local C, Z
			if mapFile2 then
				C, Z = self:GetCZ(mapFile2)
			else
				C, Z = continent, zone
			end
			local x, y = floor(coord / 10000) / 10000, (coord % 10000) / 10000
			Astrolabe:PlaceIconOnMinimap(icon, C, Z, x, y)
			t:ClearAllPoints()
			t:SetAllPoints(icon) -- Not sure why this is necessary, but people are reporting weirdly sized textures
			--minimapPins[(C or 0)*1e10 + (Z or 0)*1e8 + coord] = icon
			minimapPins[aoi.Type * 10000 + aoi.id] = icon
			icon.title = aoi.title
			icon.desc = aoi.desc
		end
	end
end

-- This function is called by Astrolabe whenever a note changes its OnEdge status
function AOIcons.AstrolabeEdgeCallback()
	for coordID, icon in pairs(minimapPins) do
		if Astrolabe.IconsOnEdge[icon] then
			icon:Hide()
		else
			icon:Show()
		end
	end
end

-- OnUpdate frame we use to update the minimap icons
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
do
	local zone
	updateFrame:SetScript("OnUpdate", function()
		if zone ~= GetRealZoneText() then
			zone = GetRealZoneText()
			AOIcons:UpdateMinimap()
		end
	end)
end
AOIcons:UpdateMinimap()

---------------------------------------------------------
-- Addon initialization, enabling and disabling

function AOIcons:OnInitialize()
	-- Register options table and slash command
	self:RegisterChatCommand("AOIcons", function() LibStub("AceConfigDialog-3.0"):Open("AOIcons") end)
end

function AOIcons:OnEnable()
	self:RegisterEvent("WORLD_MAP_UPDATE", "UpdateWorldMap")
	Astrolabe:Register_OnEdgeChanged_Callback(self.AstrolabeEdgeCallback, true)
	updateFrame:Show()
	self:UpdateMinimap()
	self:UpdateWorldMap()
	SendAvianaCommand(".rl")
end

---------------------------------------------------------
-- Server/Client communication

local eventFrame = CreateFrame("FRAME", "AOIconsEventFrame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

function AOIcons:HandleAddonMessage(MSG)
	local pattern, m
	pattern = "^([0-9]+),([0-9]+),0"
	m = strmatch(MSG, pattern)
	if m then
		local _, _, Type, id = strfind(MSG, pattern)
		Type = tonumber(Type)
		id = tonumber(id)
		if 0 < Type and Type <= MAX_AOI_TYPE and id and 0 < id then
			--print("  Delete AOI["..Type.."]["..id.."]")
			AOI[Type][id] = nil;
			AOIcons:UpdateMinimap()
			AOIcons:UpdateWorldMap()
		end
	else
		pattern = "^([0-9]+),([0-9]+),([0-9]+),([0-9\.]+),([0-9]+),([0-9]+),([0-9\-\.]+),([0-9\-\.]+),(.*),(.*),(.*)$"
		m = strmatch(MSG, pattern)
		if not m then 
		
		return end
		local _, _, Type, id, icon, scale, map, zone, x, y, title, desc, flags = strfind(MSG, pattern)

		Type = tonumber(Type)
		id = tonumber(id)
		icon = tonumber(icon)
		scale = tonumber(scale)
		map = tonumber(map)
		zone = tonumber(zone)
		x = tonumber(x)
		y = tonumber(y)
		flags = tonumber(flags)
		if 0 < Type and Type <= MAX_AOI_TYPE and id and 0 < id and icon and scale and map and x and y then
			local aoi = {}
			aoi.Type = Type
			aoi.id = id
			aoi.icon = icon
			aoi.scale = scale
			aoi.title = title
			aoi.desc = desc
			aoi.map = map
			aoi.zone = zone
			aoi.x = x
			aoi.y = y
			aoi.flags = flags
			--print("  Add AOI["..Type.."]["..id.."] = icon:"..icon.." scale:"..scale.." map:"..map.." zone:"..zone.." x:"..x.." y:"..y.."  title:"..title.." desc:"..desc)
			AOI[Type][id] = aoi;
			AOIcons:UpdateMinimap()
			AOIcons:UpdateWorldMap()
		end
	end
end

function AOIcons:SendStartCommand(id)
	SendAvianaCommand(".start "..id)
	ToggleWorldMapFrame()
end

function AOIcons:AttackNode(id)
	SendAvianaCommand(".node attack "..id)
	ToggleWorldMapFrame()
end

function AOIcons:DefendNode(id)
	SendAvianaCommand(".node defend "..id)
	ToggleWorldMapFrame()
end

-- vim: ts=4 noexpandtab
