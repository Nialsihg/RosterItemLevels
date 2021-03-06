local addonName = "RosterItemLevels"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Roster window
local rosterItemLevelsTooltip = CreateFrame("GameTooltip", addonName .. "Tooltip", UIParent, "GameTooltipTemplate")
local rosterItemLevelsDropDown = CreateFrame("Frame", addonName .. "Dropdown", rosterItemLevelsTooltip, "UIDropDownMenuTemplate")

-- Options panel
local optionsPanel = CreateFrame("Frame")
local optionsPanelTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
local minimapIconCheckButton = CreateFrame("CheckButton", addonName .. "MinimapIcon", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local optionsPanelSubtitleTooltip = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
local mouseoverCheckButton = CreateFrame("CheckButton", addonName .. "Mouseover", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local itemLevelColorDropdown = CreateFrame("Frame", addonName .. "TooltipColor", optionsPanel, "UIDropDownMenuTemplate")
local itemLevelColorDropdownLabel = itemLevelColorDropdown:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
local optionsPanelSubtitleWindow = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
local autoToggleCheckButton = CreateFrame("CheckButton", addonName .. "AutoToggle", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local specCheckButton = CreateFrame("CheckButton", addonName .. "ShowSpec", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local roleCheckButton = CreateFrame("CheckButton", addonName .. "ShowRole", optionsPanel, "InterfaceOptionsCheckButtonTemplate")

-- Load libs for easy UI creation and autocompletion in EditBox.
-- Used to create a report window.
local AceGUI = LibStub("AceGUI-3.0")
local AutoComplete = LibStub("AceGUI-3.0-Completing-EditBox")

-- Load libs for minimap icon.
local rosterItemLevelsLDB = LibStub("LibDataBroker-1.1"):NewDataObject(addonName .. "LDB", {
    type = "data source",
    text = "",
    icon = [[Interface\Icons\inv_misc_spyglass_03]]
})
local minimapIcon = LibStub("LibDBIcon-1.0")

-- Load lib for inspection of group members.
-- Used to get the specialization and role of a unit.
local LibGroupInspect = LibStub("LibGroupInSpecT-1.1")

local reportWindow  -- Used to store AceGUI's Window container object.
local ticker, updater, animation, processedChatFrame
local updateDelay = 5  -- Elapsed time between updates in seconds.
local timeToggleOffWindow = 0
local mouseoverPlayersTable, rosterLeaversTimes = {}, {}
local pendingQueries = {mouseover = {}, rosterWindow = {}}

local minLowItemLevel, maxLowItemLevel, maxHighItemLevel = 0, 700, 991
-- Note: We don't merge the tables to keep a better color accuracy.
local lowItemLevelColors = {
    [1] = {157, 157, 157},  -- from GRAY (Poor quality)
    [2] = {255, 255, 255},  -- to WHITE (Common quality)
    [3] = {30, 255, 0}      -- to GREEN (Uncommon quality)
}
local highItemLevelColors = {
    [1] = {30, 255, 0},    -- from GREEN (Uncommon quality)
    [2] = {0, 112, 221},   -- to BLUE (Rare quality)
    [3] = {163, 53, 238},  -- to PURPLE (Epic quality)
    [4] = {255, 128, 0},   -- to ORANGE (Legendary quality)
    [5] = {255, 0, 0}      -- to RED
}

local leaderIcon = [[Interface\GROUPFRAME\UI-Group-LeaderIcon]]
local roleIcons = {  -- ElvUI's role icon files.
    TANK = "Interface\\AddOns\\" .. addonName .. "\\textures\\tank",
    HEALER = "Interface\\AddOns\\" .. addonName .. "\\textures\\healer",
    DAMAGER = "Interface\\AddOns\\" .. addonName .. "\\textures\\dps"
}
local specIcons = {
    [577] = [[Interface\Icons\ability_demonhunter_specdps]],        -- Havoc Demon Hunter
    [581] = [[Interface\Icons\ability_demonhunter_spectank]],       -- Vengeance Demon Hunter

    [250] = [[Interface\Icons\spell_deathknight_bloodpresence]],    -- Death Knight Blood
    [251] = [[Interface\Icons\spell_deathknight_frostpresence]],    -- Death Knight Frost
    [252] = [[Interface\Icons\spell_deathknight_unholypresence]],   -- Death Knight Unholy

    [102] = [[Interface\Icons\spell_nature_starfall]],              -- Druid Balance
    [103] = [[Interface\Icons\ability_druid_catform]],              -- Druid Feral
    [104] = [[Interface\Icons\ability_racial_bearform]],            -- Druid Guardian
    [105] = [[Interface\Icons\spell_nature_healingtouch]],          -- Druid Restoration

    [253] = [[Interface\Icons\ability_hunter_bestialdiscipline]],   -- Hunter Beast Mastery
    [254] = [[Interface\Icons\ability_hunter_focusedaim]],          -- Hunter Marksmanship
    [255] = [[Interface\Icons\ability_hunter_camouflage]],          -- Hunter Survival

    [62] = [[Interface\Icons\spell_holy_magicalsentry]],            -- Mage Arcane
    [63] = [[Interface\Icons\spell_fire_firebolt02]],               -- Mage Fire
    [64] = [[Interface\Icons\spell_frost_frostbolt02]],             -- Mage Frost

    [268] = [[Interface\Icons\spell_monk_brewmaster_spec]],         -- Monk Brewmaster
    [269] = [[Interface\Icons\spell_monk_windwalker_spec]],         -- Monk Windwalker
    [270] = [[Interface\Icons\spell_monk_mistweaver_spec]],         -- Monk Mistweaver

    [65] = [[Interface\Icons\spell_holy_holybolt]],                 -- Paladin Holy
    [66] = [[Interface\Icons\ability_paladin_shieldofthetemplar]],  -- Paladin Protection
    [70] = [[Interface\Icons\spell_holy_auraoflight]],              -- Paladin Retribution

    [256] = [[Interface\Icons\spell_holy_powerwordshield]],         -- Priest Discipline
    [257] = [[Interface\Icons\spell_holy_guardianspirit]],          -- Priest Holy
    [258] = [[Interface\Icons\spell_shadow_shadowwordpain]],        -- Priest Shadow

    [259] = [[Interface\Icons\ability_rogue_eviscerate]],           -- Rogue Assassination
    [260] = [[Interface\Icons\inv_sword_30]],                       -- Rogue Outlaw
    [261] = [[Interface\Icons\ability_stealth]],                    -- Rogue Subtlety

    [262] = [[Interface\Icons\spell_nature_lightning]],             -- Shaman Elemental
    [263] = [[Interface\Icons\spell_shaman_improvedstormstrike]],   -- Shamen Enhancement
    [264] = [[Interface\Icons\spell_nature_healingwavegreater]],    -- Shaman Restoration

    [265] = [[Interface\Icons\spell_shadow_deathcoil]],             -- Warlock Affliction
    [266] = [[Interface\Icons\spell_shadow_metamorphosis]],         -- Warlock Demonology
    [267] = [[Interface\Icons\spell_shadow_rainoffire]],            -- Warlock Destruction

    [71] = [[Interface\Icons\ability_warrior_savageblow]],          -- Warrior Arms
    [72] = [[Interface\Icons\ability_warrior_innerrage]],           -- Warrior Fury
    [73] = [[Interface\Icons\ability_warrior_defensivestance]]      -- Warrior Protection
}

-- Cache frequently used globals in locals.
local GetTime = GetTime
local GetCVar = GetCVar
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitIsAFK = UnitIsAFK
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local SendChatMessage = SendChatMessage
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local tonumber = tonumber
local string_find = string.find
local string_match = string.match
local table_insert = table.insert
local table_sort = table.sort
local math_floor = math.floor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local function print(...)
    -- Global print wrapper.
    _G.print("|cff259054" .. addonName .. ":|r", ...)
end

local function formatIconForTooltip(icon)
    return "|T" .. icon .. ":15:15:0:0:64:64:2:56:2:56|t"
end

local function trim(s)  -- from http://lua-users.org/wiki/StringTrim
    local from = s:match"^%s*()"
    return from > #s and "" or s:match(".*%S", from)
end

local function rgbToRgbPercent(r, g, b, alpha)  -- from https://github.com/SpycerLviv/Lua-Color-Converter
    local red, green, blue = r / 255, g / 255, b / 255
    red, green, blue = math_floor(red * 100) / 100, math_floor(green * 100) / 100, math_floor(blue * 100) / 100
    if alpha == nil then
        return red, green, blue
    elseif alpha > 1 then
        alpha = alpha / 100
    end
    return red, green, blue, alpha
end

local function convertToRgb(val, minVal, maxVal, colors)  -- from https://stackoverflow.com/questions/20792445/calculate-rgb-value-for-a-range-of-values-to-create-heat-map/20793850#20793850
    local i_f = (val - minVal) / (maxVal - minVal) * (#colors - 1)
    local i, f = math_floor(i_f), i_f - math_floor(i_f)
    local shift = #colors < i + 2 and 0 or 1  -- the indices start at 1 in Lua.
    local r1, g1, b1 = unpack(colors[i + shift])
    local r2, g2, b2 = unpack(colors[i + shift + 1])
    return math_floor(r1 + f * (r2 - r1)), math_floor(g1 + f * (g2 - g1)), math_floor(b1 + f * (b2 - b1))
end

local function convertItemLevelToRgb(itemLevel)
    if itemLevel < maxLowItemLevel then
        return rgbToRgbPercent(convertToRgb(itemLevel, minLowItemLevel, maxLowItemLevel, lowItemLevelColors))
    end
    if itemLevel > maxHighItemLevel then
        return 1, 0, 0
    end
    return rgbToRgbPercent(convertToRgb(itemLevel, maxLowItemLevel, maxHighItemLevel + 1, highItemLevelColors))
end

local function getItemLevelColor(unitName)
    if RosterItemLevelsDB.options.itemLevelColor == "GearScore" then
        return convertItemLevelToRgb(mouseoverPlayersTable[unitName].ilvl)
    end
    local class = mouseoverPlayersTable[unitName].class
    return RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
end

local function isValidCharacterName(unitName)
    -- Character name must be between 2-12 characters long and must contain only letters [a-z-A-Z].
    if unitName and unitName ~= UNKNOWNOBJECT then
        if #unitName >= 2 and #unitName <= 12 then
            if string_match(unitName, "[^%a]") == nil then
                return true
            end
        end
    end
    return false
end

local function sortDesc(a, b)
    return a > b
end

local function sortRosterTableKeys(sortFunction)
    local keys = {}
    for unitName in pairs(RosterItemLevelsPerCharDB.rosterInfo.rosterTable) do
        table_insert(keys, unitName)
    end
    table_sort(keys, function(unitName1, unitName2)  -- Will exec only if table contains 2 or more elements.
        return sortFunction(RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName1].ilvl,
                RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName2].ilvl)
    end)
    return keys
end

local function computeAverageRosterItemLevel()
    local sum = 0
    for _, unitName in ipairs(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) do
        sum = sum + RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].ilvl
    end
    return math_floor(sum / #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys + 0.5)  -- rounded up or down and troncated.
end

local function cleanRosterTable()
    local removedFromRoster = {}
    for savedName in pairs(RosterItemLevelsPerCharDB.rosterInfo.rosterTable) do
        if savedName ~= UnitName("player") then
            local isInRoster = false
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    local unitName = UnitName("raid" .. i)
                    -- Note: UNKNOWNOBJECT means the unit is not fully loaded and we can't get it's name yet.
                    -- Don't remove the unit from rosterTable if we can't get its name.
                    if unitName == savedName or unitName == UNKNOWNOBJECT then
                        isInRoster = true
                    end
                end
            elseif IsInGroup() then
                for i = 1, GetNumSubgroupMembers() do
                    local unitName = UnitName("party" .. i)
                    if unitName == savedName or unitName == UNKNOWNOBJECT then
                        isInRoster = true
                    end
                end
            end
            if not isInRoster then
                table_insert(removedFromRoster, savedName)
            end
        end
    end
    for i = 1, #removedFromRoster do
        local unitName = removedFromRoster[i]
        rosterLeaversTimes[unitName] = GetTime()
        pendingQueries.rosterWindow[unitName] = nil
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] = nil
    end
    RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys = sortRosterTableKeys(sortDesc)
    RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel = computeAverageRosterItemLevel()
end

local function retrieveGroupLeader()
    if UnitIsGroupLeader("player") then
        return UnitName("player")
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsGroupLeader("raid" .. i) then
                local unitName = UnitName("raid" .. i)
                if isValidCharacterName(unitName) then
                    return unitName
                end
                break
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if UnitIsGroupLeader("party" .. i) then
                local unitName = UnitName("party" .. i)
                if isValidCharacterName(unitName) then
                    return unitName
                end
                break
            end
        end
    end
end

local function unitNameToUnitID(unitName)
    -- Look in the cache first.
    if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] and
            RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].lastKnownUnitID then
        local lastKnownUnitID = RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].lastKnownUnitID
        if unitName == UnitName(lastKnownUnitID) then
            return lastKnownUnitID
        end
    end
    if unitName == UnitName("player") then
        return "player"
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if unitName == UnitName("raid" .. i) then
                return "raid" .. i
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if unitName == UnitName("party" .. i) then
                return "party" .. i
            end
        end
    end  -- Returns nil if unitName is not in our group.
