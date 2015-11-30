--[[
Name: Astrolabe
Revision: $Rev: 107 $
$Date: 2009-08-05 00:34:29 -0700 (Wed, 05 Aug 2009) $
Author(s): Esamynn (esamynn at wowinterface.com)
Inspired By: Gatherer by Norganna
             MapLibrary by Kristofer Karlsson (krka at kth.se)
Documentation: http://wiki.esamynn.org/Astrolabe
SVN: http://svn.esamynn.org/astrolabe/
Description:
	This is a library for the World of Warcraft UI system to place
	icons accurately on both the Minimap and on Worldmaps.  
	This library also manages and updates the position of Minimap icons 
	automatically.  

Copyright (C) 2006-2008 James Carrothers

License:
	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

Note:
	This library's source code is specifically designed to work with
	World of Warcraft's interpreted AddOn system.  You have an implicit
	licence to use this library with these facilities since that is its
	designated purpose as per:
	http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]]

-- WARNING!!!
-- DO NOT MAKE CHANGES TO THIS LIBRARY WITHOUT FIRST CHANGING THE LIBRARY_VERSION_MAJOR
-- STRING (to something unique) OR ELSE YOU MAY BREAK OTHER ADDONS THAT USE THIS LIBRARY!!!
local LIBRARY_VERSION_MAJOR = "Astrolabe-0.4"
local LIBRARY_VERSION_MINOR = tonumber(string.match("$Revision: 107 $", "(%d+)") or 1)

if not DongleStub then error(LIBRARY_VERSION_MAJOR .. " requires DongleStub.") end
if not DongleStub:IsNewerVersion(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR) then return end

local Astrolabe = {};

-- define local variables for Data Tables (defined at the end of this file)
local WorldMapSize, MinimapSize, ValidMinimapShapes;

function Astrolabe:GetVersion()
	return LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR;
end


--------------------------------------------------------------------------------------------------------------
-- Config Constants
--------------------------------------------------------------------------------------------------------------

local configConstants = { 
	MinimapUpdateMultiplier = true, 
}

-- this constant is multiplied by the current framerate to determine
-- how many icons are updated each frame
Astrolabe.MinimapUpdateMultiplier = 1;


--------------------------------------------------------------------------------------------------------------
-- Working Tables
--------------------------------------------------------------------------------------------------------------

Astrolabe.LastPlayerPosition = { 0, 0, 0, 0 };
Astrolabe.MinimapIcons = {};
Astrolabe.IconsOnEdge = {};
Astrolabe.IconsOnEdge_GroupChangeCallbacks = {};

Astrolabe.MinimapIconCount = 0
Astrolabe.ForceNextUpdate = false;
Astrolabe.IconsOnEdgeChanged = false;

-- This variable indicates whether we know of a visible World Map or not.  
-- The state of this variable is controlled by the AstrolabeMapMonitor library.  
Astrolabe.WorldMapVisible = false;

local AddedOrUpdatedIcons = {}
local MinimapIconsMetatable = { __index = AddedOrUpdatedIcons }


--------------------------------------------------------------------------------------------------------------
-- Local Pointers for often used API functions
--------------------------------------------------------------------------------------------------------------

local twoPi = math.pi * 2;
local atan2 = math.atan2;
local sin = math.sin;
local cos = math.cos;
local abs = math.abs;
local sqrt = math.sqrt;
local min = math.min
local max = math.max
local yield = coroutine.yield
local next = next
local GetFramerate = GetFramerate


--------------------------------------------------------------------------------------------------------------
-- Internal Utility Functions
--------------------------------------------------------------------------------------------------------------

local function assert(level,condition,message)
	if not condition then
		error(message,level)
	end
end

