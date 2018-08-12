local WhatDidIDispel = CreateFrame("Frame","WhatDidIDispel")

local linkURL; -- used by popup to display url

--[[		Popup Box		]]--
--[[ May want to move this to its own addon, functionality is generic enough ]]--
StaticPopupDialogs["SpellIDCopyDialog"] = {
	text = "URL:  Ctrl-C to copy",
	button2 = CLOSE,
	hasEditBox = 1,
	editBoxWidth = 400,
	OnShow = function(f)
		local editBox = _G[f:GetName().."EditBox"]
		if editBox then
			editBox:SetText(linkURL)
			editBox:SetFocus()
			editBox:HighlightText(0)
		end
		local button = _G[f:GetName().."Button2"]
		if button then
			button:ClearAllPoints()
			button:SetWidth(200)
			button:SetPoint("CENTER", editBox, "CENTER", 0, -30)
		end
	end,
	EditBoxOnEscapePressed = function(f) f:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	maxLetters=1024, -- this otherwise gets cached from other dialogs which caps it at 10..20..30...
}

function WhatDidIDispel:LinkHandler(...)
	local chatFrame, link, string, button = ...;
	local type,value = strsplit(":",chatFrame);
	--print( "type = "..type.." value = "..value );
	--print( "chatFrame = "..chatFrame.." link = "..link.." string = "..string );
	if (string == "RightButton" and ( type == "spell" or type == "item")) then
		linkURL = "http://www.wowhead.com/"..type.."="..value;
		StaticPopup_Show("SpellIDCopyDialog");
	end
end

-- slash commands
SLASH_WHATDIDIDISPEL1,SLASH_WHATDIDIDISPEL2,SLASH_WHATDIDIDISPEL3 = '/wdid', '/whatdididispel', '/dispel';
function SlashCmdList.WHATDIDIDISPEL(msg, editbox)
	msg = msg:lower();
	if( msg == "help" ) then
		WhatDidIDispel:DisplayHelp();
	elseif( msg == "reset" or msg == "clear" ) then
		WhatDidIDispel:ResetDispels();
	elseif( msg == "login" ) then
		clearOnLogin = ((clearOnLogin == false) and true or false );
		print( "|cFFFFFF00Clear dispel list on login: "..tostring(clearOnLogin) );
	elseif( msg == "infinite" or ( tonumber(msg) ~= nil and tonumber(msg) >=0 ) ) then
		WhatDidIDispel:ResizeList(tonumber(msg));
	else
		WhatDidIDispel:ListDispels();
	end
end

function WhatDidIDispel:DisplayHelp()
	print("|cFFFFFF00What Did I Dispel Usage:" );
	print("  |cFFFFFF00Display list of dispels:  |cFFFFFFFF/dispel" );
	print("  |cFFFFFF00Clear the list of dispels:  |cFFFFFFFF/dispel clear" );
	print("  |cFFFFFF00Clear the dispel list on login:  |cFFFFFFFF/dispel login" );
	print("  |cFFFFFF00Set the dispel list size to 10:  |cFFFFFFFF/dispel 10" );
	print("  |cFFFFFF00Set the dispel list size to infinite:  |cFFFFFFFF/dispel 0" );
	print("  |cFFFFFF00To display this help menu again:  |cFFFFFFFF/dispel help" );
end

function WhatDidIDispel:ListDispels()
	print("|cFFFFFF00Dispels ["..#dispelList.."]: (for options type /dispel help)");
	for i,v in pairs(dispelList) do
		print("  "..GetSpellLink(v).." ["..v.."]");
	end
	print(" ");
end

function WhatDidIDispel:ResetDispels()
	--dispelList = {774,770,1126,2637,22812}; -- NOTE test data
	wipe( dispelList );
	print("|cFFFFFF00Dispel list reset.");
end

function WhatDidIDispel:ResizeList(size)
	maxSize = size;
	if( maxSize == 0 ) then
		size = "infinite";
	else
		for i=1,(#dispelList-maxSize) do
			tremove(dispelList,1);
		end	
	end;
	print( "|cFFFFFF00Dispel list size set to "..size..".");
end

function WhatDidIDispel:OnEvent(event,...)
	-- if we have a combat log event and its destination is ourselves
	if (event == "COMBAT_LOG_EVENT_UNFILTERED" ) then
		local timestamp, type, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSchool, auraType = select(1, ...);
		--        1        2      3            4           5            6            7           8         9           10         11        12         13          14           15             16            17         18
		-- we cut of the COMBATLOG_OBJECT_SPECIAL part of the sourceFlags
		local checkFlags = bit.band(sourceFlags, 0xffff);
		-- if we successfully dispel something from somebody
		if ((type == "SPELL_DISPEL" or type == "SPELL_STOLEN") and (checkFlags == 0x0511 or checkFlags == 0x1111)) then
		-- (sourceFlags == 0x0511 or sourceFlags == 0x1111)
		-- (destName == UnitName("player"))
		-- 0x0511 = player/player/friendly/self
		-- 0x1111 = pet/player/friendly/self
			--DEFAULT_CHAT_FRAME:AddMessage("event="..event.."| timestamp="..timestamp.."| type="..type.."| sourceGUID="..sourceGUID.."| sourceName="..sourceName.."| sourceFlags="..sourceFlags.."| destGUID="..destGUID.."| destName="..destName.."| destFlags="..destFlags.."| spellID="..spellID.."| spellName="..spellName.."| spellSchool="..spellSchool.."| extraSpellID="..extraSpellID.."| extraSpellName="..extraSpellName);
			
			print( GetSpellLink(extraSpellID).." ["..extraSpellID.."]");
			
			-- if our list is at max size, trim the oldest element.  maxSize of 0 denotes infinite size
			if (maxSize ~= 0 and #dispelList >= maxSize ) then
				tremove( dispelList, 1 );
			end
			
			tinsert( dispelList, extraSpellID );
		end

  -- elseif (event == "ADDON_LOADED" and select(1,...) == self:GetName()) then
	elseif (event == "ADDON_LOADED") then
    if (... == "WhatDidIDispel2") then
  		-- check for initial run
  		if( dispelList == nil ) then
  			dispelList = {};
  			maxSize = 0;
  			clearOnLogin = false;
  			print( "Thanks for trying What Did I Dispel!  For options, type /dispel help" );
  		elseif( clearOnLogin == true ) then
  			WhatDidIDispel:ResetDispels();
  		end
  		
  		-- hook into hyperlink shows to bring up the popup for spell and item links
  		hooksecurefunc( "ChatFrame_OnHyperlinkShow", WhatDidIDispel.LinkHandler );
		end
	end
end

WhatDidIDispel:RegisterEvent("ADDON_LOADED");
WhatDidIDispel:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
WhatDidIDispel:SetScript("OnEvent", WhatDidIDispel.OnEvent);