end

local function updateUnitInfo(unitName, unitID, itemLevel)
    if not RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] then
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] = {}
    end
    if not RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class then
        local _, class = UnitClass(unitID)
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class = class
    end
    local unitInfo = LibGroupInspect:GetCachedInfo(UnitGUID(unitID))  -- Most likely nil if we just relogged/reloaded.
    if unitInfo and unitInfo.global_spec_id and unitInfo.global_spec_id ~= 0 then
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].specID = unitInfo.global_spec_id
    end
    if unitInfo and unitInfo.spec_role then
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role = unitInfo.spec_role
    elseif not RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role then
        -- Use assigned role if we don't have any cached value.
        -- Note: Assigned role can differ from actual role.
        local role = UnitGroupRolesAssigned(unitID)
        if role and role ~= "NONE" then
            RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role = role
        end
    end
    RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].ilvl = tonumber(itemLevel)
    RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].lastKnownUnitID = unitID
    RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys = sortRosterTableKeys(sortDesc)
    RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel = computeAverageRosterItemLevel()
end

local function filterMessageSystem(chatFrame, event, msg, ...)
    if string_find(msg, "Invalid character") or string_find(msg, "Caracter invalid") then
        return true
    end
    if not string_find(msg, "Equipped ilvl for") and not string_find(msg, "Equipped ilvl pentru") then
        return false  -- Not the message we are looking for, don't filter.
    end
    local unitName, itemLevel = string_match(msg, "Equipped ilvl for (%a+): ([0-9]+)")
    if not unitName then  -- Server response is in Romanian.
        unitName, itemLevel = string_match(msg, "Equipped ilvl pentru (%a+): ([0-9]+)")
    end
    if not pendingQueries.mouseover[unitName] then
        if mouseoverPlayersTable[unitName] and GetTime() - mouseoverPlayersTable[unitName].lastUpdateTime <= 1 then
            return true
        end
        if GetTime() - timeToggleOffWindow <= 1 then
            -- We just toggled off the window but we are still receiving messages from last update, keep filtering.
            return true
        end
        if not updater:IsPlaying() then
            return false  -- Roster window is not open, don't filter.
        end
    end
    if rosterLeaversTimes[unitName] and GetTime() - rosterLeaversTimes[unitName] <= 1 then
        return true  -- We received a message for a unit who just left the group, filter it.
    end
    if not processedChatFrame then
        processedChatFrame = chatFrame
    end
    if pendingQueries.mouseover[unitName] then
        mouseoverPlayersTable[unitName].ilvl = tonumber(itemLevel)
        mouseoverPlayersTable[unitName].lastUpdateTime = GetTime()
        if unitName == GameTooltip:GetUnit() then  -- The tooltip still displays the unit we received a message for.
            local r, g, b = getItemLevelColor(unitName)
            GameTooltip:AddDoubleLine("Item Level", mouseoverPlayersTable[unitName].ilvl, r, g, b, r, g, b)
            GameTooltip:Show()
        end
        pendingQueries.mouseover[unitName] = nil
        return true  -- Filter messages sent from mouseovers.
    end
    if not pendingQueries.rosterWindow[unitName] then
        return false  -- Don't filter messages coming from a player's manual query.
    end
    if chatFrame ~= processedChatFrame then
        -- The query has already been processed in processedChatFrame.
        -- Filter duplicate messages coming from other chat frames.
        return true
    end
    local unitID = unitNameToUnitID(unitName)
    if unitID then
        updateUnitInfo(unitName, unitID, itemLevel)
    end
    return true
