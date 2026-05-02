local _, EnemyList = ...

--- Colored border on hostile nameplates from your threat (optional). Tanks: pulsing warn when |rawThreatPct| drops
--- below ~100% of the pull holder (API-dependent). DPS: warm colors as you approach pull threat.

local frame = CreateFrame("Frame")
local pulseAcc = 0
local BORDER_THICK = 4
local lastFullRefresh = 0
local FULL_REFRESH_INTERVAL = 0.06

local function getDb()
  return rawget(_G, "EnemyListDB")
end

local function optionOn()
  local db = getDb()
  return type(db) == "table" and db.nameplateThreatOverlay
end

local function canUseNamePlates()
  return C_NamePlate and C_NamePlate.GetNamePlateForUnit
end

local function hidePlateOverlay(np)
  if np and np.EnemyListThreatOverlay then
    np.EnemyListThreatOverlay:Hide()
  end
end

local function ensureOverlay(np)
  local f = np.EnemyListThreatOverlay
  if f then
    return f
  end
  f = CreateFrame("Frame", nil, np)
  f:SetFrameStrata("MEDIUM")
  local base = 5
  if type(EnemyList.GetNameplateStackBase) == "function" then
    pcall(function()
      base = EnemyList.GetNameplateStackBase(np) or base
    end)
  end
  --- Above |EnemyListNameplateMirror| (|base+40|) and the stock plate.
  f:SetFrameLevel(base + 70)
  f:SetAllPoints()
  f:EnableMouse(false)
  local edges = {}
  for i = 1, 4 do
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    edges[i] = t
  end
  edges[1]:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
  edges[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  edges[1]:SetHeight(BORDER_THICK)
  edges[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -2, -2)
  edges[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
  edges[2]:SetHeight(BORDER_THICK)
  edges[3]:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 0)
  edges[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -2, 0)
  edges[3]:SetWidth(BORDER_THICK)
  edges[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 0)
  edges[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, 0)
  edges[4]:SetWidth(BORDER_THICK)
  f._edges = edges
  f._pulse = false
  f:Hide()
  np.EnemyListThreatOverlay = f
  return f
end

local function setEdgeVisual(ov, r, g, b, a, pulse)
  if not ov or not ov._edges then
    return
  end
  a = a or 0.92
  ov._pulse = pulse and true or false
  ov._pr, ov._pg, ov._pb = r, g, b
  for i = 1, 4 do
    ov._edges[i]:SetVertexColor(r, g, b)
    ov._edges[i]:SetAlpha(a)
  end
end

--- Returns r,g,b, alpha, pulse
local function colorForThreat(ti)
  if not ti or not ti.hasAPI then
    return 0.42, 0.44, 0.48, 0.55, false
  end
  do
    local db = getDb()
    if type(db) == "table" and db.nameplateThreatSecondStyle and ti.isSecondOnThreat and not ti.isTanking then
      return 0.12, 0.85, 0.95, 0.9, false
    end
  end
  if ti.isTanking then
    local raw = ti.rawThreatPct
    if type(raw) == "number" and raw < 99.75 then
      return 1, 0.28, 0.08, 0.95, true
    end
    return 0.12, 0.88, 0.22, 0.92, false
  end
  local pct = ti.threatPct
  if type(pct) == "number" then
    if pct >= 98 then
      return 0.95, 0.15, 0.12, 0.95, true
    end
    if pct >= 90 then
      return 1, 0.35, 0.12, 0.92, true
    end
    if pct >= 75 then
      return 1, 0.55, 0.12, 0.88, false
    end
    if pct >= 50 then
      return 0.95, 0.75, 0.15, 0.85, false
    end
  end
  if ti.status == 2 then
    return 0.95, 0.55, 0.12, 0.88, false
  end
  if ti.status == 1 then
    return 0.9, 0.82, 0.2, 0.82, false
  end
  return 0.45, 0.52, 0.62, 0.72, false
end

local function updateOne(unit)
  if not canUseNamePlates() then
    return
  end
  if not unit or not UnitExists(unit) then
    return
  end
  if not UnitCanAttack("player", unit) then
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    hidePlateOverlay(np)
    return
  end
  if not optionOn() then
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    hidePlateOverlay(np)
    return
  end
  local np = C_NamePlate.GetNamePlateForUnit(unit)
  if not np then
    return
  end
  local ti = EnemyList.GetThreatAnalysis and EnemyList.GetThreatAnalysis(unit)
  if not ti then
    hidePlateOverlay(np)
    return
  end
  local ov = ensureOverlay(np)
  if type(EnemyList.GetNameplateStackBase) == "function" then
    pcall(function()
      ov:SetFrameLevel(EnemyList.GetNameplateStackBase(np) + 70)
    end)
  end
  local r, g, b, a, pulse = colorForThreat(ti)
  ov:Show()
  setEdgeVisual(ov, r, g, b, a, pulse)
end

local function hideAllOverlays()
  if not canUseNamePlates() then
    return
  end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) then
      local np = C_NamePlate.GetNamePlateForUnit(u)
      hidePlateOverlay(np)
    end
  end
end

function EnemyList.RefreshNameplateThreatOverlays(force)
  if not canUseNamePlates() or not EnemyList.GetThreatAnalysis then
    return
  end
  if not optionOn() then
    hideAllOverlays()
    return
  end
  local now = GetTime and GetTime() or 0
  if not force and now - lastFullRefresh < FULL_REFRESH_INTERVAL then
    return
  end
  lastFullRefresh = now
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and UnitCanAttack("player", u) then
      updateOne(u)
    end
  end
end

frame:SetScript("OnUpdate", function(_, elapsed)
  if not optionOn() or not canUseNamePlates() then
    return
  end
  pulseAcc = pulseAcc + elapsed
  if pulseAcc < 0.04 then
    return
  end
  pulseAcc = 0
  local t = GetTime and GetTime() or 0
  local alpha = 0.5 + 0.45 * (0.5 + 0.5 * math.sin(t * 7.5))
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) then
      local np = C_NamePlate.GetNamePlateForUnit(u)
      local ov = np and np.EnemyListThreatOverlay
      if ov and ov:IsShown() and ov._pulse and ov._edges then
        for j = 1, 4 do
          ov._edges[j]:SetVertexColor(ov._pr or 1, ov._pg or 0.2, ov._pb or 0.1)
          ov._edges[j]:SetAlpha(alpha)
        end
      end
    end
  end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
pcall(function()
  frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end)
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
pcall(function()
  frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
end)

frame:SetScript("OnEvent", function(_, event, arg1)
  if not canUseNamePlates() or not EnemyList.GetThreatAnalysis then
    return
  end
  if event == "PLAYER_LOGIN" then
    EnemyList.RefreshNameplateThreatOverlays(true)
    return
  end
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(arg1) == "string" and optionOn() then
      lastFullRefresh = 0
      updateOne(arg1)
    elseif not optionOn() then
      hideAllOverlays()
    end
    return
  end
  if event == "NAME_PLATE_UNIT_REMOVED" then
    EnemyList.RefreshNameplateThreatOverlays(true)
    return
  end
  if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
    EnemyList.RefreshNameplateThreatOverlays(true)
  end
end)
