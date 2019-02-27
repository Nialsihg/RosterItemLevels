local addonName = "RosterItemLevels"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local rosterItemLevelsWindow = CreateFrame("GameTooltip", addonName .. "Frame", UIParent, "GameTooltipTemplate")

-- Options Panel.
local optionsPanel = CreateFrame("Frame")
local optionsPanelTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
local autoToggleCheckButton = CreateFrame("CheckButton", addonName .. "AutoToggle", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local minimapIconCheckButton = CreateFrame("CheckButton", addonName .. "MinimapIcon", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local specIconCheckButton = CreateFrame("CheckButton", addonName .. "ShowSpec", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
local mouseoverCheckButton = CreateFrame("CheckButton", addonName .. "Mouseover", optionsPanel, "InterfaceOptionsCheckButtonTemplate")

-- Load libs for easy UI creation and autocompletion in EditBox.
-- Used to create a report window.
local AceGUI = LibStub("AceGUI-3.0")
local AutoComplete = LibStub("AceGUI-3.0-Completing-EditBox")
local reportWindow  -- Used to store AceGUI's Window container object.

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

local updateDelay = 5  -- Elapsed time between updates in seconds.
local ticker, updater, animation, processedChatFrame
local mouseoverredPlayersTable, mouseoverItemLevelQueries, rosterLeaversTimes = {}, {}, {}

local leaderIconPath = [[Interface\GROUPFRAME\UI-Group-LeaderIcon]]
local roleIconPaths = {  -- ElvUI's role icon files.
	TANK = "Interface\\AddOns\\" .. addonName .. "\\textures\\tank",
	HEALER = "Interface\\AddOns\\" .. addonName .. "\\textures\\healer",
	DAMAGER = "Interface\\AddOns\\" .. addonName .. "\\textures\\dps"
}
local specIconPaths = {
	[577] = [[Interface\Icons\ability_demonhunter_specdps]],		-- Havoc Demon Hunter
	[581] = [[Interface\Icons\ability_demonhunter_spectank]],		-- Vengeance Demon Hunter

	[250] = [[Interface\Icons\spell_deathknight_bloodpresence]],	-- Death Knight Blood
	[251] = [[Interface\Icons\spell_deathknight_frostpresence]],	-- Death Knight Frost
	[252] = [[Interface\Icons\spell_deathknight_unholypresence]],	-- Death Knight Unholy
	
	[102] = [[Interface\Icons\spell_nature_starfall]],				-- Druid Balance
	[103] = [[Interface\Icons\ability_druid_catform]],				-- Druid Feral
	[104] = [[Interface\Icons\ability_racial_bearform]],			-- Druid Guardian
	[105] = [[Interface\Icons\spell_nature_healingtouch]],			-- Druid Restoration

	[253] = [[Interface\Icons\ability_hunter_bestialdiscipline]],	-- Hunter Beast Mastery
	[254] = [[Interface\Icons\ability_hunter_focusedaim]],			-- Hunter Marksmanship
	[255] = [[Interface\Icons\ability_hunter_camouflage]],			-- Hunter Survival
	
	[62] = [[Interface\Icons\spell_holy_magicalsentry]],			-- Mage Arcane
	[63] = [[Interface\Icons\spell_fire_firebolt02]],				-- Mage Fire
	[64] = [[Interface\Icons\spell_frost_frostbolt02]],				-- Mage Frost
	
	[268] = [[Interface\Icons\spell_monk_brewmaster_spec]],			-- Monk Brewmaster
	[269] = [[Interface\Icons\spell_monk_windwalker_spec]],			-- Monk Windwalker
	[270] = [[Interface\Icons\spell_monk_mistweaver_spec]],			-- Monk Mistweaver
	
	[65] = [[Interface\Icons\spell_holy_holybolt]],					-- Paladin Holy
	[66] = [[Interface\Icons\ability_paladin_shieldofthetemplar]],	-- Paladin Protection
	[70] = [[Interface\Icons\spell_holy_auraoflight]],				-- Paladin Retribution
	
	[256] = [[Interface\Icons\spell_holy_powerwordshield]],			-- Priest Discipline
	[257] = [[Interface\Icons\spell_holy_guardianspirit]],			-- Priest Holy
	[258] = [[Interface\Icons\spell_shadow_shadowwordpain]],		-- Priest Shadow
	
	[259] = [[Interface\Icons\ability_rogue_eviscerate]],			-- Rogue Assassination
	[260] = [[Interface\Icons\inv_sword_30]],						-- Rogue Outlaw
	[261] = [[Interface\Icons\ability_stealth]],					-- Rogue Subtlety
	
	[262] = [[Interface\Icons\spell_nature_lightning]],				-- Shaman Elemental
	[263] = [[Interface\Icons\spell_shaman_improvedstormstrike]],	-- Shamen Enhancement
	[264] = [[Interface\Icons\spell_nature_healingwavegreater]],	-- Shaman Restoration
	
	[265] = [[Interface\Icons\spell_shadow_deathcoil]],				-- Warlock Affliction
	[266] = [[Interface\Icons\spell_shadow_metamorphosis]],			-- Warlock Demonology
	[267] = [[Interface\Icons\spell_shadow_rainoffire]],			-- Warlock Destruction
	
	[71] = [[Interface\Icons\ability_warrior_savageblow]],			-- Warrior Arms
	[72] = [[Interface\Icons\ability_warrior_innerrage]],			-- Warrior Fury
	[73] = [[Interface\Icons\ability_warrior_defensivestance]],		-- Warrior Protection
}

-- Cache frequently used globals in locals.
local GetTime = GetTime
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitClass = UnitClass
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

local function trim(s)  -- from http://lua-users.org/wiki/StringTrim
	local from = s:match"^%s*()"
	return from > #s and "" or s:match(".*%S", from)
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
		return sortFunction(RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName1].ilvl, RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName2].ilvl)
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

local function updateRosterTableDependencies()
	RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys = sortRosterTableKeys(sortDesc)
	RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel = computeAverageRosterItemLevel()
end

local function resetRosterInfo()
	wipe(RosterItemLevelsPerCharDB.rosterInfo.rosterTable)
	wipe(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys)
	RosterItemLevelsPerCharDB.rosterInfo.leaderName = ""
	RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel = 0
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
		RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] = nil
	end
	updateRosterTableDependencies()
	return #removedFromRoster