end

local function queryUnitItemLevel(unitID)
    local unitName = UnitName(unitID)
    if isValidCharacterName(unitName) and UnitIsConnected(unitID) then
        if not pendingQueries.mouseover[unitName] then
            pendingQueries.rosterWindow[unitName] = true
        end
        -- Send the command in the EMOTE chat type to avoid flooding restrictions.
        -- The server will respond with a system message which will trigger filterMessageSystem()
        SendChatMessage(".ilvl " .. unitName, "EMOTE")
    end
end

local function queryRosterItemLevels(autoCancelAFK)
    local groupSize = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers() + 1
    if groupSize < #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys then
        cleanRosterTable()
    end
    if IsInGroup() and RosterItemLevelsPerCharDB.rosterInfo.leaderName == nil then
        RosterItemLevelsPerCharDB.rosterInfo.leaderName = retrieveGroupLeader()
    end
    if UnitIsDeadOrGhost("player") then
        return
    end
    if UnitIsAFK("player") and not autoCancelAFK then
        return
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            queryUnitItemLevel("raid" .. i)
        end
    else
        queryUnitItemLevel("player")
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do
                queryUnitItemLevel("party" .. i)
            end
        end
    end
end

local function sendReportMessage(chatType, channel)
    if #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys < 2 then
        print("There is no data to report.")
        return
    end
    SendChatMessage(addonName .. " AddOn report:", chatType, nil, channel)
    SendChatMessage("--------------------------------------------", chatType, nil, channel)
    for _, unitName in ipairs(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) do
        local reportMessage = "<iLvl>  " .. RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].ilvl .. "        " .. unitName
        SendChatMessage(reportMessage, chatType, nil, channel)
    end
    SendChatMessage("--------------------------------------------", chatType, nil, channel)
    SendChatMessage("<Avg>  " .. RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel, chatType, nil, channel)
