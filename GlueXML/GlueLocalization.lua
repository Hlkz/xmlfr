function Localize()
	-- Put all locale specific string adjustments here
	--SHOW_CONTEST_AGREEMENT = 1;

	DONATE = "Donations";
	VERSION_STRING = "World of Warcraft pour Aviana version 1.0.0 - 26 Février 2014";

	-- Show termination of service without notice agreement
	SHOW_TERMINATION_WITHOUT_NOTICE_AGREEMENT = 1;
end

function LocalizeFrames()
	-- Put all locale specific UI adjustments here
	RealmWizardSuggest:SetWidth(235);
	WorldOfWarcraftRating:SetTexture("Interface\\Glues\\Login\\Glues-FrenchRating");
	WorldOfWarcraftRating:ClearAllPoints();
	WorldOfWarcraftRating:SetPoint("BOTTOMLEFT", "AccountLoginUI", "BOTTOMLEFT", 20, 45);
	WorldOfWarcraftRating:Show();
	RealmCharactersSort:SetWidth(RealmCharactersSort:GetWidth() + 8);
	RealmLoadSort:SetWidth(RealmLoadSort:GetWidth() - 8);
end