end

local function updateGroupLeader()
	if UnitIsGroupLeader("player") then
		RosterItemLevelsPerCharDB.rosterInfo.leaderName = UnitName("player")
		return
	end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			if UnitIsGroupLeader("raid" .. i) then
				RosterItemLevelsPerCharDB.rosterInfo.leaderName = UnitName("raid" .. i)
				return
			end
		end
	elseif IsInGroup() then
		for i = 1, GetNumSubgroupMembers() do
			if UnitIsGroupLeader("party" .. i) then
				RosterItemLevelsPerCharDB.rosterInfo.leaderName = UnitName("party" .. i)
				return
			end
		end
	end
end

local function unitNameToUnitID(unitName)
	-- Look in cache first.
	if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] and RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].lastKnownUnitID then
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
	end
	-- no return if unitName is not in our group.
end

local function updateUnitInfo(unitName, unitID, itemLevel)
	if not RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] then
		RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] = {}
	end
	if not RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class then
		local _, class = UnitClass(unitID)
		RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class = class
	end
	local unitInfo = LibGroupInspect:GetCachedInfo(UnitGUID(unitID))  -- Most likely nil if we just relogged/reloaded
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
	updateRosterTableDependencies()
end

local function filterMessageSystem(chatFrame, event, msg, ...)
	-- Note: Ugly work around. A proper fix would require to treat the cause of those messages.
	-- Filter "Away" message flood when going AFK with window toggled on. Related to the use of the EMOTE channeL.
	-- Filter "Invalid character" which might be returned by .ilvl command.
	if string_find(msg, "Invalid character") or string_find(msg, "You are now Away") or string_find(msg, "You are no longer Away") then
		return true  
	end
	if not string_find(msg, "Equipped ilvl for") then
		return false  -- not the message we'r looking for, don't filter.
	end
	if not processedChatFrame then
		processedChatFrame = chatFrame  -- saves the chatFrame that we want to process data from.
	end
	if chatFrame ~= processedChatFrame then
		return true  -- filter the message from all chatFrames but only process data from processedChatFrame.
	end
	local unitName, itemLevel = string_match(msg, "Equipped ilvl for (%a+): ([0-9]+)")
	if mouseoverItemLevelQueries[unitName] then
		mouseoverredPlayersTable[unitName].ilvl = itemLevel
		mouseoverredPlayersTable[unitName].lastUpdateTime = GetTime()
		if unitName == GameTooltip:GetUnit() then  -- mouse is still over the unit we received a message for.
			local class = mouseoverredPlayersTable[unitName].class
			GameTooltip:AddDoubleLine("Item Level", 
				itemLevel,
				RAID_CLASS_COLORS[class].r,
				RAID_CLASS_COLORS[class].g,
				RAID_CLASS_COLORS[class].b,
				RAID_CLASS_COLORS[class].r,
				RAID_CLASS_COLORS[class].g,
				RAID_CLASS_COLORS[class].b)
			GameTooltip:Show()
		end
		mouseoverItemLevelQueries[unitName] = nil
		return true  -- filter messages sent from mouseovers.
	end
	if not updater:IsPlaying() then
		return false  -- roster window is not open, don't filter.
	end
	if rosterLeaversTimes[unitName] then
		if GetTime() - rosterLeaversTimes[unitName] <= 1 then
			return true  -- we received a message for a unit that just left the group, filter it.
		end
	end
	local unitID = unitNameToUnitID(unitName)
	if not unitID then
		if IsInRaid() or IsInGroup() then
			return false  -- unit is not in the group, don't filter.
		else
			return true  -- we left the group but we are still receiving messages from last update, keep filtering.
		end
	end
	updateUnitInfo(unitName, unitID, itemLevel)
	return true