end

local function closeReportWindow()
    if reportWindow then
        reportWindow:ReleaseChildren()
        reportWindow:Release()
        reportWindow = nil
    end
end

local function openReportWindow()
    if reportWindow ~= nil then
        return
    end
    reportWindow = AceGUI:Create("Window")
    reportWindow:EnableResize(false)
    reportWindow:SetLayout("Flow")
    reportWindow:SetWidth(250)
    -- AceGUI hack to auto-set report window's height.
    reportWindow.LayoutFinished = function(self, _, height) reportWindow:SetHeight(height + 57) end
    reportWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    reportWindow:SetTitle(addonName .. " - Report")
    reportWindow:SetCallback("OnClose", function(widget, callback) closeReportWindow() end)

    local channelDropDown = AceGUI:Create("Dropdown")
    channelDropDown:SetLabel("Channel")
    channelDropDown:SetList({"Guild", "Instance", "Party", "Raid", "Whisper", "Whisper Target"})
    local channel = RosterItemLevelsDB.report.channel or 4
    channelDropDown:SetValue(channel)
    channelDropDown:SetCallback("OnValueChanged", function(f, e, value)
        RosterItemLevelsDB.report.channel = value  -- Redraw in-place to add/remove whisper editbox.
        if channel ~= value then
            local pos = {reportWindow:GetPoint()}
            closeReportWindow()
            openReportWindow()
            reportWindow:SetPoint(unpack(pos))
        end
    end)
    reportWindow:AddChild(channelDropDown)

    local whisperBox
    if channel == 5 then
        AutoComplete:Register("All", AUTOCOMPLETE_LIST_TEMPLATES.ALL)
        whisperBox = AceGUI:Create("EditBoxAll")
        whisperBox:SetLabel("Whisper Target")
        whisperBox:DisableButton(true)
        whisperBox:SetMaxLetters(12)
        whisperBox:SetText(RosterItemLevelsDB.report.target or "")
        whisperBox.editbox:SetCursorPosition(12)
        whisperBox:HighlightText(0, 12)
        whisperBox:SetFocus(true)
        whisperBox:SetCallback("OnEnterPressed", function(box, event, text)
            RosterItemLevelsDB.report.target = trim(text)
            reportWindow.button.frame:Click()
        end)
        whisperBox:SetFullWidth(true)
        reportWindow:AddChild(whisperBox)
    end

    local reportButton = AceGUI:Create("Button")
    reportWindow.button = reportButton
    reportButton:SetText("Send")
    reportButton:SetFullWidth(true)
    reportButton:SetCallback("OnClick", function()
        if channel == 1 then
            if IsInGuild() then
                sendReportMessage("GUILD")
            else
                print("You must be in a guild.")
                return
            end
        elseif channel == 2 then
            if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
                sendReportMessage("INSTANCE_CHAT")
            else
                print("You must be in an instance group.")
                return
            end
        elseif channel == 3 then
            if IsInGroup() then
                sendReportMessage("PARTY")
            else
                print("You must be in a group.")
                return
            end
        elseif channel == 4 then
            if IsInRaid() then
                sendReportMessage("RAID")
            else
                print("You must be in a raid group.")
                return
            end
        elseif channel == 5 then
            RosterItemLevelsDB.report.target = trim(whisperBox:GetText())
            if RosterItemLevelsDB.report.target and RosterItemLevelsDB.report.target ~= "" then
                sendReportMessage("WHISPER", RosterItemLevelsDB.report.target)
            else
                print("Whisper target not found.")
                return
            end
        elseif channel == 6 then
            if UnitExists("target") and UnitIsPlayer("target") and UnitIsConnected("target") then
                sendReportMessage("WHISPER", UnitName("target"))
            else
                print("Whisper target not found.")
                return
            end
        end
        reportWindow:Hide()
    end)
    reportWindow:AddChild(reportButton)