local function argcheck(value, num, ...)
	assert(1, type(num) == "number", "Bad argument #2 to 'argcheck' (number expected, got " .. type(level) .. ")")
	
	for i=1,select("#", ...) do
		if type(value) == select(i, ...) then return end
	end
	
	local types = strjoin(", ", ...)
	local name = string.match(debugstack(2,2,0), ": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to 'Astrolabe.%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

local function getContPosition( zoneData, z, x, y )
	if ( z ~= 0 ) then
		zoneData = zoneData[z];
		x = x * zoneData.width + zoneData.xOffset;
		y = y * zoneData.height + zoneData.yOffset;
	else
		x = x * zoneData.width;
		y = y * zoneData.height;
	end
	return x, y;
end


--------------------------------------------------------------------------------------------------------------
-- General Utility Functions
--------------------------------------------------------------------------------------------------------------

function Astrolabe:ComputeDistance( c1, z1, x1, y1, c2, z2, x2, y2 )
	--[[
	argcheck(c1, 2, "number");
	assert(3, c1 >= 0, "ComputeDistance: Illegal continent index to c1: "..c1);
	argcheck(z1, 3, "number", "nil");
	argcheck(x1, 4, "number");
	argcheck(y1, 5, "number");
	argcheck(c2, 6, "number");
	assert(3, c2 >= 0, "ComputeDistance: Illegal continent index to c2: "..c2);
	argcheck(z2, 7, "number", "nil");
	argcheck(x2, 8, "number");
	argcheck(y2, 9, "number");
	--]]
	
	z1 = z1 or 0;
	z2 = z2 or 0;
	
	local dist, xDelta, yDelta;
	if ( c1 == c2 and z1 == z2 ) then
		-- points in the same zone
		local zoneData = WorldMapSize[c1];
		if ( z1 ~= 0 ) then
			zoneData = zoneData[z1];
		end
		xDelta = (x2 - x1) * zoneData.width;
		yDelta = (y2 - y1) * zoneData.height;
	
	elseif ( c1 == c2 ) then
		-- points on the same continent
		local zoneData = WorldMapSize[c1];
		x1, y1 = getContPosition(zoneData, z1, x1, y1);
		x2, y2 = getContPosition(zoneData, z2, x2, y2);
		xDelta = (x2 - x1);
		yDelta = (y2 - y1);
	
	elseif ( c1 and c2 ) then
		local cont1 = WorldMapSize[c1];
		local cont2 = WorldMapSize[c2];
		if ( cont1.parentContinent == cont2.parentContinent ) then
			x1, y1 = getContPosition(cont1, z1, x1, y1);
			x2, y2 = getContPosition(cont2, z2, x2, y2);
			if ( c1 ~= cont1.parentContinent ) then
				x1 = x1 + cont1.xOffset;
				y1 = y1 + cont1.yOffset;
			end
			if ( c2 ~= cont2.parentContinent ) then
				x2 = x2 + cont2.xOffset;
				y2 = y2 + cont2.yOffset;
			end
			
			xDelta = x2 - x1;
			yDelta = y2 - y1;
		end
	
	end
	if ( xDelta and yDelta ) then
		dist = sqrt(xDelta*xDelta + yDelta*yDelta);
	end
	return dist, xDelta, yDelta;
end

function Astrolabe:TranslateWorldMapPosition( C, Z, xPos, yPos, nC, nZ )
	--[[
	argcheck(C, 2, "number");
	argcheck(Z, 3, "number", "nil");
	argcheck(xPos, 4, "number");
	argcheck(yPos, 5, "number");
	argcheck(nC, 6, "number");
	argcheck(nZ, 7, "number", "nil");
	--]]
	
	Z = Z or 0;
	nZ = nZ or 0;
	if ( nC < 0 ) then
		return;
	end
	
	local zoneData;
	if ( C == nC and Z == nZ ) then
		return xPos, yPos;
	
	elseif ( C == nC ) then
		-- points on the same continent
		zoneData = WorldMapSize[C];
		xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
		if ( nZ ~= 0 ) then
			zoneData = WorldMapSize[C][nZ];
			xPos = xPos - zoneData.xOffset;
			yPos = yPos - zoneData.yOffset;
		end
	
	elseif ( C and nC ) and ( WorldMapSize[C].parentContinent == WorldMapSize[nC].parentContinent ) then
		-- different continents, same world
		zoneData = WorldMapSize[C];
		local parentContinent = zoneData.parentContinent;
		xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
		if ( C ~= parentContinent ) then
			-- translate up to world map if we aren't there already
			xPos = xPos + zoneData.xOffset;
			yPos = yPos + zoneData.yOffset;
			zoneData = WorldMapSize[parentContinent];
		end
		if ( nC ~= parentContinent ) then
			-- translate down to the new continent
			zoneData = WorldMapSize[nC];
			xPos = xPos - zoneData.xOffset;
			yPos = yPos - zoneData.yOffset;
			if ( nZ ~= 0 ) then
				zoneData = zoneData[nZ];
				xPos = xPos - zoneData.xOffset;
				yPos = yPos - zoneData.yOffset;
			end
		end
	
	else
		return;
	end
	
	return (xPos / zoneData.width), (yPos / zoneData.height);
end

--*****************************************************************************
-- This function will do its utmost to retrieve some sort of valid position 
-- for the specified unit, including changing the current map zoom (if needed).  
-- Map Zoom is returned to its previous setting before this function returns.  
--*****************************************************************************
function Astrolabe:GetUnitPosition( unit, noMapChange )
	local x, y = GetPlayerMapPosition(unit);
	if ( x <= 0 and y <= 0 ) then
		if ( noMapChange ) then
			-- no valid position on the current map, and we aren't allowed
			-- to change map zoom, so return
			return;
		end
		local lastCont, lastZone = GetCurrentMapContinent(), GetCurrentMapZone();
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition(unit);
		if ( x <= 0 and y <= 0 ) then
			SetMapZoom(GetCurrentMapContinent());
			x, y = GetPlayerMapPosition(unit);
			if ( x <= 0 and y <= 0 ) then
				-- we are in an instance or otherwise off the continent map
				return;
			end
		end
		local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
		if ( C ~= lastCont or Z ~= lastZone ) then
			SetMapZoom(lastCont, lastZone); -- set map zoom back to what it was before
		end
		return C, Z, x, y;
	end
	return GetCurrentMapContinent(), GetCurrentMapZone(), x, y;
end

--*****************************************************************************
-- This function will do its utmost to retrieve some sort of valid position 
-- for the specified unit, including changing the current map zoom (if needed).  
-- However, if a monitored WorldMapFrame (See AstrolabeMapMonitor.lua) is 
-- visible, then will simply return nil if the current zoom does not provide 
-- a valid position for the player unit.  Map Zoom is returned to its previous 
-- setting before this function returns, if it was changed.  
--*****************************************************************************
function Astrolabe:GetCurrentPlayerPosition()
	local x, y = GetPlayerMapPosition("player");
	if ( x <= 0 and y <= 0 ) then
		if ( self.WorldMapVisible ) then
			-- we know there is a visible world map, so don't cause 
			-- WORLD_MAP_UPDATE events by changing map zoom
			return;
		end
		local lastCont, lastZone = GetCurrentMapContinent(), GetCurrentMapZone();
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition("player");
		if ( x <= 0 and y <= 0 ) then
			SetMapZoom(GetCurrentMapContinent());
			x, y = GetPlayerMapPosition("player");
			if ( x <= 0 and y <= 0 ) then
				-- we are in an instance or otherwise off the continent map
				return;
			end
		end
		local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
		if ( C ~= lastCont or Z ~= lastZone ) then
			SetMapZoom(lastCont, lastZone); --set map zoom back to what it was before
		end
		return C, Z, x, y;
	end
	return GetCurrentMapContinent(), GetCurrentMapZone(), x, y;
end


--------------------------------------------------------------------------------------------------------------
-- Working Table Cache System
--------------------------------------------------------------------------------------------------------------

local tableCache = {};
tableCache["__mode"] = "v";
setmetatable(tableCache, tableCache);

local function GetWorkingTable( icon )
	if ( tableCache[icon] ) then
		return tableCache[icon];
	else
		local T = {};
		tableCache[icon] = T;
		return T;
	end
end


--------------------------------------------------------------------------------------------------------------
-- Minimap Icon Placement
--------------------------------------------------------------------------------------------------------------

--*****************************************************************************
-- local variables specifically for use in this section
--*****************************************************************************
local minimapRotationEnabled = false;
local minimapShape = false;

local minimapRotationOffset = GetPlayerFacing();


local function placeIconOnMinimap( minimap, minimapZoom, mapWidth, mapHeight, icon, dist, xDist, yDist )
	local mapDiameter;
	if ( Astrolabe.minimapOutside ) then
		mapDiameter = MinimapSize.outdoor[minimapZoom];
	else
		mapDiameter = MinimapSize.indoor[minimapZoom];
	end
	local mapRadius = mapDiameter / 2;
	local xScale = mapDiameter / mapWidth;
	local yScale = mapDiameter / mapHeight;
	local iconDiameter = ((icon:GetWidth() / 2) + 3) * xScale;
	local iconOnEdge = nil;
	local isRound = true;
	
	if ( minimapRotationEnabled ) then
		local sinTheta = sin(minimapRotationOffset)
		local cosTheta = cos(minimapRotationOffset)
		--[[
		Math Note
		The math that is acutally going on in the next 3 lines is:
			local dx, dy = xDist, -yDist
			xDist = (dx * cosTheta) + (dy * sinTheta)
			yDist = -((-dx * sinTheta) + (dy * cosTheta))
		
		This is because the origin for map coordinates is the top left corner
		of the map, not the bottom left, and so we have to reverse the vertical 
		distance when doing the our rotation, and then reverse the result vertical 
		distance because this rotation formula gives us a result with the origin based 
		in the bottom left corner (of the (+, +) quadrant).  
		The actual code is a simplification of the above.  
		]]
		local dx, dy = xDist, yDist
		xDist = (dx * cosTheta) - (dy * sinTheta)
		yDist = (dx * sinTheta) + (dy * cosTheta)
	end
	
	if ( minimapShape and not (xDist == 0 or yDist == 0) ) then
		isRound = (xDist < 0) and 1 or 3;
		if ( yDist < 0 ) then
			isRound = minimapShape[isRound];
		else
			isRound = minimapShape[isRound + 1];
		end
	end
	
	-- for non-circular portions of the Minimap edge
	if not ( isRound ) then
		dist = max(abs(xDist), abs(yDist))
	end

	if ( (dist + iconDiameter) > mapRadius ) then
		-- position along the outside of the Minimap
		iconOnEdge = true;
		local factor = (mapRadius - iconDiameter) / dist;
		xDist = xDist * factor;
		yDist = yDist * factor;
	end
	
	if ( Astrolabe.IconsOnEdge[icon] ~= iconOnEdge ) then
		Astrolabe.IconsOnEdge[icon] = iconOnEdge;
		Astrolabe.IconsOnEdgeChanged = true;
	end
	
	icon:ClearAllPoints();
	icon:SetPoint("CENTER", minimap, "CENTER", xDist/xScale, -yDist/yScale);
end

function Astrolabe:PlaceIconOnMinimap( icon, continent, zone, xPos, yPos )
	-- check argument types
	argcheck(icon, 2, "table");
	assert(3, icon.SetPoint and icon.ClearAllPoints, "Usage Message");
	argcheck(continent, 3, "number");
	argcheck(zone, 4, "number", "nil");
	argcheck(xPos, 5, "number");
	argcheck(yPos, 6, "number");
	
	-- if the positining system is currently active, just use the player position used by the last incremental (or full) update
	-- otherwise, make sure we base our calculations off of the most recent player position (if one is available)
	local lC, lZ, lx, ly;
	if ( self.processingFrame:IsShown() ) then
		lC, lZ, lx, ly = unpack(self.LastPlayerPosition);
	else
		lC, lZ, lx, ly = self:GetCurrentPlayerPosition();
		if ( lC and lC >= 0 ) then
			local lastPosition = self.LastPlayerPosition;
			lastPosition[1] = lC;
			lastPosition[2] = lZ;
			lastPosition[3] = lx;
			lastPosition[4] = ly;
		else
			lC, lZ, lx, ly = unpack(self.LastPlayerPosition);
		end
	end
	
	local dist, xDist, yDist = self:ComputeDistance(lC, lZ, lx, ly, continent, zone, xPos, yPos);
	if not ( dist ) then
		--icon's position has no meaningful position relative to the player's current location
		return -1;
	end
	
	local iconData = GetWorkingTable(icon);
	if ( self.MinimapIcons[icon] ) then
		self.MinimapIcons[icon] = nil;
	else
		self.MinimapIconCount = self.MinimapIconCount + 1
	end
	
	AddedOrUpdatedIcons[icon] = iconData
	iconData.continent = continent;
	iconData.zone = zone;
	iconData.xPos = xPos;
	iconData.yPos = yPos;
	iconData.dist = dist;
	iconData.xDist = xDist;
	iconData.yDist = yDist;
	
	minimapRotationEnabled = GetCVar("rotateMinimap") ~= "0"
	if ( minimapRotationEnabled ) then
		minimapRotationOffset = GetPlayerFacing();
	end
	
	-- check Minimap Shape
	minimapShape = GetMinimapShape and ValidMinimapShapes[GetMinimapShape()];
	
	-- place the icon on the Minimap and :Show() it
	local map = Minimap
	placeIconOnMinimap(map, map:GetZoom(), map:GetWidth(), map:GetHeight(), icon, dist, xDist, yDist);
	icon:Show()
	
	-- We know this icon's position is valid, so we need to make sure the icon placement system is active.  
	self.processingFrame:Show()
	
	return 0;
end

function Astrolabe:RemoveIconFromMinimap( icon )
	if not ( self.MinimapIcons[icon] ) then
		return 1;
	end
	AddedOrUpdatedIcons[icon] = nil
	self.MinimapIcons[icon] = nil;
	self.IconsOnEdge[icon] = nil;
	icon:Hide();
	
	local MinimapIconCount = self.MinimapIconCount - 1
	if ( MinimapIconCount <= 0 ) then
		-- no icons left to manage
		self.processingFrame:Hide()
		MinimapIconCount = 0 -- because I'm paranoid
	end
	self.MinimapIconCount = MinimapIconCount
	
	return 0;
end

function Astrolabe:RemoveAllMinimapIcons()
	self:DumpNewIconsCache()
	local MinimapIcons = self.MinimapIcons;
	local IconsOnEdge = self.IconsOnEdge;
	for k, v in pairs(MinimapIcons) do
		MinimapIcons[k] = nil;
		IconsOnEdge[k] = nil;
		k:Hide();
	end
	self.MinimapIconCount = 0
	self.processingFrame:Hide()
end

local lastZoom; -- to remember the last seen Minimap zoom level

-- local variables to track the status of the two update coroutines
local fullUpdateInProgress = true
local resetIncrementalUpdate = false
local resetFullUpdate = false

-- Incremental Update Code
do
	-- local variables to track the incremental update coroutine
	local incrementalUpdateCrashed = true
	local incrementalUpdateThread
	
	local function UpdateMinimapIconPositions( self )
		yield()
		
		while ( true ) do
			self:DumpNewIconsCache() -- put new/updated icons into the main datacache
			
			resetIncrementalUpdate = false -- by definition, the incremental update is reset if it is here
			
			local C, Z, x, y = self:GetCurrentPlayerPosition();
			if ( C and C >= 0 ) then
				local Minimap = Minimap;
				local lastPosition = self.LastPlayerPosition;
				local lC, lZ, lx, ly = unpack(lastPosition);
				
				minimapRotationEnabled = GetCVar("rotateMinimap") ~= "0"
				if ( minimapRotationEnabled ) then
					minimapRotationOffset = GetPlayerFacing();
				end
				
				-- check current frame rate
				local numPerCycle = min(50, GetFramerate() * (self.MinimapUpdateMultiplier or 1))
				
				-- check Minimap Shape
				minimapShape = GetMinimapShape and ValidMinimapShapes[GetMinimapShape()];
				
				if ( lC == C and lZ == Z and lx == x and ly == y ) then
					-- player has not moved since the last update
					if ( lastZoom ~= Minimap:GetZoom() or self.ForceNextUpdate or minimapRotationEnabled ) then
						local currentZoom = Minimap:GetZoom();
						lastZoom = currentZoom;
						local mapWidth = Minimap:GetWidth();
						local mapHeight = Minimap:GetHeight();
						numPerCycle = numPerCycle * 2
						local count = 0
						for icon, data in pairs(self.MinimapIcons) do
							placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, data.dist, data.xDist, data.yDist);
							
							count = count + 1
							if ( count > numPerCycle ) then
								count = 0
								yield()
								-- check if the incremental update cycle needs to be reset 
								-- because a full update has been run
								if ( resetIncrementalUpdate ) then
									break;
								end
							end
						end
						self.ForceNextUpdate = false;
					end
				else
					local dist, xDelta, yDelta = self:ComputeDistance(lC, lZ, lx, ly, C, Z, x, y);
					if ( dist ) then
						local currentZoom = Minimap:GetZoom();
						lastZoom = currentZoom;
						local mapWidth = Minimap:GetWidth();
						local mapHeight = Minimap:GetHeight();
						local count = 0
						for icon, data in pairs(self.MinimapIcons) do
							local xDist = data.xDist - xDelta;
							local yDist = data.yDist - yDelta;
							local dist = sqrt(xDist*xDist + yDist*yDist);
							placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, dist, xDist, yDist);
							
							data.dist = dist;
							data.xDist = xDist;
							data.yDist = yDist;
							
							count = count + 1
							if ( count >= numPerCycle ) then
								count = 0
								yield()
								-- check if the incremental update cycle needs to be reset 
								-- because a full update has been run
								if ( resetIncrementalUpdate ) then
									break;
								end
							end
						end
						if not ( resetIncrementalUpdate ) then
							lastPosition[1] = C;
							lastPosition[2] = Z;
							lastPosition[3] = x;
							lastPosition[4] = y;
						end
					else
						self:RemoveAllMinimapIcons()
						lastPosition[1] = C;
						lastPosition[2] = Z;
						lastPosition[3] = x;
						lastPosition[4] = y;
					end
				end
			else
				if not ( self.WorldMapVisible ) then
					self.processingFrame:Hide();
				end
			end
			
			-- if we've been reset, then we want to start the new cycle immediately
			if not ( resetIncrementalUpdate ) then
				yield()
			end
		end
	end
	
	function Astrolabe:UpdateMinimapIconPositions()
		if ( fullUpdateInProgress ) then
			-- if we're in the middle a a full update, we want to finish that first
			self:CalculateMinimapIconPositions()
		else
			if ( incrementalUpdateCrashed ) then
				incrementalUpdateThread = coroutine.wrap(UpdateMinimapIconPositions)
				incrementalUpdateThread(self) --initialize the thread
			end
			incrementalUpdateCrashed = true
			incrementalUpdateThread()
			incrementalUpdateCrashed = false
		end
	end