end

local function queryUnitItemLevel(unitNameOrID)
	local unitName = UnitName(unitNameOrID) or unitNameOrID
	if unitName then
		SendChatMessage(".ilvl " .. unitName, "EMOTE")  -- Will call filterMessageSystem() on server response.
	end
end

local function queryRosterItemLevels()
	if UnitIsDeadOrGhost("player") then
		return  -- Prevents error message: "You can't chat when you're dead!" due to the use of the EMOTE channel.
	end 
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			queryUnitItemLevel("raid" .. i)
		end
	elseif IsInGroup() then
		for i = 1, GetNumSubgroupMembers() do
			queryUnitItemLevel("party" .. i)
		end
		queryUnitItemLevel("player")
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
	reportWindow.LayoutFinished = function(self, _, height) reportWindow:SetHeight(height + 57) end  -- AceGUI hack to auto-set height of Window widget.
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
			local pos = { reportWindow:GetPoint() }
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

local function renderRosterItemLevelsWindow()
	rosterItemLevelsWindow:ClearLines()
	rosterItemLevelsWindow:SetText("Roster Item Levels", 1, 1, 1)
	if #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys >= 1 then
		for _, unitName in ipairs(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) do
			if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName] then
				local roleIcon, specIcon, stringLeft = "", "", ""
				local class = RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].class
				if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role then
					roleIcon = "|T" .. roleIconPaths[RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].role] .. ":15:15:0:0:64:64:2:56:2:56|t"
					stringLeft = roleIcon
				end
				if RosterItemLevelsDB.options.spec then
					if RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].specID then
						specIcon = "|T" .. specIconPaths[RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].specID] .. ":15:15:0:0:64:64:2:56:2:56|t"
						stringLeft = stringLeft .. " " .. specIcon
					end
				end
				stringLeft = stringLeft .. " " .. unitName
				if unitName == RosterItemLevelsPerCharDB.rosterInfo.leaderName then
					stringLeft = stringLeft .. " |T" .. leaderIconPath .. ":15:15:0:0:64:64:2:56:2:56|t"
				end
				rosterItemLevelsWindow:AddDoubleLine(
					stringLeft,
					RosterItemLevelsPerCharDB.rosterInfo.rosterTable[unitName].ilvl,
					RAID_CLASS_COLORS[class].r,
					RAID_CLASS_COLORS[class].g,
					RAID_CLASS_COLORS[class].b,
					RAID_CLASS_COLORS[class].r,
					RAID_CLASS_COLORS[class].g,
					RAID_CLASS_COLORS[class].b)
			end
		end
		if #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys >= 2 then
			rosterItemLevelsWindow:AddLine(" ", 1, 1, 1)
			rosterItemLevelsWindow:AddDoubleLine(
				"Average (" .. #RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys .. ")",
				RosterItemLevelsPerCharDB.rosterInfo.avgRosterItemLevel, 1, 1, 1, 1, 1, 1)
		end
	end
	rosterItemLevelsWindow:Show()
end

