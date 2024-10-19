local WhatDidIDispel = CreateFrame("Frame", "WhatDidIDispel")

-- Popup Box
local linkURL -- used by popup to display url
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
    maxLetters = 1024, -- this otherwise gets cached from other dialogs which caps it at 10..20..30...
}

function WhatDidIDispel:LinkHandler(...)
    local chatFrame, link, string, button = ...
    local type,value = strsplit(":", chatFrame)
    if string == "RightButton" and (type == "spell" or type == "item") then
        linkURL = "http://www.wowhead.com/"..type.."="..value
        StaticPopup_Show("SpellIDCopyDialog")
    end
end

-- slash commands
SLASH_WHATDIDIDISPEL1 = '/wdid'
SLASH_WHATDIDIDISPEL2 = '/whatdididispel'
SLASH_WHATDIDIDISPEL3 = '/dispel'
function SlashCmdList.WHATDIDIDISPEL(msg)
    local self = WhatDidIDispel
    msg = msg:lower()
    if msg == "help" then
        self:DisplayHelp()
    elseif msg == "reset" or msg == "clear" then
        self:ResetDispels()
    elseif msg == "login" then
        self.db.clearOnLogin = (self.db.clearOnLogin == false) and true or false
        print("|cFFFFFF00Clear dispel list on login: "..tostring(self.db.clearOnLogin))
    elseif msg == "infinite" or (tonumber(msg) ~= nil and tonumber(msg) >= 0) then
        self:ResizeList(tonumber(msg))
    else
        self:ListDispels()
    end
end

function WhatDidIDispel:DisplayHelp()
    print("|cFFFFFF00What Did I Dispel Usage:")
    print("  |cFFFFFF00Display list of dispels:  |cFFFFFFFF/dispel")
    print("  |cFFFFFF00Clear the list of dispels:  |cFFFFFFFF/dispel clear")
    print("  |cFFFFFF00Clear the dispel list on login:  |cFFFFFFFF/dispel login")
    print("  |cFFFFFF00Set the dispel list size to 10:  |cFFFFFFFF/dispel 10")
    print("  |cFFFFFF00Set the dispel list size to infinite:  |cFFFFFFFF/dispel 0")
    print("  |cFFFFFF00To display this help menu again:  |cFFFFFFFF/dispel help")
end

function WhatDidIDispel:ListDispels()
    print("|cFFFFFF00Dispels ["..#self.db.dispelList.."]: (for options type /dispel help)")
    for k, v in pairs(self.db.dispelList) do
        print("  "..C_Spell.GetSpellLink(v).." ["..v.."]")
    end
    print(" ")
end

function WhatDidIDispel:ResetDispels()
    --self.db.dispelList = {774,770,1126,2637,22812} -- test data
    wipe(self.db.dispelList)
    print("|cFFFFFF00Dispel list reset.")
end

function WhatDidIDispel:ResizeList(size)
    self.db.maxSize = size
    if self.db.maxSize == 0 then
        size = "infinite"
    else
        for i = 1, #self.db.dispelList - self.db.maxSize do
            tremove(self.db.dispelList, 1)
        end
    end
    print("|cFFFFFF00Dispel list size set to "..size..".")
end

function WhatDidIDispel:OnEvent(event, ...)
    -- if we have a combat log event and its destination is ourselves
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local eventData = {CombatLogGetCurrentEventInfo()}
        local type = eventData[2]
        local sourceFlags = eventData[6]
        local extraSpellID = eventData[15]
        -- we cut of the COMBATLOG_OBJECT_SPECIAL part of the sourceFlags
        local checkFlags = bit.band(sourceFlags, 0xffff)
        -- if we successfully dispel something from somebody
        if (type == "SPELL_DISPEL" or type == "SPELL_STOLEN") and (checkFlags == 0x0511 or checkFlags == 0x1111) then
            -- 0x0511 = player/player/friendly/self
            -- 0x1111 = pet/player/friendly/self
            --DEFAULT_CHAT_FRAME:AddMessage("event="..event.."| timestamp="..timestamp.."| type="..type.."| sourceGUID="..sourceGUID.."| sourceName="..sourceName.."| sourceFlags="..sourceFlags.."| destGUID="..destGUID.."| destName="..destName.."| destFlags="..destFlags.."| spellID="..spellID.."| spellName="..spellName.."| spellSchool="..spellSchool.."| extraSpellID="..extraSpellID.."| extraSpellName="..extraSpellName)
            print(C_Spell.GetSpellLink(extraSpellID).." ["..extraSpellID.."]")

            -- if our list is at max size, trim the oldest element. maxSize of 0 denotes infinite size
            if self.db.maxSize ~= 0 and #self.db.dispelList >= self.db.maxSize then
                tremove(self.db.dispelList, 1)
            end
            tinsert(self.db.dispelList, extraSpellID)
        end
    elseif event == "ADDON_LOADED" then
        if ... == "WhatDidIDispel2" then
            -- check for initial run
            if WhatDidIDispelDB == nil then
                WhatDidIDispelDB = {
                    dispelList = {},
                    maxSize = 0,
                    clearOnLogin = false,
                }
                print("Thanks for trying What Did I Dispel!  For options, type /dispel help")
            end
            self.db = WhatDidIDispelDB

            if self.db.clearOnLogin == true then
                WhatDidIDispel:ResetDispels()
            end

            -- hook into hyperlink shows to bring up the popup for spell and item links
            hooksecurefunc("ChatFrame_OnHyperlinkShow", WhatDidIDispel.LinkHandler)
        end
    end
end

WhatDidIDispel:RegisterEvent("ADDON_LOADED")
WhatDidIDispel:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
WhatDidIDispel:SetScript("OnEvent", WhatDidIDispel.OnEvent)