end

-- Full Update Code
do
	-- local variables to track the full update coroutine
	local fullUpdateCrashed = true
	local fullUpdateThread
	
	local function CalculateMinimapIconPositions( self )
		yield()
		
		while ( true ) do
			self:DumpNewIconsCache() -- put new/updated icons into the main datacache
			
			resetFullUpdate = false -- by definition, the full update is reset if it is here
			fullUpdateInProgress = true -- set the flag the says a full update is in progress
			
			local C, Z, x, y = self:GetCurrentPlayerPosition();
			if ( C and C >= 0 ) then
				minimapRotationEnabled = GetCVar("rotateMinimap") ~= "0"
				if ( minimapRotationEnabled ) then
					minimapRotationOffset = GetPlayerFacing();
				end
				
				-- check current frame rate
				local numPerCycle = GetFramerate() * (self.MinimapUpdateMultiplier or 1) * 2
				
				-- check Minimap Shape
				minimapShape = GetMinimapShape and ValidMinimapShapes[GetMinimapShape()];
				
				local currentZoom = Minimap:GetZoom();
				lastZoom = currentZoom;
				local Minimap = Minimap;
				local mapWidth = Minimap:GetWidth();
				local mapHeight = Minimap:GetHeight();
				local count = 0
				for icon, data in pairs(self.MinimapIcons) do
					local dist, xDist, yDist = self:ComputeDistance(C, Z, x, y, data.continent, data.zone, data.xPos, data.yPos);
					if ( dist ) then
						placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, dist, xDist, yDist);
						
						data.dist = dist;
						data.xDist = xDist;
						data.yDist = yDist;
					else
						self:RemoveIconFromMinimap(icon)
					end
					
					count = count + 1
					if ( count >= numPerCycle ) then
						count = 0
						yield()
						-- check if we need to restart due to the full update being reset
						if ( resetFullUpdate ) then
							break;
						end
					end
				end
				
				if not ( resetFullUpdate ) then
					local lastPosition = self.LastPlayerPosition;
					lastPosition[1] = C;
					lastPosition[2] = Z;
					lastPosition[3] = x;
					lastPosition[4] = y;
					
					resetIncrementalUpdate = true
				end
			else
				if not ( self.WorldMapVisible ) then
					self.processingFrame:Hide();
				end
			end
			
			-- if we've been reset, then we want to start the new cycle immediately
			if not ( resetFullUpdate ) then
				fullUpdateInProgress = false
				yield()
			end
		end
	end
	
	function Astrolabe:CalculateMinimapIconPositions( reset )
		if ( fullUpdateCrashed ) then
			fullUpdateThread = coroutine.wrap(CalculateMinimapIconPositions)
			fullUpdateThread(self) --initialize the thread
		elseif ( reset ) then
			resetFullUpdate = true
		end
		fullUpdateCrashed = true
		fullUpdateThread()
		fullUpdateCrashed = false
		
		-- return result flag
		if ( fullUpdateInProgress ) then
			return 1 -- full update started, but did not complete on this cycle
		
		else
			if ( resetIncrementalUpdate ) then
				return 0 -- update completed
			else
				return -1 -- full update did no occur for some reason
			end
		
		end
	end