end

local function renderRosterItemLevelsTooltip()
    rosterItemLevelsTooltip:ClearLines()
    rosterItemLevelsTooltip:SetText("Roster Item Levels", 1, 1, 1)
    for _, unitName in ipairs(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) do
        if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] then
            local roleIcon, specIcon, stringLeft = _, _, ""
            local class = RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class
            local r, g, b = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
            if RosterItemLevelsDB.options.role and RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role then
                roleIcon = formatIconForTooltip(roleIcons[RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role])
                stringLeft = roleIcon
            end
            if RosterItemLevelsDB.options.spec and RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].specID then
                specIcon = formatIconForTooltip(specIcons[RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].specID])
                stringLeft = roleIcon == nil and specIcon or stringLeft .. " " .. specIcon
            end
            stringLeft = (roleIcon == nil and specIcon == nil) and unitName or stringLeft .. " " .. unitName
            if unitName == RosterItemLevelsPerCharDB.rosterInfo.leaderName then
                stringLeft = stringLeft .. " " .. formatIconForTooltip(leaderIcon)
            end
            rosterItemLevelsTooltip:AddDoubleLine(
                stringLeft, RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].ilvl, r, g, b, r, g, b)
        end
    end
    if #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys >= 2 then
        GameTooltip_AddBlankLinesToTooltip(rosterItemLevelsTooltip, 1)
        rosterItemLevelsTooltip:AddDoubleLine(
            "Average (" .. #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys .. ")",
            RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel, 1, 1, 1, 1, 1, 1)
    end
    rosterItemLevelsTooltip:Show()
end

local function startNewUpdate(autoCancelAFK, delay)
    delay = delay or 0
    C_Timer.After(delay, function()
        if updater:IsPlaying() then
            ticker:Cancel()
            queryRosterItemLevels(autoCancelAFK)
            ticker = C_Timer.NewTicker(updateDelay, function() queryRosterItemLevels(false) end)
        end
    end)
end

local function toggleOffRosterWindow()
    timeToggleOffWindow = GetTime()
    ticker:Cancel()
    updater:Stop()
    rosterItemLevelsTooltip:Hide()
    wipe(pendingQueries.rosterWindow)
end

local function toggleOnRosterWindow(delay)
    delay = delay or 0
    C_Timer.After(delay, function()
        if not updater:IsPlaying() then
            rosterItemLevelsTooltip:Show()
            rosterItemLevelsTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            animation:SetDuration(0.05)
            updater:SetScript("OnLoop", renderRosterItemLevelsTooltip)
            updater:Play()
            queryRosterItemLevels(true)
            ticker = C_Timer.NewTicker(updateDelay, function() queryRosterItemLevels(false) end)
            -- Reduces the CPU usage by lowering the refresh rate of the roster window once it has fully loaded.
            C_Timer.After(1, function() animation:SetDuration(0.5) end)
        end
    end)
end

local function mouseoverTooltipHook()
    if not RosterItemLevelsDB.options.mouseover or UnitIsDeadOrGhost("player") or
            (UnitIsAFK("player") and GetCVar("autoClearAFK") == "1") then
        return
    end
    local unitName, unitID = GameTooltip:GetUnit()
    if UnitExists(unitID) and UnitIsPlayer(unitID) then  -- Also true when unitID isn't connected but is in our group.
        if UnitIsConnected(unitID) then  -- Must be connected to use command .ilvl.
            if mouseoverPlayersTable[unitName] then
                if mouseoverPlayersTable[unitName].lastUpdateTime and
                        GetTime() - mouseoverPlayersTable[unitName].lastUpdateTime < updateDelay then
                    local r, g, b = getItemLevelColor(unitName)
                    GameTooltip:AddDoubleLine("Item Level", mouseoverPlayersTable[unitName].ilvl, r, g, b, r, g, b)
                    GameTooltip:Show()
                else  -- Item level is too old, send a new query.
                    if not pendingQueries.mouseover[unitName] then
                        pendingQueries.mouseover[unitName] = true
                        queryUnitItemLevel(unitID)
                    end
                end
            else  -- First time we mouseover this unit.
                mouseoverPlayersTable[unitName] = {}
                if not mouseoverPlayersTable[unitName].class then
                    local _, class = UnitClass(unitID)
                    mouseoverPlayersTable[unitName].class = class
                end
                if not pendingQueries.mouseover[unitName] then
                    pendingQueries.mouseover[unitName] = true
                    queryUnitItemLevel(unitID)
                end
            end
        else  -- Unit isn't connected, can't refresh his ilvl so look for a cached value.
            if mouseoverPlayersTable[unitName] and mouseoverPlayersTable[unitName].ilvl then
                local r, g, b = getItemLevelColor(unitName)
                GameTooltip:AddDoubleLine("Item Level", mouseoverPlayersTable[unitName].ilvl, r, g, b, r, g, b)
                GameTooltip:Show()
            end
        end
    end
