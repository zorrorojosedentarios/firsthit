-- FirstHit UI Logic (Premium & Resizable Version)
local addonName, addonTable = ...
local frame = CreateFrame("Frame", "FirstHitMainFrame", UIParent)
addonTable.UI = frame

-- Initial state
frame:SetSize(380, 480)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG") -- Ensure it sits above other background addons
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetMinResize(250, 300)
frame:SetMaxResize(800, 800)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = {} end
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    _G["FirstHitSettings"].uiPos = { point, relativePoint, xOfs, yOfs }
end)
frame:Hide()

-- Dark glassmorphism background
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
frame:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

-- Title Bar
local header = frame:CreateTexture(nil, "OVERLAY")
header:SetHeight(34)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
header:SetGradientAlpha("HORIZONTAL", 0.0, 0.4, 0.8, 0.9, 0.0, 0.1, 0.2, 0.9)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
title:SetPoint("LEFT", header, "LEFT", 12, 0)
title:SetText("Registro de Primer Golpe")

-- Close Button (X)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)

-- Help Button (?)
local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
helpBtn:SetSize(20, 20)
helpBtn:SetPoint("RIGHT", closeBtn, "LEFT", 6, 0)
helpBtn:SetText("?")
helpBtn:SetScript("OnClick", function()
    if FirstHitHelpFrame and FirstHitHelpFrame:IsVisible() then
        FirstHitHelpFrame:Hide()
    else
        if not FirstHitHelpFrame then
            local hf = CreateFrame("Frame", "FirstHitHelpFrame", frame)
            hf:SetSize(320, 270)
            hf:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
            hf:SetFrameStrata("DIALOG")
            
            hf:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            hf:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
            hf:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
            
            local title = hf:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            title:SetPoint("TOP", 0, -10)
            title:SetText("Ayuda de FirstHit")
            
            local text = hf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("TOPLEFT", 12, -35)
            text:SetPoint("BOTTOMRIGHT", -12, 10)
            text:SetJustifyH("LEFT")
            text:SetJustifyV("TOP")
            text:SetText("FirstHit detecta quién da el primer golpe a un jefe.\n\n" ..
                "|cffffffffAutomático:|r Escucha los contadores de DBM o cuando entras en combate en banda.\n\n" ..
                "|cffffffffBotones:|r\n" ..
                "- |cffaaaaaaLIMPIAR:|r Borra el historial actual.\n" ..
                "- |cffaaaaaaANUNCIAR:|r Manda un resumen de los primeros golpes al chat de banda.\n\n" ..
                "|cffffffffOpciones:|r\n" ..
                "- |cffaaaaaaSolo DBM:|r Solo registra el golpe si hubo una cuenta atrás de DBM.\n" ..
                "- |cffaaaaaaSilencio:|r Evita que el addon anuncie automáticamente en el chat al detectar el golpe.\n\n" ..
                "Comandos: /fh o /firsthit")
                
            local closeH = CreateFrame("Button", nil, hf, "UIPanelCloseButton")
            closeH:SetPoint("TOPRIGHT", hf, "TOPRIGHT", 2, 2)
        end
        FirstHitHelpFrame:Show()
    end
end)

-- Resizer Handle (Bottom Right)
local resizer = CreateFrame("Button", nil, frame)
resizer:SetSize(16, 16)
resizer:SetPoint("BOTTOMRIGHT", -2, 2)
resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizer:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
resizer:SetScript("OnMouseUp", function() 
    frame:StopMovingOrSizing() 
    if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = {} end
    _G["FirstHitSettings"].uiWidth = frame:GetWidth()
    _G["FirstHitSettings"].uiHeight = frame:GetHeight()
    UpdateUI()
end)

-- List Background
local listBG = frame:CreateTexture(nil, "BACKGROUND")
listBG:SetPoint("TOPLEFT", 10, -44)
listBG:SetPoint("BOTTOMRIGHT", -10, 50)
listBG:SetTexture(0, 0, 0, 0.3)

-- Scroll Area
local scrollFrame = CreateFrame("ScrollFrame", "FirstHitScrollFrame", frame, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -45)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 55)