end

function Astrolabe:GetDistanceToIcon( icon )
	local data = self.MinimapIcons[icon];
	if ( data ) then
		return data.dist, data.xDist, data.yDist;
	end
end

function Astrolabe:IsIconOnEdge( icon )
	return self.IconsOnEdge[icon];
end

function Astrolabe:GetDirectionToIcon( icon )
	local data = self.MinimapIcons[icon];
	if ( data ) then
		local dir = atan2(data.xDist, -(data.yDist))
		if ( dir > 0 ) then
			return twoPi - dir;
		else
			return -dir;
		end
	end
end

function Astrolabe:Register_OnEdgeChanged_Callback( func, ident )
	-- check argument types
	argcheck(func, 2, "function");
	
	self.IconsOnEdge_GroupChangeCallbacks[func] = ident;
end

--*****************************************************************************
-- INTERNAL USE ONLY PLEASE!!!
-- Calling this function at the wrong time can cause errors
--*****************************************************************************
function Astrolabe:DumpNewIconsCache()
	local MinimapIcons = self.MinimapIcons
	for icon, data in pairs(AddedOrUpdatedIcons) do
		MinimapIcons[icon] = data
		AddedOrUpdatedIcons[icon] = nil
	end
	-- we now need to restart any updates that were in progress
	resetIncrementalUpdate = true
	resetFullUpdate = true
