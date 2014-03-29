
BrowseNameText:SetPoint("TOPLEFT", "AuctionFrameBrowse", "TOPLEFT", 80, -37);
BrowseName:SetPoint("TOPLEFT", "BrowseNameText", "BOTTOMLEFT", 3, -6); 
BrowseLevelHyphen:SetPoint("LEFT", "BrowseMinLevel", "RIGHT", -1, 1);
BrowseMinLevel:SetWidth(22);
BrowseMaxLevel:SetWidth(22);
BrowseMinLevel:SetPoint("TOPLEFT", "BrowseLevelText", "BOTTOMLEFT", 7, -6);
BrowseMaxLevel:SetPoint("LEFT", "BrowseMinLevel", "RIGHT", 10, 0);
BrowseDropDown:SetPoint("TOPLEFT", "BrowseLevelText", "BOTTOMRIGHT", 10, 0);