local function toggleOffRosterWindow()
	ticker:Cancel()
	updater:Stop()
	rosterItemLevelsWindow:Hide()
end

local function toggleOnRosterWindow()
	rosterItemLevelsWindow:Show()
	rosterItemLevelsWindow:SetOwner(UIParent, "ANCHOR_PRESERVE")
	updater:SetScript("OnLoop", renderRosterItemLevelsWindow)
	updater:Play()
	queryRosterItemLevels()
	ticker = C_Timer.NewTicker(updateDelay, queryRosterItemLevels)
end

local function toggleOnRosterWindowAfterDelay(delay)
	C_Timer.After(delay, function()
		if not updater:IsPlaying() then
			toggleOnRosterWindow()
		end
	end)
end

local function mouseoverTooltipHook()
	if not RosterItemLevelsDB.options.mouseover then
		return
	end
	local unitName, unitID = GameTooltip:GetUnit()
	if UnitExists(unitID) and UnitIsPlayer(unitID) then  -- Note: true when unitID isn't connected and inside our group.
		if UnitIsConnected(unitID) then  -- must be connected to use command .ilvl
			if mouseoverredPlayersTable[unitName] then
				if mouseoverredPlayersTable[unitName].lastUpdateTime and GetTime() - mouseoverredPlayersTable[unitName].lastUpdateTime < updateDelay then
					local class = mouseoverredPlayersTable[unitName].class
					GameTooltip:AddDoubleLine(
						"Item Level",
						mouseoverredPlayersTable[unitName].ilvl,
						RAID_CLASS_COLORS[class].r,
						RAID_CLASS_COLORS[class].g,
						RAID_CLASS_COLORS[class].b,
						RAID_CLASS_COLORS[class].r,
						RAID_CLASS_COLORS[class].g,
						RAID_CLASS_COLORS[class].b)
					GameTooltip:Show()
				else  -- data is too old, send new ilvl query
					if not mouseoverItemLevelQueries[unitName] then  -- make sure a query is not already pending.
						mouseoverItemLevelQueries[unitName] = true
						queryUnitItemLevel(unitName)
					end
				end
			else  -- first time we mouseover this unit.
				mouseoverredPlayersTable[unitName] = {}
				if not mouseoverredPlayersTable[unitName].class then
					local _, class = UnitClass(unitID)
					mouseoverredPlayersTable[unitName].class = class
				end
				if not mouseoverItemLevelQueries[unitName] then
					mouseoverItemLevelQueries[unitName] = true
					queryUnitItemLevel(unitName)
				end
			end
		else  -- isn't connected, can't refresh his ilvl so look for a cached value.
			if mouseoverredPlayersTable[unitName] and mouseoverredPlayersTable[unitName].ilvl then
				local class = mouseoverredPlayersTable[unitName].class
				GameTooltip:AddDoubleLine(
					"Item Level",
					mouseoverredPlayersTable[unitName].ilvl,
					RAID_CLASS_COLORS[class].r,
					RAID_CLASS_COLORS[class].g,
					RAID_CLASS_COLORS[class].b,
					RAID_CLASS_COLORS[class].r,
					RAID_CLASS_COLORS[class].g,
					RAID_CLASS_COLORS[class].b)
				GameTooltip:Show()
			end
		end
	end
end

function frame:CINEMATIC_STOP()
	-- Fix a bug were the window would lose its owner after a cinematic.
	if updater:IsPlaying() then  -- window was shown before the cinematic, set his owner back.
		rosterItemLevelsWindow:SetOwner(UIParent, "ANCHOR_PRESERVE")
	end
end

function frame:PLAYER_LEAVING_WORLD()
	RosterItemLevelsPerCharDB.window.wasShown = rosterItemLevelsWindow:IsShown()  -- save window state in DB in case of a reload/relog.
end

function frame:PARTY_LEADER_CHANGED()
	updateGroupLeader()
end

function frame:GROUP_ROSTER_UPDATE()  -- A player joined or left the group.
	local numGroupMembersRemoved = cleanRosterTable()  -- Remove the player from the DB if he left.
	if updater:IsPlaying() and numGroupMembersRemoved == 0 then
		-- A player joined, start a new update.
		ticker:Cancel()
		queryRosterItemLevels()
		ticker = C_Timer.NewTicker(updateDelay, queryRosterItemLevels)
	end
end