local rows = {}
local rowCount = 20 -- Support more rows for tall windows

for i = 1, rowCount do
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 10, -45 - (i-1)*34)
    row:SetPoint("RIGHT", -32, 0) -- Dynamic width
    
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(1, 1, 1, 0.03)
    
    local bossLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("LEFT", 8, 0)
    bossLabel:SetWidth(140)
    bossLabel:SetJustifyH("LEFT")
    
    local playerLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    playerLabel:SetPoint("LEFT", bossLabel, "RIGHT", 10, 0)
    playerLabel:SetWidth(100)
    playerLabel:SetJustifyH("LEFT")
    
    local timeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    timeLabel:SetPoint("RIGHT", -8, 0)
    timeLabel:SetWidth(60)
    timeLabel:SetJustifyH("RIGHT")
    
    row.boss = bossLabel
    row.player = playerLabel
    row.time = timeLabel
    rows[i] = row
end

local function UpdateUI()
    if not frame:IsVisible() then return end
    
    local db = _G["FirstHitDB"] or {}
    -- Calculate visible rows based on frame height
    local frameHeight = frame:GetHeight()
    local visibleRows = math.floor((frameHeight - 100) / 34)
    if visibleRows > rowCount then visibleRows = rowCount end
    if visibleRows < 1 then visibleRows = 1 end

    FauxScrollFrame_Update(scrollFrame, #db, visibleRows, 34)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    
    for i = 1, rowCount do
        local idx = i + offset
        local row = rows[i]
        
        if i <= visibleRows and idx <= #db then
            local data = db[idx]
            row.boss:SetText(data.boss or "Desconocido")
            
            local classColor = RAID_CLASS_COLORS[data.class]
            if classColor then
                row.player:SetText(string.format("|cff%02x%02x%02x%s|r", classColor.r*255, classColor.g*255, classColor.b*255, data.player))
            else
                row.player:SetText(data.player)
            end
            
            row.time:SetText(data.time or "--")
            row:Show()
        else
            row:Hide()
        end
    end
end

scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 34, UpdateUI)
end)

frame:SetScript("OnSizeChanged", UpdateUI)

-- Styling for buttons
local function StyleButton(btn)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    
    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.4, 0.8, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.2, 1) end)
end

-- Footer Buttons
local clearBtn = CreateFrame("Button", nil, frame)
clearBtn:SetSize(80, 24)
clearBtn:SetPoint("BOTTOMLEFT", 12, 12)
clearBtn:SetText("LIMPIAR")
StyleButton(clearBtn)
clearBtn:SetScript("OnClick", function() _G["FirstHitDB"] = {}; UpdateUI() end)