end

function frame:CINEMATIC_STOP()
    -- Fix a bug were the roster window would lose its owner after a cinematic.
    if updater:IsPlaying() then
        -- Roster window was shown before the cinematic, set his owner back.
        rosterItemLevelsTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    end
end

function frame:PLAYER_LEAVING_WORLD()
    -- Saves roster window state in case of a reload/relog.
    RosterItemLevelsPerCharDB.window.wasShown = rosterItemLevelsTooltip:IsShown()
end

function frame:PLAYER_EQUIPMENT_CHANGED()
    if updater:IsPlaying() then
        queryUnitItemLevel("player")
    end
end

function frame:PARTY_LEADER_CHANGED()
    RosterItemLevelsPerCharDB.rosterInfo.leaderName = retrieveGroupLeader()
end

function frame:GROUP_ROSTER_UPDATE()
    -- This event also triggers on player connects/disconnects.
    -- We want to make sure that a player actually joined or left the group.
    local groupSize = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers() + 1
    if groupSize < #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys then
        -- A player left, remove him from the roster window.
        cleanRosterTable()
    elseif groupSize > #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys then
        if updater:IsPlaying() then
            -- A player joined, start a new update.
            startNewUpdate(false)
        end
    end
end

function frame:GROUP_LEFT()
    self:UnregisterEvent("GROUP_LEFT")
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("PARTY_LEADER_CHANGED")
    if updater:IsPlaying() then
        toggleOffRosterWindow()
    end
    cleanRosterTable()
    RosterItemLevelsPerCharDB.rosterInfo.leaderName = nil
end

function frame:GROUP_JOINED()
    self:RegisterEvent("GROUP_LEFT")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PARTY_LEADER_CHANGED")
    if updater:IsPlaying() then
        startNewUpdate(true, 0.5)
    elseif RosterItemLevelsDB.options.autoToggle then
        toggleOnRosterWindow(1)  -- Toggle on after 1 second. We have to wait for group data to be available.
    end
end

function frame:PLAYER_LOGIN()  -- Fires on login / reload.
    -- Make sure GROUP_JOINED doesn't fire when we login inside a group.
    C_Timer.After(0.1, function() self:RegisterEvent("GROUP_JOINED") end)
    if IsInGroup() then
        self:RegisterEvent("GROUP_LEFT")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PARTY_LEADER_CHANGED")
        LibGroupInspect:Rescan()
        RosterItemLevelsPerCharDB.rosterInfo.leaderName = retrieveGroupLeader()
    else
        RosterItemLevelsPerCharDB.rosterInfo.leaderName = nil
    end
    cleanRosterTable()
    if RosterItemLevelsPerCharDB.window.wasShown then
        toggleOnRosterWindow(1)  -- Toggle on after 1 second. We have to wait for group data to be available.
    end
end