end


--------------------------------------------------------------------------------------------------------------
-- World Map Icon Placement
--------------------------------------------------------------------------------------------------------------

function Astrolabe:PlaceIconOnWorldMap( worldMapFrame, icon, continent, zone, xPos, yPos )
	-- check argument types
	argcheck(worldMapFrame, 2, "table");
	assert(3, worldMapFrame.GetWidth and worldMapFrame.GetHeight, "Usage Message");
	argcheck(icon, 3, "table");
	assert(3, icon.SetPoint and icon.ClearAllPoints, "Usage Message");
	argcheck(continent, 4, "number");
	argcheck(zone, 5, "number", "nil");
	argcheck(xPos, 6, "number");
	argcheck(yPos, 7, "number");
	
	local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
	local nX, nY = self:TranslateWorldMapPosition(continent, zone, xPos, yPos, C, Z);
	
	-- anchor and :Show() the icon if it is within the boundry of the current map, :Hide() it otherwise
	if ( nX and nY and (0 < nX and nX <= 1) and (0 < nY and nY <= 1) ) then
		icon:ClearAllPoints();
		icon:SetPoint("CENTER", worldMapFrame, "TOPLEFT", nX * worldMapFrame:GetWidth(), -nY * worldMapFrame:GetHeight());
		icon:Show();
	else
		icon:Hide();
	end
	return nX, nY;
end


--------------------------------------------------------------------------------------------------------------
-- Handler Scripts
--------------------------------------------------------------------------------------------------------------