function frame:GROUP_LEFT()
	self:UnregisterEvent("GROUP_LEFT")
	self:UnregisterEvent("CINEMATIC_STOP")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("PARTY_LEADER_CHANGED")
	if updater:IsPlaying() then
		toggleOffRosterWindow()
	end
	resetRosterInfo()
end

function frame:GROUP_JOINED()
	self:RegisterEvent("GROUP_LEFT")
	self:RegisterEvent("CINEMATIC_STOP")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("PARTY_LEADER_CHANGED")
	if RosterItemLevelsDB.options.autoToggle then
		toggleOnRosterWindowAfterDelay(0.5)
	end
end

function frame:PLAYER_LOGIN()  -- Registers on login / reload.
	self:RegisterEvent("GROUP_JOINED")
	if IsInRaid() or IsInGroup() then
		self:RegisterEvent("GROUP_LEFT")
		self:RegisterEvent("CINEMATIC_STOP")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PARTY_LEADER_CHANGED")
		LibGroupInspect:Rescan()
		updateGroupLeader()
		if RosterItemLevelsPerCharDB.window.wasShown then
			toggleOnRosterWindowAfterDelay(0.5)
		end
	else
		-- Wipe old data in case we left a group while we were reloging or reloading.
		resetRosterInfo()
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
	if type(RosterItemLevelsDB.options) ~= "table" then
		RosterItemLevelsDB.options = {}
	end
	if RosterItemLevelsDB.options.autoToggle == nil then
		RosterItemLevelsDB.options.autoToggle = true
	end
	if RosterItemLevelsDB.options.spec == nil then
		RosterItemLevelsDB.options.spec = true
	end
	if RosterItemLevelsDB.options.mouseover == nil then
		RosterItemLevelsDB.options.mouseover = true
	end
	if RosterItemLevelsDB.options.minimap == nil then
		RosterItemLevelsDB.options.minimap = {}
	end
	if RosterItemLevelsDB.options.minimap.hide == nil then
		RosterItemLevelsDB.options.minimap.hide = false
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
		-- Especially for specID and role which takes time to get due to inspection delays.
		-- Saved specID and role are used until we receive updated values.
		RosterItemLevelsPerCharDB.rosterInfo.rosterTable = {}
	end
	if type(RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys) ~= "table" then
		RosterItemLevelsPerCharDB.rosterInfo.sortedRosterTableKeys = {}
	end

	-- Minimap icon
	if minimapIcon and not minimapIcon:IsRegistered(addonName .. "LDB") then
		minimapIcon:Register(addonName .. "LDB", rosterItemLevelsLDB, RosterItemLevelsDB.options.minimap)  -- Register and display icon on minimap.
	end

	-- Options panel
	optionsPanel.name = addonName
	InterfaceOptions_AddCategory(optionsPanel)
	optionsPanel.okay = function(self)
		-- Apply changes based on checkbutton state.
		local checked = minimapIconCheckButton:GetChecked()
		minimapIconCheckButton:SetChecked(checked)
		RosterItemLevelsDB.options.minimap.hide = not checked

		checked = autoToggleCheckButton:GetChecked()
		autoToggleCheckButton:SetChecked(checked)
		RosterItemLevelsDB.options.autoToggle = checked

		checked = specIconCheckButton:GetChecked()
		specIconCheckButton:SetChecked(checked)
		RosterItemLevelsDB.options.spec = checked

		checked = mouseoverCheckButton:GetChecked()
		mouseoverCheckButton:SetChecked(checked)
		RosterItemLevelsDB.options.mouseover = checked
	end
	optionsPanel.cancel = function(self)
		-- Revert changes if any, and set icon to the corresponding state.
		minimapIconCheckButton:SetChecked(not RosterItemLevelsDB.options.minimap.hide)
		if RosterItemLevelsDB.options.minimap.hide then
			minimapIcon:Hide(addonName .. "LDB")
		else
			minimapIcon:Show(addonName .. "LDB")
		end

		autoToggleCheckButton:SetChecked(RosterItemLevelsDB.options.autoToggle)

		specIconCheckButton:SetChecked(RosterItemLevelsDB.options.spec)

		mouseoverCheckButton:SetChecked(RosterItemLevelsDB.options.mouseover)
	end

	optionsPanelTitle:SetPoint("TOPLEFT", 16, -16)
	optionsPanelTitle:SetText(addonName)

	local function setCheckButtonProperties(checkButton, label, description)
		checkButton.label = _G[checkButton:GetName() .. "Text"]
		checkButton.label:SetText(label)
		checkButton.tooltipText = label
		checkButton.tooltipRequirement = description
	end

	setCheckButtonProperties(autoToggleCheckButton, "Auto toggle", "Automatically toggles the roster window when joining a group.")
	autoToggleCheckButton:SetPoint("TOPLEFT", optionsPanelTitle, "BOTTOMLEFT", -2, -16)
	autoToggleCheckButton:SetChecked(RosterItemLevelsDB.options.autoToggle)

	setCheckButtonProperties(minimapIconCheckButton, "Minimap icon", "Shows " .. addonName .. " icon around your minimap.")
	minimapIconCheckButton:SetPoint("TOPLEFT", autoToggleCheckButton, "BOTTOMLEFT", 0, -8)
	minimapIconCheckButton:SetChecked(not RosterItemLevelsDB.options.minimap.hide)
	minimapIconCheckButton:SetScript("OnClick", function(self)
		if not minimapIconCheckButton:GetChecked() then
			minimapIcon:Hide(addonName .. "LDB")
		else
			minimapIcon:Show(addonName .. "LDB")
		end
	end)

	setCheckButtonProperties(specIconCheckButton, "Specializations", "Shows specializations of group members in the roster window.")
	specIconCheckButton:SetPoint("TOPLEFT", minimapIconCheckButton, "BOTTOMLEFT", 2, -8)
	specIconCheckButton:SetChecked(RosterItemLevelsDB.options.spec)

	setCheckButtonProperties(mouseoverCheckButton, "Mouseover", "Adds the item level in the gametooltip when you mouseover a player.")
	mouseoverCheckButton:SetPoint("TOPLEFT", specIconCheckButton, "BOTTOMLEFT", 2, -8)
	mouseoverCheckButton:SetChecked(RosterItemLevelsDB.options.mouseover)
	
	-- RosterItemLevels window config
	local frameBackdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tile = true,
		tileSize = 16,
		insets = { left = 2, right = 14, top = 2, bottom = 2 }
	}
	rosterItemLevelsWindow:SetFrameStrata("LOW")
	rosterItemLevelsWindow:SetBackdrop(frameBackdrop)
	rosterItemLevelsWindow:SetPoint(RosterItemLevelsDB.window.point, UIParent, RosterItemLevelsDB.window.point, RosterItemLevelsDB.window.x, RosterItemLevelsDB.window.y)
	rosterItemLevelsWindow:SetHeight(64)
	rosterItemLevelsWindow:SetWidth(64)
	rosterItemLevelsWindow:EnableMouse(true)
	rosterItemLevelsWindow:SetMovable(1)
	GameTooltip_OnLoad(rosterItemLevelsWindow)
	rosterItemLevelsWindow:SetPadding(16, 0)
	rosterItemLevelsWindow:RegisterForDrag("LeftButton")
	rosterItemLevelsWindow:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	rosterItemLevelsWindow:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		RosterItemLevelsDB.window.x = x
		RosterItemLevelsDB.window.y = y
		RosterItemLevelsDB.window.point = point
	end)
	
	SLASH_ROSTERITEMLEVELS1 = "/ilvls"

	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")

	-- Create an animation to render rosterItemLevelsWindow.
	updater = frame:CreateAnimationGroup()
	updater:SetLooping("REPEAT")
	animation = updater:CreateAnimation()
	animation:SetDuration(0.05)

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filterMessageSystem)
	GameTooltip:HookScript("OnTooltipSetUnit", mouseoverTooltipHook)
end

-- Minimap icon events
function rosterItemLevelsLDB:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:SetText(addonName)
	GameTooltip:AddLine("|cffeda55fClick|r to toggle roster window.", 0, 1, 0)
	GameTooltip:AddLine("|cffeda55fShift-Click|r to report roster item levels.", 0, 1, 0)
	GameTooltip:AddLine("|cffeda55fRight-Click|r to open options panel.", 0, 1, 0)
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
		InterfaceOptionsFrame_OpenToCategory(addonName)  -- First open generic interface options frame
		InterfaceOptionsFrame_OpenToCategory(addonName)  -- Then go to RosterItemLevels options frame.
	end
end

function SlashCmdList.ROSTERITEMLEVELS(msg, editbox)
	if not IsInRaid() and not IsInGroup() then
		print("You must be in a group to toggle the roster window.")
		return
	end
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