function frame:ADDON_LOADED(name)
    if name ~= addonName then
        return
    end

    -- RosterItemLevelsDB
    if type(RosterItemLevelsDB) ~= "table" then
        RosterItemLevelsDB = {}
    end
    if type(RosterItemLevelsDB.window) ~= "table" then
        RosterItemLevelsDB.window = {}
    end
    if RosterItemLevelsDB.window.point == nil then
        RosterItemLevelsDB.window.point = "CENTER"
    end
    if RosterItemLevelsDB.window.locked == nil then
        RosterItemLevelsDB.window.locked = false
    end
    if type(RosterItemLevelsDB.options) ~= "table" then
        RosterItemLevelsDB.options = {}
    end
    if RosterItemLevelsDB.options.minimap == nil then
        RosterItemLevelsDB.options.minimap = {}
    end
    if RosterItemLevelsDB.options.minimap.hide == nil then
        RosterItemLevelsDB.options.minimap.hide = false
    end
    if RosterItemLevelsDB.options.mouseover == nil then
        RosterItemLevelsDB.options.mouseover = true
    end
    if RosterItemLevelsDB.options.itemLevelColor == nil then
        RosterItemLevelsDB.options.itemLevelColor = "GearScore"
    end
    if RosterItemLevelsDB.options.autoToggle == nil then
        RosterItemLevelsDB.options.autoToggle = true
    end
    if RosterItemLevelsDB.options.spec == nil then
        RosterItemLevelsDB.options.spec = true
    end
    if RosterItemLevelsDB.options.role == nil then
        RosterItemLevelsDB.options.role = true
    end
    if type(RosterItemLevelsDB.report) ~= "table" then
        RosterItemLevelsDB.report = {}
    end

    -- RosterItemLevelsPerCharDB
    if type(RosterItemLevelsPerCharDB) ~= "table" then
        RosterItemLevelsPerCharDB = {}
    end
    if type(RosterItemLevelsPerCharDB.window) ~= "table" then
        RosterItemLevelsPerCharDB.window = {}
    end
    if type(RosterItemLevelsPerCharDB.rosterInfo) ~= "table" then
        RosterItemLevelsPerCharDB.rosterInfo = {}
    end
    if type(RosterItemLevelsPerCharDB.rosterInfo.rosterTable) ~= "table" then
        -- We store roster data informations inside a saved variable so that we don't lose it when we relog or reload.
        -- Especially for specID and role which take time to get due to inspection delays.
        -- Saved specID and role are used until we receive updated values.
        RosterItemLevelsPerCharDB.rosterInfo.rosterTable = {}
    end
    if type(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) ~= "table" then
        RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys = {}
    end

    -- Minimap icon
    if minimapIcon and not minimapIcon:IsRegistered(addonName .. "LDB") then
        -- Register and display RosterItemLevels minimap icon.
        minimapIcon:Register(addonName .. "LDB", rosterItemLevelsLDB, RosterItemLevelsDB.options.minimap)
    end

    -- Options panel
    optionsPanel.name = addonName
    InterfaceOptions_AddCategory(optionsPanel)
    optionsPanel.okay = function(self)
        -- Apply changes based on options states.
        local checked = minimapIconCheckButton:GetChecked()
        minimapIconCheckButton:SetChecked(checked)
        RosterItemLevelsDB.options.minimap.hide = not checked

        checked = mouseoverCheckButton:GetChecked()
        mouseoverCheckButton:SetChecked(checked)
        RosterItemLevelsDB.options.mouseover = checked

        RosterItemLevelsDB.options.itemLevelColor = itemLevelColorDropdown.selectedValue

        checked = autoToggleCheckButton:GetChecked()
        autoToggleCheckButton:SetChecked(checked)
        RosterItemLevelsDB.options.autoToggle = checked

        checked = specCheckButton:GetChecked()
        specCheckButton:SetChecked(checked)
        RosterItemLevelsDB.options.spec = checked

        checked = roleCheckButton:GetChecked()
        roleCheckButton:SetChecked(checked)
        RosterItemLevelsDB.options.role = checked
    end
    optionsPanel.cancel = function(self)
        -- Revert changes if any, and set icon to the corresponding state.
        minimapIconCheckButton:SetChecked(not RosterItemLevelsDB.options.minimap.hide)
        if RosterItemLevelsDB.options.minimap.hide then
            minimapIcon:Hide(addonName .. "LDB")
        else
            minimapIcon:Show(addonName .. "LDB")
        end

        mouseoverCheckButton:SetChecked(RosterItemLevelsDB.options.mouseover)
        itemLevelColorDropdown.selectedValue = RosterItemLevelsDB.options.itemLevelColor
        RosterItemLevelsTooltipColorText:SetText(RosterItemLevelsDB.options.itemLevelColor)

        autoToggleCheckButton:SetChecked(RosterItemLevelsDB.options.autoToggle)
        specCheckButton:SetChecked(RosterItemLevelsDB.options.spec)
        roleCheckButton:SetChecked(RosterItemLevelsDB.options.role)
    end

    optionsPanelTitle:SetPoint("TOPLEFT", 16, -16)
    optionsPanelTitle:SetText(addonName)

    local function setCheckButtonProperties(checkButton, label, description)
        checkButton.label = _G[checkButton:GetName() .. "Text"]
        checkButton.label:SetText(label)
        checkButton.tooltipText = label
        checkButton.tooltipRequirement = description
    end

    setCheckButtonProperties(minimapIconCheckButton, "Minimap icon", "Shows " .. addonName .. " icon around your minimap.")
    minimapIconCheckButton:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 24, -44)
    minimapIconCheckButton:SetChecked(not RosterItemLevelsDB.options.minimap.hide)
    minimapIconCheckButton:SetScript("OnClick", function(self)
        if not minimapIconCheckButton:GetChecked() then
            minimapIcon:Hide(addonName .. "LDB")
        else
            minimapIcon:Show(addonName .. "LDB")
        end
    end)

    optionsPanelSubtitleTooltip:SetPoint("TOPLEFT", minimapIconCheckButton, "BOTTOMLEFT", 0, -16)
    optionsPanelSubtitleTooltip:SetText("Tooltip")

    setCheckButtonProperties(mouseoverCheckButton, "Mouseover", "Adds the item level in the tooltip when you mouseover a player.")
    mouseoverCheckButton:SetPoint("TOPLEFT", optionsPanelSubtitleTooltip, "BOTTOMLEFT", 8, -8)
    mouseoverCheckButton:SetChecked(RosterItemLevelsDB.options.mouseover)

    itemLevelColorDropdown:SetPoint("TOPRIGHT", mouseoverCheckButton, "BOTTOMRIGHT", 0, -16)
    itemLevelColorDropdown.selectedValue = RosterItemLevelsDB.options.itemLevelColor
    RosterItemLevelsTooltipColorText:SetText(RosterItemLevelsDB.options.itemLevelColor)
    itemLevelColorDropdown.initialize = function(self)
        local info
        info = UIDropDownMenu_CreateInfo()
        info.text = "Class"
        info.value = "Class"
        info.func = function(self)
            itemLevelColorDropdown.selectedValue = self.value
            RosterItemLevelsTooltipColorText:SetText(self.value)
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "GearScore"
        info.value = "GearScore"
        info.func = function(self)
            itemLevelColorDropdown.selectedValue = self.value
            RosterItemLevelsTooltipColorText:SetText(self.value)
        end
        UIDropDownMenu_AddButton(info)
    end
    itemLevelColorDropdownLabel:SetPoint("BOTTOMLEFT", itemLevelColorDropdown, "TOPLEFT", 16, 3)
    itemLevelColorDropdownLabel:SetText("Item Level Color")

    optionsPanelSubtitleWindow:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 24, -200)
    optionsPanelSubtitleWindow:SetText("Roster Window")

    setCheckButtonProperties(autoToggleCheckButton, "Auto toggle", "Automatically toggles the roster window when joining a group.")
    autoToggleCheckButton:SetPoint("TOPLEFT", optionsPanelSubtitleWindow, "BOTTOMLEFT", 8, -8)
    autoToggleCheckButton:SetChecked(RosterItemLevelsDB.options.autoToggle)

    setCheckButtonProperties(specCheckButton, "Specialization", "Shows specialization of group members in the roster window.")
    specCheckButton:SetPoint("TOPLEFT", autoToggleCheckButton, "BOTTOMLEFT", 0, -8)
    specCheckButton:SetChecked(RosterItemLevelsDB.options.spec)

    setCheckButtonProperties(roleCheckButton, "Role", "Shows role of group members in the roster window.")
    roleCheckButton:SetPoint("TOPLEFT", specCheckButton, "BOTTOMLEFT", 0, -8)
    roleCheckButton:SetChecked(RosterItemLevelsDB.options.role)

    -- Roster window config
    local frameBackdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 16,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    }
    rosterItemLevelsTooltip:SetFrameStrata("LOW")
    rosterItemLevelsTooltip:SetBackdrop(frameBackdrop)
    rosterItemLevelsTooltip:SetPoint(RosterItemLevelsDB.window.point, UIParent, RosterItemLevelsDB.window.point, RosterItemLevelsDB.window.x, RosterItemLevelsDB.window.y)
    rosterItemLevelsTooltip:SetHeight(64)
    rosterItemLevelsTooltip:SetWidth(64)
    rosterItemLevelsTooltip:EnableMouse(true)
    rosterItemLevelsTooltip:SetMovable(1)
    GameTooltip_OnLoad(rosterItemLevelsTooltip)
    rosterItemLevelsTooltip:SetPadding(2, 0)
    rosterItemLevelsTooltip:RegisterForDrag("LeftButton")
    rosterItemLevelsTooltip:SetScript("OnDragStart", function(self)
        if not RosterItemLevelsDB.window.locked then
            self:StartMoving()
        end
    end)
    rosterItemLevelsTooltip:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        RosterItemLevelsDB.window.x = x
        RosterItemLevelsDB.window.y = y
        RosterItemLevelsDB.window.point = point
    end)
    rosterItemLevelsTooltip:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            if _G["DropDownList1"]:IsShown() and UIDROPDOWNMENU_OPEN_MENU == rosterItemLevelsDropDown then
                CloseDropDownMenus()
            else
                UIDropDownMenu_Initialize(rosterItemLevelsDropDown, function(dropdownFrame, level, menuList)
                    local info
                    if level == 1 then
                        info = UIDropDownMenu_CreateInfo()
                        info.text = HIDE
                        info.notCheckable = true
                        info.func = function() toggleOffRosterWindow() end
                        info.arg1 = rosterItemLevelsTooltip
                        UIDropDownMenu_AddButton(info, 1)

                        info = UIDropDownMenu_CreateInfo()
                        info.text = "Lock"
                        if RosterItemLevelsDB.window.locked then
                            info.checked = true
                        end
                        info.func = function() RosterItemLevelsDB.window.locked = not RosterItemLevelsDB.window.locked end
                        UIDropDownMenu_AddButton(info, 1)
                    end
                end)
                ToggleDropDownMenu(1, nil, rosterItemLevelsDropDown, "cursor", 5, -10)
            end
        end
    end)
    -- Set RosterItemLevels command.
    SLASH_ROSTERITEMLEVELS1 = "/ilvls"
    -- Register events unrelated to groups.
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("CINEMATIC_STOP")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    -- Create an animation to render rosterItemLevelsTooltip.
    updater = frame:CreateAnimationGroup()
    updater:SetLooping("REPEAT")
    animation = updater:CreateAnimation()
    -- Listen to system messages.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filterMessageSystem)
    -- Hook GameTooltip to display item level in it.
    GameTooltip:HookScript("OnTooltipSetUnit", mouseoverTooltipHook)