function Astrolabe:OnEvent( frame, event )
	if ( event == "MINIMAP_UPDATE_ZOOM" ) then
		-- update minimap zoom scale
		local Minimap = Minimap;
		local curZoom = Minimap:GetZoom();
		if ( GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") ) then
			if ( curZoom < 2 ) then
				Minimap:SetZoom(curZoom + 1);
			else
				Minimap:SetZoom(curZoom - 1);
			end
		end
		if ( GetCVar("minimapZoom")+0 == Minimap:GetZoom() ) then
			self.minimapOutside = true;
		else
			self.minimapOutside = false;
		end
		Minimap:SetZoom(curZoom);
		
		-- re-calculate all Minimap Icon positions
		if ( frame:IsVisible() ) then
			self:CalculateMinimapIconPositions(true);
		end
	
	elseif ( event == "PLAYER_LEAVING_WORLD" ) then
		frame:Hide(); -- yes, I know this is redunant
		self:RemoveAllMinimapIcons(); --dump all minimap icons
		-- TODO: when I uncouple the point buffer from Minimap drawing,
		--       I should consider updating LastPlayerPosition here
	
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		frame:Show();
		if not ( frame:IsVisible() ) then
			-- do the minimap recalculation anyways if the OnShow script didn't execute
			-- this is done to ensure the accuracy of information about icons that were 
			-- inserted while the Player was in the process of zoning
			self:CalculateMinimapIconPositions(true);
		end
	
	elseif ( event == "ZONE_CHANGED_NEW_AREA" ) then
		frame:Hide();
		frame:Show();
	
	end
end

function Astrolabe:OnUpdate( frame, elapsed )
	-- on-edge group changed call-backs
	if ( self.IconsOnEdgeChanged ) then
		self.IconsOnEdgeChanged = false;
		for func in pairs(self.IconsOnEdge_GroupChangeCallbacks) do
			pcall(func);
		end
	end
	
	self:UpdateMinimapIconPositions();
end

function Astrolabe:OnShow( frame )
	-- set the world map to a zoom with a valid player position
	if not ( self.WorldMapVisible ) then
		SetMapToCurrentZone();
	end
	local C, Z = Astrolabe:GetCurrentPlayerPosition();
	if ( C and C >= 0 ) then
		SetMapZoom(C, Z);
	else
		frame:Hide();
		return
	end
	
	-- re-calculate minimap icon positions (if needed)
	if ( next(self.MinimapIcons) ) then
		self:CalculateMinimapIconPositions(true);
	else
		-- needed so that the cycle doesn't overwrite an updated LastPlayerPosition
		resetIncrementalUpdate = true;
	end
	
	if ( self.MinimapIconCount <= 0 ) then
		-- no icons left to manage
		frame:Hide();
	end
end

function Astrolabe:OnHide( frame )
	-- dump the new icons cache here
	-- a full update will performed the next time processing is re-actived
	self:DumpNewIconsCache()
end

-- called by AstrolabMapMonitor when all world maps are hidden
function Astrolabe:AllWorldMapsHidden()
	if ( IsLoggedIn() ) then
		self.processingFrame:Hide();
		self.processingFrame:Show();
	end
end


--------------------------------------------------------------------------------------------------------------
-- Library Registration
--------------------------------------------------------------------------------------------------------------

local function activate( newInstance, oldInstance )
	if ( oldInstance ) then -- this is an upgrade activate
		if ( oldInstance.DumpNewIconsCache ) then
			oldInstance:DumpNewIconsCache()
		end
		for k, v in pairs(oldInstance) do
			if ( type(v) ~= "function" and (not configConstants[k]) ) then
				newInstance[k] = v;
			end
		end
		-- sync up the current MinimapIconCount value
		local iconCount = 0
		for _ in pairs(newInstance.MinimapIcons) do
			iconCount = iconCount + 1
		end
		newInstance.MinimapIconCount = iconCount
		
		Astrolabe = oldInstance;
	else
		local frame = CreateFrame("Frame");
		newInstance.processingFrame = frame;
		
		newInstance.ContinentList = { GetMapContinents() };
		for C in pairs(newInstance.ContinentList) do
			local zones = { GetMapZones(C) };
			newInstance.ContinentList[C] = zones;
			for Z in ipairs(zones) do
				SetMapZoom(C, Z);
				zones[Z] = GetMapInfo();
			end
		end
	end
	configConstants = nil -- we don't need this anymore
	
	local frame = newInstance.processingFrame;
	frame:Hide();
	frame:SetParent("Minimap");
	frame:UnregisterAllEvents();
	frame:RegisterEvent("MINIMAP_UPDATE_ZOOM");
	frame:RegisterEvent("PLAYER_LEAVING_WORLD");
	frame:RegisterEvent("PLAYER_ENTERING_WORLD");
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	frame:SetScript("OnEvent",
		function( frame, event, ... )
			Astrolabe:OnEvent(frame, event, ...);
		end
	);
	frame:SetScript("OnUpdate",
		function( frame, elapsed )
			Astrolabe:OnUpdate(frame, elapsed);
		end
	);
	frame:SetScript("OnShow",
		function( frame )
			Astrolabe:OnShow(frame);
		end
	);
	frame:SetScript("OnHide",
		function( frame )
			Astrolabe:OnHide(frame);
		end
	);
	
	setmetatable(Astrolabe.MinimapIcons, MinimapIconsMetatable)
end

DongleStub:Register(Astrolabe, activate)


--------------------------------------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------------------------------------

-- diameter of the Minimap in game yards at
-- the various possible zoom levels
MinimapSize = {
	indoor = {
		[0] = 300, -- scale
		[1] = 240, -- 1.25
		[2] = 180, -- 5/3
		[3] = 120, -- 2.5
		[4] = 80,  -- 3.75
		[5] = 50,  -- 6
	},
	outdoor = {
		[0] = 466 + 2/3, -- scale
		[1] = 400,       -- 7/6
		[2] = 333 + 1/3, -- 1.4
		[3] = 266 + 2/6, -- 1.75
		[4] = 200,       -- 7/3
		[5] = 133 + 1/3, -- 3.5
	},
}

ValidMinimapShapes = {
	-- { upper-left, lower-left, upper-right, lower-right }
	["SQUARE"]                = { false, false, false, false },
	["CORNER-TOPLEFT"]        = { true,  false, false, false },
	["CORNER-TOPRIGHT"]       = { false, false, true,  false },
	["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
	["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
	["SIDE-LEFT"]             = { true,  true,  false, false },
	["SIDE-RIGHT"]            = { false, false, true,  true },
	["SIDE-TOP"]              = { true,  false, true,  false },
	["SIDE-BOTTOM"]           = { false, true,  false, true },
	["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
	["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
	["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
	["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

-- distances across and offsets of the world maps
-- in game yards
WorldMapSize = {
	-- World Map of Azeroth
	[0] = {
		parentContinent = 0,
		--height = 31809.64857610083,
		--width = 47714.278579261,
		height = 22266.74312,
		width = 33400.121,
	},
	-- Kalimdor
	{ -- [1]
		-- Kalimdor = { height = 24533.2, width = 36799.8, xOffset = 0, yOffset = 0, },
		parentContinent = 0,
		height = 24533.2,
		width = 36799.8,
		xOffset = -5783.43962,-- -8590.40725049343,
		yOffset = 11116.4766,-- 5628.692856102324,
		zoneData = {
			Silithus = { height = 2706.25, width = 4058.33, xOffset = 14083.3, yOffset = 18672.8, },
			Durotar = { height = 3525, width = 5287.5, xOffset = 19029.1, yOffset = 10991.6, },
			Teldrassil = { height = 3916.65, width = 5875, xOffset = 12831.2, yOffset = 952, },
			Darkshore = { height = 4310.42, width = 6464.59, xOffset = 14049.9, yOffset = 4576.98, },
			Dustwallow = { height = 3500, width = 5250, xOffset = 18041.6, yOffset = 14833.2, },
			Dustwallow_terrain1 = { height = 3500, width = 5250, xOffset = 18041.6, yOffset = 14833.2, },
			Aszhara = { height = 3677.08, width = 5514.58, xOffset = 20439.5, yOffset = 7418.65, },
			Orgrimmar = { height = 1159.59, width = 1739.38, xOffset = 20572.9, yOffset = 10313.2, },
			ThunderBluff = { height = 695.83, width = 1043.75, xOffset = 16549.9, yOffset = 13649.9, },
			Darnassus = { height = 1027.1, width = 1539.58, xOffset = 13879.1, yOffset = 2335.3, },
			Barrens = { height = 3831.25, width = 5745.83, xOffset = 16864.5, yOffset = 10989.5, },
			Mulgore = { height = 3633.33, width = 5450, xOffset = 14862.4, yOffset = 12968.7, },
			Ashenvale = { height = 3843.75, width = 5766.67, xOffset = 15366.6, yOffset = 8126.98, },
			Feralas = { height = 4633.33, width = 6950, xOffset = 11624.9, yOffset = 15166.6, },
			Felwood = { height = 4041.67, width = 6062.5, xOffset = 15268.7, yOffset = 5562.4, },
			ThousandNeedles = { height = 2933.33, width = 4400, xOffset = 17499.9, yOffset = 16766.6, },
			Desolace = { height = 2997.91, width = 4495.83, xOffset = 12833.3, yOffset = 12347.8, },
			StonetalonMountains = { height = 3933.34, width = 5900, xOffset = 13164.5, yOffset = 9395.73, },
			Tanaris = { height = 4808.37, width = 7212.5, xOffset = 17129.1, yOffset = 18570.7, },
			SouthernBarrens = { height = 4941.67, width = 7412.5, xOffset = 15710.3, yOffset = 12595.7, },
			UngoroCrater = { height = 2466.66, width = 3700, xOffset = 16533.3, yOffset = 18766.6, },
			Moonglade = { height = 1539.59, width = 2308.33, xOffset = 18447.8, yOffset = 4308.23, },
			Uldum = { height = 4129.13, width = 6193.75, xOffset = 14624.9, yOffset = 20829.1, },
			Uldum_terrain1 = { height = 4129.13, width = 6193.75, xOffset = 14624.9, yOffset = 20829.1, },
			AhnQirajTheFallenKingdom = { height = 2699.97, width = 4050, xOffset = 13174.9, yOffset = 20833.2, },
			Hyjal = { height = 2831.25, width = 4245.83, xOffset = 17995.8, yOffset = 6604.07, },
			Hyjal_terrain1 = { height = 2831.25, width = 4245.83, xOffset = 17995.8, yOffset = 6604.07, },
			Winterspring = { height = 4100, width = 6150, xOffset = 18058.3, yOffset = 4006.15, },
			ShadowglenStart = { height = 966.6, width = 1450, xOffset = 15574.9, yOffset = 1766.6, },
			ValleyofTrialsStart = { height = 900, width = 1350, xOffset = 20708.3, yOffset = 12799.9, },
			CampNaracheStart = { height = 1177.09, width = 1766.66, xOffset = 16833.3, yOffset = 15377, },
			EchoIslesStart = { height = 1204.17, width = 1806.25, xOffset = 21558.3, yOffset = 13324.9, },
		},
	},
	-- Eastern Kingdoms
	{ -- [2]
		-- Azeroth = { height = 27149.6, width = 40741.2, xOffset = 0, yOffset = 0, },
		parentContinent = 0,
		height = 27149.6,
		width = 40741.2,
		xOffset = 18542.31220836664,
		yOffset = 3585.574573158966,
		zoneData = {
			DunMorogh = { height = 3264.58, width = 4897.92, xOffset = 16034.5, yOffset = 15118, },
			Duskwood = { height = 1800.03, width = 2700, xOffset = 17338.7, yOffset = 20893, },
			Wetlands = { height = 2756.25, width = 4135.42, xOffset = 18561.6, yOffset = 13324.2, },
			Elwynn = { height = 2314.62, width = 3470.84, xOffset = 16636.6, yOffset = 19115.9, },
			Silverpine = { height = 2800, width = 4200, xOffset = 14722, yOffset = 9509.63, },
			EasternPlaguelands = { height = 2687.5, width = 4031.25, xOffset = 20459.5, yOffset = 7472.13, },
			Undercity = { height = 640.1, width = 959.375, xOffset = 17298.8, yOffset = 9298.36, },
			StormwindCity = { height = 1158.34, width = 1737.5, xOffset = 16449.1, yOffset = 19172.1, },
			Ironforge = { height = 527.61, width = 790.629, xOffset = 18885.6, yOffset = 15745.5, },
			HillsbradFoothills = { height = 3241.67, width = 4862.5, xOffset = 16322, yOffset = 9695.05, },
			WesternPlaguelands = { height = 2866.67, width = 4300, xOffset = 17755.3, yOffset = 7809.63, },
			Badlands = { height = 2045.83, width = 3070.84, xOffset = 20074.1, yOffset = 17030.5, },
			StranglethornJungle = { height = 2733.3, width = 4100, xOffset = 16428.2, yOffset = 22193, },
			LochModan = { height = 1839.58, width = 2758.33, xOffset = 20165.8, yOffset = 15663.8, },
			BlastedLands = { height = 2441.7, width = 3662.5, xOffset = 19365.8, yOffset = 21759.6, },
			Westfall = { height = 2333.3, width = 3500, xOffset = 15155.3, yOffset = 20576.3, },
			DeadwindPass = { height = 1666.63, width = 2500, xOffset = 19005.3, yOffset = 21043, },
			Redridge = { height = 1712.52, width = 2568.75, xOffset = 19651.2, yOffset = 19690.9, },
			Arathi = { height = 2318.75, width = 3477.09, xOffset = 19299.1, yOffset = 11318, },
			BurningSteppes = { height = 2100, width = 3152.09, xOffset = 18636.6, yOffset = 18161.7, },
			Hinterlands = { height = 2566.67, width = 3850, xOffset = 19747, yOffset = 9709.63, },
			RuinsofGilneas = { height = 2097.92, width = 3145.83, xOffset = 14732.4, yOffset = 11709.6, },
			VashjirKelpForest = { height = 1868.75, width = 2802.08, xOffset = 13101.2, yOffset = 15195, },
			TwilightHighlands = { height = 3514.58, width = 5270.83, xOffset = 20609.5, yOffset = 13332.5, },
			TwilightHighlands_terrain1 = { height = 3514.58, width = 5270.83, xOffset = 20609.5, yOffset = 13332.5, },
			SearingGorge = { height = 1487.5, width = 2231.25, xOffset = 18494.9, yOffset = 17276.3, },
			VashjirRuins = { height = 3233.33, width = 4850, xOffset = 11490.8, yOffset = 15932.5, },
			VashjirDepths = { height = 2716.67, width = 4075, xOffset = 9938.67, yOffset = 16082.5, },
			Vashjir = { height = 4631.25, width = 6945.84, xOffset = 9417.83, yOffset = 14897.1, },
			TheCapeOfStranglethorn = { height = 2631.2, width = 3945.83, xOffset = 16063.7, yOffset = 23693, },
			StranglethornVale = { height = 4368.7, width = 6552.08, xOffset = 15194.9, yOffset = 22140.9, },
			RuinsofGilneasCity = { height = 593.75, width = 889.58, xOffset = 16238.7, yOffset = 12482.5, },
			Northshire = { height = 645.84, width = 968.75, xOffset = 17984.5, yOffset = 19747.1, },
			ColdridgeValley = { height = 643.75, width = 964.583, xOffset = 17192.8, yOffset = 17138.8, },
			DeathknellStart = { height = 727.08, width = 1089.59, xOffset = 16024.1, yOffset = 8905.47, },
			NewTinkertownStart = { height = 1233.34, width = 1850, xOffset = 16965.8, yOffset = 15903.4, },
			SwampOfSorrows = { height = 1672.88, width = 2508.33, xOffset = 20253.2, yOffset = 20711.7, },
			Tirisfal = { height = 3012.5, width = 4518.75, xOffset = 15138.7, yOffset = 7338.8, },
		},
	},
	-- Outland
	{ -- [3]
		-- Expansion01 = { height = 11642.7, width = 17464, xOffset = 0, yOffset = 0, },
		parentContinent = 3,
		height = 11642.7,
		width = 17464,
		zoneData = {
			EversongWoods = { height = 3283.37, width = 4925, xOffset = 17483.5, yOffset = -5220.34, },
			Ghostlands = { height = 2200, width = 3300, xOffset = 18279.3, yOffset = -2445.31, },
			Hellfire = { height = 3443.75, width = 5164.58, xOffset = 7456.42, yOffset = 4340.11, },
			SilvermoonCity = { height = 806.76, width = 1211.46, xOffset = 19396.8, yOffset = -4332.34, },
			Nagrand = { height = 3683.34, width = 5524.97, xOffset = 2700.2, yOffset = 5779.69, },
			TerokkarForest = { height = 3600, width = 5400, xOffset = 5912.67, yOffset = 6821.36, },
			ShadowmoonValley = { height = 3666.66, width = 5500, xOffset = 8771, yOffset = 7769.28, },
			Zangarmarsh = { height = 3352.09, width = 5027.08, xOffset = 3521, yOffset = 3885.94, },
			BladesEdgeMountains = { height = 3616.66, width = 5425, xOffset = 4150.17, yOffset = 1413.03, },
			Netherstorm = { height = 3716.67, width = 5575, xOffset = 7512.67, yOffset = 365.11, },
			AzuremystIsle = { height = 2714.58, width = 4070.8, xOffset = 23496, yOffset = 8615.11, },
			BloodmystIsle = { height = 2175, width = 3262.5, xOffset = 23071, yOffset = 6579.69, },
			TheExodar = { height = 704.69, width = 1056.7, xOffset = 24062.4, yOffset = 9431.04, },
			ShattrathCity = { height = 870.84, width = 1306.25, xOffset = 6860.74, yOffset = 7295.31, },
			Sunwell = { height = 2218.8, width = 3327.09, xOffset = 18298.1, yOffset = -7747.44, },
			SunstriderIsleStart = { height = 1066.63, width = 1600, xOffset = 18379.3, yOffset = -5011.94, },
			AmmenValeStart = { height = 1212.5, width = 1818.7, xOffset = 25810.6, yOffset = 9425.53, },
		},
	},
	-- Northrend
	{ -- [4]
		-- Northrend = { height = 11834.3, width = 17751.4, xOffset = 0, yOffset = 0, },
		parentContinent = 0,
		height = 11834.3,
		width = 17751.4,
		xOffset = 16020.94044398222,
		yOffset = 454.2451915717977,
		zoneData = {
			IcecrownGlacier = { height = 4181.25, width = 6270.83, xOffset = 3773.4, yOffset = 1166.32, },
			CrystalsongForest = { height = 1814.58, width = 2722.92, xOffset = 7773.4, yOffset = 4091.32, },
			BoreanTundra = { height = 3843.75, width = 5764.58, xOffset = 646.32, yOffset = 5695.48, },
			SholazarBasin = { height = 2904.17, width = 4356.25, xOffset = 2287.98, yOffset = 3305.9, },
			GrizzlyHills = { height = 3500, width = 5250, xOffset = 10327.6, yOffset = 5076.73, },
			LakeWintergrasp = { height = 1983.34, width = 2975, xOffset = 4887.98, yOffset = 4876.73, },
			Dalaran = { height = 0, width = 0, xOffset = 9217.15, yOffset = 10593.4, },
			HrothgarsLanding = { height = 2452.03, width = 3677.09, xOffset = 6419.23, yOffset = -187.8, },
			HowlingFjord = { height = 4031.25, width = 6045.83, xOffset = 10615.1, yOffset = 7476.73, },
			Dragonblight = { height = 3739.58, width = 5608.33, xOffset = 5590.07, yOffset = 5018.4, },
			ZulDrak = { height = 3329.17, width = 4993.75, xOffset = 9817.15, yOffset = 2924.65, },
			TheStormPeaks = { height = 4741.65, width = 7112.5, xOffset = 7375.48, yOffset = 395.5, },
		},
	},
	-- Pandaria
	{ -- [5]
		-- Pandaria = { height = 10343.5, width = 15515.3, xOffset = 0, yOffset = 0, },
		parentContinent = 0,
		height = 10343.5,
		width = 15515.3,
		xOffset = 16020.94044398222,
		yOffset = 454.2451915717977,
		zoneData = {
			TheJadeForest = { height = 4654.16, width = 6983.33, xOffset = 7300.78, yOffset = 3027.08, },
			ValleyoftheFourWinds = { height = 2616.66, width = 3925, xOffset = 6073.69, yOffset = 5583.33, },
			ValeofEternalBlossoms = { height = 1687.5, width = 2533.33, xOffset = 6271.61, yOffset = 4731.24, },
			KunLaiSummit = { height = 4172.92, width = 6258.33, xOffset = 3913.28, yOffset = 1060.41, },
			TownlongWastes = { height = 3829.16, width = 5743.75, xOffset = 1673.69, yOffset = 2120.83, },
			TheHiddenPass = { height = 1195.83, width = 1793.75, xOffset = 7940.36, yOffset = 4989.58, },
			Krasarang = { height = 3125, width = 4687.5, xOffset = 5804.94, yOffset = 6789.58, },
			Krasarang_terrain1 = { height = 3125, width = 4687.5, xOffset = 5804.94, yOffset = 6789.58, },
			DreadWastes = { height = 3568.75, width = 5352.08, xOffset = 2613.28, yOffset = 5262.49, },
			ShrineofTwoMoons = { height = 0, width = 0, xOffset = 8752.86, yOffset = 6679.16, },
			ShrineofSevenStars = { height = 0, width = 0, xOffset = 8752.86, yOffset = 6679.16, },
			IsleOfGiants = { height = 1191.67, width = 1787.5, xOffset = 6748.69, yOffset = -18.7598, },
			TimelessIsle = { height = 1600, width = 2400, xOffset = 12836.2, yOffset = 6445.83, },
		},
	},
}

local zeroData;
zeroData = { xOffset = 0, height = 0, yOffset = 0, width = 0, __index = function() return zeroData end };
setmetatable(zeroData, zeroData);
setmetatable(WorldMapSize, zeroData);

for continent, zones in pairs(Astrolabe.ContinentList) do
	local mapData = WorldMapSize[continent];
	for index, mapName in pairs(zones) do
		if not ( mapData.zoneData[mapName] ) then
			--WE HAVE A PROBLEM!!!
			--ChatFrame1:AddMessage("Astrolabe is missing data for "..select(index, GetMapZones(continent))..".");
			mapData.zoneData[mapName] = zeroData;
		end
		mapData[index] = mapData.zoneData[mapName];
		mapData.zoneData[mapName] = nil;
	end
end


-- register this library with AstrolabeMapMonitor, this will cause a full update if PLAYER_LOGIN has already fired
local AstrolabeMapMonitor = DongleStub("AstrolabeMapMonitor");
AstrolabeMapMonitor:RegisterAstrolabeLibrary(Astrolabe, LIBRARY_VERSION_MAJOR);
