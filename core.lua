-- FirstHit Core Logic for WotLK 3.3.5a
local addonName, addonTable = ...
local frame = CreateFrame("Frame")
_G["FirstHit"] = addonTable

-- State
local currentHits = {}
local pullActive = false
local combatStartTime = 0

-- Centralized pull text detection
local PULL_KEYWORDS = { "pull", "empieza", "start", "inicia", "lanzamiento", "cuenta", "conteo" }
local function IsPullTrigger(text)
    local t = tostring(text or ""):lower()
    for _, kw in ipairs(PULL_KEYWORDS) do
        if t:find(kw) then return true end
    end
    return false
end

-- DBM & BigWigs Integration
local function OnPullStarted()
    if not pullActive then
        pullActive = true
        print("|cff66ffff[FirstHit]|r |cff00ff00Vigilando pull...|r")
    end
end

if DBM and DBM.RegisterCallback then
    local function handleDBMTimer(id, text)
        if IsPullTrigger(text or id) then
            OnPullStarted()
        end
    end
    DBM:RegisterCallback("timerStart", handleDBMTimer)
    DBM:RegisterCallback("DBM_TimerStart", handleDBMTimer)
end

-- BigWigs Support
if BigWigsLoader then
    local function BWCallback(_, _, _, text)
        if IsPullTrigger(text) then
            OnPullStarted()
        end
    end
    if BigWigsLoader.RegisterMessage then
        BigWigsLoader.RegisterMessage(addonTable, "BigWigs_StartBar", BWCallback)
    end
end

-- Shared function to record and announce
local lastRecordTime = 0
local function AddFirstHitEntry(bossName, playerName, playerClass)
    -- Prevent multi-announcements for the same pull (e.g. AOE hitting multiple trash)
    if GetTime() - lastRecordTime < 2 then return end
    lastRecordTime = GetTime()

    if not _G["FirstHitDB"] then _G["FirstHitDB"] = {} end
    
    local entry = {
        boss = bossName,
        player = playerName,
        class = playerClass or "PRIEST",
        time = date("%H:%M:%S")
    }
    
    table.insert(_G["FirstHitDB"], 1, entry)
    if #_G["FirstHitDB"] > 50 then table.remove(_G["FirstHitDB"]) end
    
    if addonTable.UpdateUI then addonTable.UpdateUI() end
    
    -- Announcement to Raid/Party (Only if not silent)
    if not _G["FirstHitSettings"] or not _G["FirstHitSettings"].silent then
        local msg = string.format("[FirstHit] %s fue el primero en golpear a %s!", playerName, bossName)
        if IsInRaid() then
            SendChatMessage(msg, "RAID")
        elseif IsInGroup() then
            SendChatMessage(msg, "PARTY")
        end
    end
    
    local color = RAID_CLASS_COLORS[playerClass] or {r=1, g=1, b=1}
    print(string.format("|cff66ffff[FirstHit]|r |cff%02x%02x%02x%s|r lo hizo en %s", color.r*255, color.g*255, color.b*255, playerName, bossName))
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_RAID_WARNING")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not _G["FirstHitDB"] then _G["FirstHitDB"] = {} end
        if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = {} end
        if _G["FirstHitSettings"].silent == nil then _G["FirstHitSettings"].silent = false end
        if _G["FirstHitSettings"].dbmOnly == nil then _G["FirstHitSettings"].dbmOnly = false end
        if addonTable.UpdateMinimapPosition then addonTable.UpdateMinimapPosition() end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        print("|cff66ffff[FirstHit]|r Cargado. Usa /fh para el historial.")
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatStartTime = GetTime()
        if IsInInstance() then
            print("|cff66ffff[FirstHit]|r Combate iniciado. Buscando primer golpe...")
        end
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        currentHits = {}
        pullActive = false
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "DBM" or prefix == "DBM-Core" then
            -- DBM Pull timers often send PT\t[time] or similar sync messages
            if message:find("^PT\t") or message:find("^Pull\t") then
                OnPullStarted()
            end
        end
        
    elseif event == "CHAT_MSG_RAID_WARNING" then
        local msg = ...
        if msg and IsPullTrigger(msg) and (msg:lower():find("%d+ seg") or msg:lower():find("%d+ sec")) then
            OnPullStarted()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
        
        -- Only actual damage counts as first hit
        if not subevent:find("_DAMAGE") then return end
            
            -- Destination must be a Hostile/Neutral NPC (nil-guard for broken combatlog on private servers)
            if not destFlags or type(destFlags) ~= "number" then return end
            local isNPC = bit.band(destFlags, 0x00000800) ~= 0
            local isEnemy = bit.band(destFlags, 0x00000040) ~= 0 or bit.band(destFlags, 0x00000020) ~= 0
            
            if destName and isNPC and isEnemy then
                if not currentHits[destGUID] then
                    
                    -- Only track if DBM pull was active OR we are in an instance and combat just started
                    local dbmOnly = _G["FirstHitSettings"] and _G["FirstHitSettings"].dbmOnly
                    local inCombat = UnitAffectingCombat("player")
                    
                    local isRaidPull = false
                    if pullActive then
                        isRaidPull = true
                    elseif not dbmOnly and IsInInstance() then
                        -- If we are not in combat yet, this hit IS the pull.
                        -- If we ARE in combat, only count hits within the first 10 seconds (handles initial pack pull).
                        if not inCombat or (GetTime() - combatStartTime < 10) then
                            isRaidPull = true
                        end
                    end
                    
                    if isRaidPull then
                        -- Source must be from our group (nil-guard for broken combatlog)
                        if not sourceFlags or type(sourceFlags) ~= "number" then return end
                        -- 0x7 = COMBATLOG_OBJECT_AFFILIATION_MINE | PARTY | RAID
                        local isFromGroup = bit.band(sourceFlags, 0x00000007) ~= 0
                        
                        -- Also check if it's a pet of a group member
                        if not isFromGroup then
                            local isPet = bit.band(sourceFlags, 0x00001000) ~= 0
                            if isPet then
                                isFromGroup = bit.band(sourceFlags, 0x00000007) ~= 0
                            end
                        end

                        if sourceName and isFromGroup then
                            local _, playerClass = UnitClass(sourceName)
                            if not playerClass then
                                playerClass = select(2, UnitClass("player"))
                            end
                            currentHits[destGUID] = GetTime()
                            pullActive = false
                            AddFirstHitEntry(destName, sourceName, playerClass)
                        end
                    end
                end
            end
    end
end)

-- Slash commands
SLASH_FIRSTHIT1 = "/fh"
SLASH_FIRSTHIT2 = "/firsthit"
SlashCmdList["FIRSTHIT"] = function(msg)
    if addonTable.ToggleUI then addonTable.ToggleUI() end
end

-- Test command
SLASH_FHTEST1 = "/fhtest"
SlashCmdList["FHTEST"] = function()
    print("|cff66ffff[FirstHit]|r Generando entrada de prueba...")
    AddFirstHitEntry("Boss de Prueba", UnitName("player"), select(2, UnitClass("player")))
end