end

-- Minimap icon events
function rosterItemLevelsLDB:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(addonName)
    GameTooltip:AddLine("|cffeda55fClick|r to toggle the roster window.", 0, 1, 0)
    GameTooltip:AddLine("|cffeda55fShift-Click|r to toggle the report window.", 0, 1, 0)
    GameTooltip:AddLine("|cffeda55fRight-Click|r to open the options panel.", 0, 1, 0)
    GameTooltip:Show()
end

function rosterItemLevelsLDB:OnLeave()
    GameTooltip:Hide()
end

function rosterItemLevelsLDB:OnClick(button)
    if button == "LeftButton" and IsShiftKeyDown() then
        SlashCmdList.ROSTERITEMLEVELS(SecureCmdOptionParse("report"))  -- same as "/ilvls report" command.
    elseif button == "LeftButton" then
        SlashCmdList.ROSTERITEMLEVELS("")  -- same as "/ilvls" command. Will toggle On or Off.
    elseif button == "RightButton" then
        InterfaceOptionsFrame_OpenToCategory(addonName)  -- First open generic interface options frame.
        InterfaceOptionsFrame_OpenToCategory(addonName)  -- Then go to RosterItemLevels options panel.
    end
end

function SlashCmdList.ROSTERITEMLEVELS(msg, editbox)
    local arg = string.split(" ", msg)
    if arg == "report" then  -- /ilvls report
        if updater:IsPlaying() then
            openReportWindow()
        else
            print("Roster window must be toggled on to report item levels.")
        end
    elseif arg == "" then  -- /ilvls
        if updater:IsPlaying() then
            toggleOffRosterWindow()
        else
            toggleOnRosterWindow()
        end
    else
        print("Help")
        print("/ilvls [report]")
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)  -- Automatically call the method for this event, if it exists.
end)