local announceBtn = CreateFrame("Button", nil, frame)
announceBtn:SetSize(80, 24)
announceBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
announceBtn:SetText("ANUNCIAR")
StyleButton(announceBtn)
announceBtn:SetScript("OnClick", function()
    local db = _G["FirstHitDB"] or {}
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel or #db == 0 then return end
    SendChatMessage("--- [FirstHit] Resumen ---", channel)
    for i = 1, math.min(#db, 5) do
        local d = db[i]
        SendChatMessage(string.format("%d. %s -> %s", i, d.boss, d.player), channel)
    end
end)

-- Silent Mode Checkbox
local silentCheck = CreateFrame("CheckButton", "FirstHitSilentCheck", frame, "UICheckButtonTemplate")
silentCheck:SetPoint("BOTTOMRIGHT", -150, 10)
silentCheck:SetSize(24, 24)
_G[silentCheck:GetName() .. "Text"]:SetText("Silencio")
_G[silentCheck:GetName() .. "Text"]:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

silentCheck:SetScript("OnClick", function(self)
    if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = { silent = false, dbmOnly = false } end
    _G["FirstHitSettings"].silent = self:GetChecked()
    if _G["FirstHitSettings"].silent then
        print("|cff66ffff[FirstHit]|r Modo silencio activado.")
    else
        print("|cff66ffff[FirstHit]|r Modo silencio desactivado.")
    end
end)

-- Only DBM Pull Checkbox
local dbmOnlyCheck = CreateFrame("CheckButton", "FirstHitDBMOnlyCheck", frame, "UICheckButtonTemplate")
dbmOnlyCheck:SetPoint("BOTTOMRIGHT", -230, 10)
dbmOnlyCheck:SetSize(24, 24)
_G[dbmOnlyCheck:GetName() .. "Text"]:SetText("Solo DBM")
_G[dbmOnlyCheck:GetName() .. "Text"]:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

dbmOnlyCheck:SetScript("OnClick", function(self)
    if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = { silent = false, dbmOnly = false } end
    _G["FirstHitSettings"].dbmOnly = self:GetChecked()
    if _G["FirstHitSettings"].dbmOnly then
        print("|cff66ffff[FirstHit]|r Registrando solo pulls de DBM.")
    else
        print("|cff66ffff[FirstHit]|r Registrando todos los combates.")
    end
end)

local closeBottomBtn = CreateFrame("Button", nil, frame)
closeBottomBtn:SetSize(80, 24)
closeBottomBtn:SetPoint("BOTTOMRIGHT", -12, 12)
closeBottomBtn:SetText("CERRAR")
StyleButton(closeBottomBtn)
closeBottomBtn:SetScript("OnClick", function() frame:Hide() end)

addonTable.UpdateUI = UpdateUI
addonTable.ToggleUI = function()
    if frame:IsVisible() then
        frame:Hide()
    else
        if _G["FirstHitSettings"] then
            if _G["FirstHitSettings"].silent ~= nil then silentCheck:SetChecked(_G["FirstHitSettings"].silent) end
            if _G["FirstHitSettings"].dbmOnly ~= nil then dbmOnlyCheck:SetChecked(_G["FirstHitSettings"].dbmOnly) end
            
            if _G["FirstHitSettings"].uiPos then
                frame:ClearAllPoints()
                frame:SetPoint(_G["FirstHitSettings"].uiPos[1], UIParent, _G["FirstHitSettings"].uiPos[2], _G["FirstHitSettings"].uiPos[3], _G["FirstHitSettings"].uiPos[4])
            end
            if _G["FirstHitSettings"].uiWidth then
                frame:SetSize(_G["FirstHitSettings"].uiWidth, _G["FirstHitSettings"].uiHeight)
            end
        end
        UIFrameFadeIn(frame, 0.2, 0, 1)
        UpdateUI()
    end
end

-- ================= MINIMAP BUTTON =================
local minimapBtn = CreateFrame("Button", "FirstHitMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameLevel(8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local btnIcon = minimapBtn:CreateTexture(nil, "BACKGROUND")
-- NOTA: WoW 3.3.5a NO soporta PNG. Debe ser convertido a TGA o BLP.
btnIcon:SetTexture("Interface\\AddOns\\firsthit\\firsthit.tga") 
btnIcon:SetSize(20, 20)
btnIcon:SetPoint("CENTER", 0, 0)

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", 0, 0)

minimapBtn:SetScript("OnClick", function()
    addonTable.ToggleUI()
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("FirstHit", 0, 1, 1)
    GameTooltip:AddLine("Click para abrir el historial", 1, 1, 1)
    GameTooltip:AddLine("Arrastra para mover el botón", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Arrastrar el botón
minimapBtn:SetMovable(true)
minimapBtn:RegisterForDrag("LeftButton")

local function MoveMinimapButton()
    local angle = (_G["FirstHitSettings"] and _G["FirstHitSettings"].minimapPos) or 45
    minimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(math.rad(angle))), (80 * math.sin(math.rad(angle))) - 52)
end

minimapBtn:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local scale = Minimap:GetEffectiveScale()
        
        local xdir = (xpos / scale) - xmin - 70
        local ydir = (ypos / scale) - ymin - 70
        local angle = math.deg(math.atan2(ydir, xdir))
        
        if not _G["FirstHitSettings"] then _G["FirstHitSettings"] = {} end
        _G["FirstHitSettings"].minimapPos = angle
        MoveMinimapButton()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
end)

addonTable.UpdateMinimapPosition = MoveMinimapButton
