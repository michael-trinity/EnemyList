--- Optional: replace the stock nameplate for listed hostiles with the same row UI as the enemy list.
--- Hides Blizzard/Plater |UnitFrame|/|unitFrame| and draws the list row. Follows the same idea as
--- |Plater.OnRetailNamePlateShow| + a |SetAlpha| hook (see Plater.lua): the default frame is re-shown
--- on refresh, so we must re-apply and hook — not only the first time.

local _, EnemyList = ...

local frame = CreateFrame("Frame")
local lastFull = 0
local FULL_INTERVAL = 0.08
--- Extra pulse when a mirror is visible so other addons/Blizzard cannot flash the stock plate between refreshes.
local pulseAcc = 0
--- Light bar hide + |SetAlpha| only; avoid recursive squash on this interval (it fights the client and blinks the whole plate).
local PULSE_INTERVAL = 0.06
--- Full subtree squash to catch |Texture| redraws, without the 10–30Hz hammer of the old pulse.
local squashAcc = 0
local SQUASH_MAINTAIN_INTERVAL = 0.18
--- The stock |UnitFrame| rect is often wider than the visible bar art (aura slots, etc.). Inset the
--- mirror on the right (and a touch on the left) so the black backing does not spill past the plate.
local MIRROR_INSET_LEFT = 2
--- Plater/Blizz |unitFrame| is wider than the art + threat border; pull in more on the right.
local MIRROR_INSET_RIGHT = 20
local MIRROR_INSET_TOP = 0
local MIRROR_INSET_BOTTOM = 0

local function getDb()
  return rawget(_G, "EnemyListDB")
end

local function optionOn()
  local db = getDb()
  return type(db) == "table" and db.nameplateListMirror
end

local function canUseNamePlates()
  return C_NamePlate and C_NamePlate.GetNamePlateForUnit
end

--- Blizzard default is |UnitFrame|; Plater uses |unitFrame| (lowercase). May both exist; both must be hidden.
local function getUnitFrameList(nameplate)
  if not nameplate then
    return {}
  end
  local out = nameplate._elMirrorUfList
  if not out then
    out = {}
    nameplate._elMirrorUfList = out
  end
  for i = #out, 1, -1 do
    out[i] = nil
  end
  local a, b = nameplate.UnitFrame, nameplate.unitFrame
  if a and type(a) == "table" then
    out[#out + 1] = a
  end
  if b and type(b) == "table" and b ~= a then
    out[#out + 1] = b
  end
  return out
end

--- Visual bars live on |unitFrame|/|unitFrame| (Plater) or |UnitFrame| — used only for **positioning**.
--- The mirror is parented to the |C_NamePlate| root (sibling of |unitFrame|) so it is not a child of the
--- alpha-0 |UnitFrame| and lines up with the threat border (threat is drawn on the nameplate root).
local function getMirrorLayoutAnchorUf(nameplate)
  if not nameplate or type(nameplate) ~= "table" then
    return nil
  end
  return nameplate.unitFrame or nameplate.UnitFrame or nameplate
end

local function mirrorIsShownOnPlate(np)
  return np
    and np.EnemyListNameplateMirror
    and np.EnemyListNameplateMirror.IsShown
    and np.EnemyListNameplateMirror:IsShown()
end

--- Blizzard/Plater redraw |Texture| layers on the health/cast path each update; hide the full subtree + regions.
--- Records every frame's pre-hide |IsShown|/alpha and every region's alpha into |nameplate._elSquashState|
--- so the restore path in |persistSuppressPlateUnitFrames(_, false)| can put the bars back. Without
--- this, mirrored plates that later went un-mirrored kept name+level visible but no health/cast bar.
--- |nameplate._elSquashState = { frames = { [frame] = { wasShown, alpha } }, regions = { [region] = { wasShown, alpha } } }|.
local function squashBarSubtreeForMirror(uf, nameplate)
  if not uf or type(uf) ~= "table" then
    return
  end
  nameplate = nameplate or uf._elMirrorNameplate
  local state
  if type(nameplate) == "table" then
    if not nameplate._elSquashState then
      nameplate._elSquashState = { frames = {}, regions = {} }
    end
    state = nameplate._elSquashState
  end
  local function recordFrame(f)
    if not state or state.frames[f] ~= nil then return end
    local wasShown, alpha = true, 1
    pcall(function() if f.IsShown then wasShown = f:IsShown() and true or false end end)
    pcall(function() if f.GetAlpha then alpha = f:GetAlpha() or 1 end end)
    state.frames[f] = { wasShown = wasShown, alpha = alpha }
  end
  local function recordRegion(reg)
    if not state or state.regions[reg] ~= nil then return end
    local wasShown, alpha = true, 1
    pcall(function() if reg.IsShown then wasShown = reg:IsShown() and true or false end end)
    pcall(function() if reg.GetAlpha then alpha = reg:GetAlpha() or 1 end end)
    state.regions[reg] = { wasShown = wasShown, alpha = alpha }
  end
  local function visitFrame(f, depth)
    if not f or type(f) ~= "table" or (depth and depth > 4) then
      return
    end
    if f.IsForbidden and f:IsForbidden() then
      return
    end
    recordFrame(f)
    pcall(function()
      if f.SetIgnoreParentAlpha then
        f:SetIgnoreParentAlpha(false)
      end
    end)
    pcall(f.Hide, f)
    pcall(f.SetAlpha, f, 0)
    pcall(function()
      if f.GetRegions then
        local nr = select("#", f:GetRegions())
        for ri = 1, nr do
          local reg = select(ri, f:GetRegions())
          if reg then
            recordRegion(reg)
            if reg.SetAlpha then
              pcall(reg.SetAlpha, reg, 0)
            end
            if reg.Hide then
              pcall(reg.Hide, reg)
            end
          end
        end
      end
    end)
    local n = 0
    pcall(function()
      n = f.GetNumChildren and f:GetNumChildren() or 0
    end)
    for i = 1, math.min(n, 20) do
      local ch = select(i, f.GetChildren and f:GetChildren() or nil)
      visitFrame(ch, (depth or 0) + 1)
    end
  end
  local roots = {
    uf.healthBar,
    uf.castBar,
    uf.ClassPowerBar,
    uf.powerBar,
    uf.CastBar,
    uf.secondaryPowerBar,
    uf.HealthBarsContainer,
  }
  for i = 1, #roots do
    if roots[i] and type(roots[i]) == "table" then
      visitFrame(roots[i], 0)
    end
  end
  pcall(function()
    local hbc = uf.HealthBarsContainer
    if hbc and hbc.healthBar and type(hbc.healthBar) == "table" then
      visitFrame(hbc.healthBar, 0)
    end
  end)
end

--- Drive common Blizzard/Plater pieces to 0: parent can be 0 but children may use |SetIgnoreParentAlpha(true)|.
--- |nameplate| is the |C_NamePlate| root; used to store sub-frame visibility for restore.
--- |includeSquash|: pass |false| on the high-frequency pulse so we do not re-walk the bar subtree every tick (causes full-plate blink).
local function applyDefaultPlateVisualHideToUf(uf, nameplate, includeSquash)
  if not uf or type(uf) ~= "table" then
    return
  end
  nameplate = nameplate or uf._elMirrorNameplate
  pcall(function()
    if uf.SetIgnoreParentAlpha then
      uf:SetIgnoreParentAlpha(false)
    end
  end)
  pcall(function()
    if uf.SetAlpha then
      uf:SetAlpha(0)
    end
  end)
  pcall(function()
    if uf.EnableMouse then
      uf:EnableMouse(false)
    end
  end)
  local byName = {
    "healthBar",
    "castBar",
    "powerBar",
    "name",
    "Name",
    "buffFrame",
    "BuffFrame",
    "BuffFrame2",
  }
  --- Record each child's pre-hide alpha so the restore path can put it back. Without this, hiding
  --- |uf.name| stuck the FontString at alpha 0 — meaning the name never reappeared once the mirror
  --- was hidden (e.g. for an enemy that isn't in the list yet, pre-combat). The user only saw the
  --- level text on the stock plate until the addon discovered the enemy and restored the mirror.
  if type(nameplate) == "table" then
    if not nameplate._elChildPrevAlpha then nameplate._elChildPrevAlpha = {} end
    local store = nameplate._elChildPrevAlpha
    for i = 1, #byName do
      local c = uf[byName[i]]
      if c and c.GetAlpha and store[c] == nil then
        pcall(function() store[c] = c:GetAlpha() or 1 end)
      end
    end
  end
  for i = 1, #byName do
    local c = uf[byName[i]]
    if c and c.SetAlpha then
      pcall(function()
        if c.SetIgnoreParentAlpha then
          c:SetIgnoreParentAlpha(false)
        end
        c:SetAlpha(0)
      end)
    end
  end
  pcall(function()
    local c = uf.HealthBarsContainer
    if c and c.SetAlpha then
      if c.SetIgnoreParentAlpha then
        c:SetIgnoreParentAlpha(false)
      end
      c:SetAlpha(0)
    end
  end)
  pcall(function()
    local c = uf.HealthBarsContainer
    c = c and c.healthBar
    if c and c.SetAlpha then
      if c.SetIgnoreParentAlpha then
        c:SetIgnoreParentAlpha(false)
      end
      c:SetAlpha(0)
    end
  end)
  --- Hiding bar frames (not just alpha) stops |Raid| fill textures from ghosting. Restore in |persist| off.
  if type(nameplate) == "table" then
    local function partHide(fb)
      if not fb or type(fb) ~= "table" or not fb.Hide then
        return
      end
      if not nameplate._elPartShown then
        nameplate._elPartShown = {}
      end
      if nameplate._elPartShown[fb] == nil and fb.IsShown then
        pcall(function()
          nameplate._elPartShown[fb] = fb:IsShown() and true or false
        end)
      end
      pcall(fb.Hide, fb)
      pcall(fb.SetAlpha, fb, 0)
    end
    for _, n in pairs({
      "healthBar",
      "castBar",
      "ClassPowerBar",
      "powerBar",
      "CastBar",
    }) do
      partHide(uf[n])
    end
    partHide(uf.HealthBarsContainer)
    pcall(function()
      local hbc = uf.HealthBarsContainer
      partHide(hbc and hbc.healthBar)
    end)
  end
  if includeSquash ~= false then
    squashBarSubtreeForMirror(uf, nameplate)
  end
end

--- Instants and short cast flashes re-|Show| the stock health/cast bars; keep them hidden like Plater
--- re-entry on |Show| for the |UnitFrame|.
local function ensureSubBarMirrorHooks(bar, np)
  if not bar or type(bar) ~= "table" or bar._elMirrorSubBarHooks then
    return
  end
  bar._elMirrorSubBarHooks = true
  bar._elMirrorNameplate = np
  hooksecurefunc(bar, "Show", function(self)
    if not optionOn() then
      return
    end
    local p = self._elMirrorNameplate
    if not p or not mirrorIsShownOnPlate(p) then
      return
    end
    pcall(self.Hide, self)
    pcall(self.SetAlpha, self, 0)
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if not optionOn() or not self or self.IsForbidden and self:IsForbidden() then
          return
        end
        local p2 = self._elMirrorNameplate
        if p2 and mirrorIsShownOnPlate(p2) then
          pcall(self.Hide, self)
          pcall(self.SetAlpha, self, 0)
          for _, uff in ipairs(getUnitFrameList(p2) or {}) do
            pcall(squashBarSubtreeForMirror, uff, p2)
          end
        end
      end)
    end
  end)
  local lock = false
  hooksecurefunc(bar, "SetAlpha", function(self, a)
    if lock or not optionOn() or not self or self.IsForbidden and self:IsForbidden() then
      return
    end
    local p = self._elMirrorNameplate
    if not p or not mirrorIsShownOnPlate(p) then
      return
    end
    if type(a) == "number" and a > 0.01 then
      lock = true
      pcall(self.Hide, self)
      pcall(self.SetAlpha, self, 0)
      lock = false
    end
  end)
  pcall(function()
    if not bar.SetShown then
      return
    end
    local lockS = false
    hooksecurefunc(bar, "SetShown", function(self, on)
      if lockS or not on then
        return
      end
      if not optionOn() or not self or self.IsForbidden and self:IsForbidden() then
        return
      end
      local p = self._elMirrorNameplate
      if not p or not mirrorIsShownOnPlate(p) then
        return
      end
      lockS = true
      pcall(self.Hide, self)
      pcall(self.SetAlpha, self, 0)
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          if not p or not mirrorIsShownOnPlate(p) or not optionOn() or not self or (self.IsForbidden and self:IsForbidden()) then
            return
          end
          pcall(self.Hide, self)
          pcall(self.SetAlpha, self, 0)
          for _, uff in ipairs(getUnitFrameList(p) or {}) do
            pcall(squashBarSubtreeForMirror, uff, p)
          end
        end)
      end
      lockS = false
    end)
  end)
end

local function registerAllSubbarHooksForUf(uf, np)
  if not uf or not np or type(uf) ~= "table" then
    return
  end
  for _, key in pairs({
    "healthBar",
    "castBar",
    "powerBar",
    "ClassPowerBar",
    "CastBar",
    "secondaryPowerBar",
    "PlaterBuffFrame",
    "PlaterDebuffFrame",
  }) do
    local b = uf[key]
    if b and type(b) == "table" then
      b._elMirrorNameplate = np
      ensureSubBarMirrorHooks(b, np)
    end
  end
  pcall(function()
    local c = uf.HealthBarsContainer
    if c and type(c) == "table" then
      c._elMirrorNameplate = np
      ensureSubBarMirrorHooks(c, np)
      local hb = c.healthBar
      if hb and type(hb) == "table" then
        hb._elMirrorNameplate = np
        ensureSubBarMirrorHooks(hb, np)
      end
    end
  end)
end

--- |hooksecurefunc| once per frame: Plater-style lock so |SetAlpha| from Blizzard/Plater cannot flash the plate.
--- Hooks read |self._elMirrorNameplate| (updated every refresh) so the closure never holds a stale plate.

local function ensureUfSuppressionHooks(uf, np)
  if not uf or not np or type(uf) ~= "table" or uf._elMirrorListHooks then
    return
  end
  uf._elMirrorListHooks = true
  uf._elMirrorNameplate = np
  local lockA = false
  hooksecurefunc(uf, "SetAlpha", function(self, a)
    if lockA or self == nil or self.IsForbidden and self:IsForbidden() then
      return
    end
    if not optionOn() then
      return
    end
    local p = self._elMirrorNameplate
    if not p or not mirrorIsShownOnPlate(p) then
      return
    end
    if type(a) == "number" and a > 0.01 then
      lockA = true
      applyDefaultPlateVisualHideToUf(self)
      pcall(self.SetAlpha, self, 0)
      lockA = false
    end
  end)
  hooksecurefunc(uf, "Show", function(self)
    if not optionOn() then
      return
    end
    local p = self._elMirrorNameplate
    if not p or not mirrorIsShownOnPlate(p) then
      return
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if not optionOn() or not self or self.IsForbidden and self:IsForbidden() then
          return
        end
        local plate = self._elMirrorNameplate
        if plate and mirrorIsShownOnPlate(plate) then
          applyDefaultPlateVisualHideToUf(self)
        end
      end)
    else
      applyDefaultPlateVisualHideToUf(self)
    end
  end)
end

--- Capture original alpha only once per frame per plate, restore when mirror hides.
local function persistSuppressPlateUnitFrames(nameplate, hide)
  if not nameplate then
    return
  end
  local ufs = getUnitFrameList(nameplate)
  if hide then
    if not nameplate._elMirrorPrevAlpha then
      nameplate._elMirrorPrevAlpha = {}
    end
    for i = 1, #ufs do
      local uf = ufs[i]
      if uf and type(uf) == "table" then
        uf._elMirrorNameplate = nameplate
      end
      if not nameplate._elMirrorPrevAlpha[uf] then
        pcall(function()
          if uf and uf.GetAlpha then
            nameplate._elMirrorPrevAlpha[uf] = uf:GetAlpha() or 1
          else
            nameplate._elMirrorPrevAlpha[uf] = 1
          end
        end)
        if not nameplate._elMirrorPrevAlpha[uf] then
          nameplate._elMirrorPrevAlpha[uf] = 1
        end
      end
      applyDefaultPlateVisualHideToUf(uf, nameplate)
      ensureUfSuppressionHooks(uf, nameplate)
      registerAllSubbarHooksForUf(uf, nameplate)
    end
    nameplate._elMirrorUfSuppress = #ufs > 0
  else
    if nameplate._elPartShown then
      for fb, was in pairs(nameplate._elPartShown) do
        pcall(function()
          if type(fb) == "table" and fb.SetAlpha and not (fb.IsForbidden and fb:IsForbidden()) then
            fb:SetAlpha(1)
            if was and fb.Show then
              fb:Show()
            end
          end
        end)
      end
      nameplate._elPartShown = nil
    end
    local t = nameplate._elMirrorPrevAlpha
    if t then
      for uf, a in pairs(t) do
        pcall(function()
          if type(uf) == "table" and uf.GetAlpha and uf.SetAlpha and not (uf.IsForbidden and uf:IsForbidden()) then
            uf:SetAlpha(type(a) == "number" and a or 1)
            if uf.EnableMouse then
              uf:EnableMouse(true)
            end
          end
        end)
      end
    end
    --- Restore the per-child alphas captured by |applyDefaultPlateVisualHideToUf|. Without this,
    --- |uf.name| / |uf.Name| / etc. stayed at alpha 0 — the user saw only the level on stock plates
    --- for any enemy not currently mirrored.
    local ct = nameplate._elChildPrevAlpha
    if ct then
      for c, a in pairs(ct) do
        pcall(function()
          if type(c) == "table" and c.SetAlpha and not (c.IsForbidden and c:IsForbidden()) then
            c:SetAlpha(type(a) == "number" and a or 1)
          end
        end)
      end
    end
    --- Restore everything |squashBarSubtreeForMirror| hid: every frame in the bar subtrees and
    --- every region (texture / fontstring) inside them. Without this the stock plate's health bar,
    --- cast bar, and class power bar stayed hidden indefinitely after the mirror went away — name
    --- + level were the only things still visible.
    local sq = nameplate._elSquashState
    if sq then
      if sq.regions then
        for reg, snap in pairs(sq.regions) do
          pcall(function()
            if type(reg) == "table" and not (reg.IsForbidden and reg:IsForbidden()) then
              if reg.SetAlpha then reg:SetAlpha(snap and snap.alpha or 1) end
              if snap and snap.wasShown and reg.Show then reg:Show() end
            end
          end)
        end
      end
      if sq.frames then
        for f, snap in pairs(sq.frames) do
          pcall(function()
            if type(f) == "table" and not (f.IsForbidden and f:IsForbidden()) then
              if f.SetAlpha then f:SetAlpha(snap and snap.alpha or 1) end
              if snap and snap.wasShown and f.Show then f:Show() end
            end
          end)
        end
      end
    end
    nameplate._elMirrorPrevAlpha = nil
    nameplate._elChildPrevAlpha = nil
    nameplate._elSquashState = nil
    nameplate._elMirrorUfSuppress = nil
  end
end

--- |noSquash|: when true, only hide bars/alpha (pulse path). Full |squashBarSubtreeForMirror| is expensive and on a fast timer it blinks the nameplate.
local function reapplyUfVisualHideForPlate(np, noSquash)
  if not np then
    return
  end
  local includeSquash = not noSquash
  local ufs = getUnitFrameList(np)
  for i = 1, #ufs do
    local uf = ufs[i]
    applyDefaultPlateVisualHideToUf(uf, np, includeSquash)
    registerAllSubbarHooksForUf(uf, np)
  end
end

local function findEntryForUnit(unit, data)
  if not data or not unit or not UnitExists(unit) then
    return nil
  end
  local g = UnitGUID(unit)
  local function scan(t)
    for _, row in ipairs(t or {}) do
      if row and row.unit == unit then
        return row
      end
    end
    for _, row in ipairs(t or {}) do
      if row and g and row.guid and row.guid == g then
        return row
      end
    end
  end
  local a = scan(data.aggro)
  if a then
    return a
  end
  return scan(data.other)
end

local function hideMirror(np)
  if not np then
    return
  end
  if np.EnemyListNameplateMirror then
    np.EnemyListNameplateMirror:Hide()
  end
  persistSuppressPlateUnitFrames(np, false)
end

--- |FrameLevel| when the mirror is a **sibling** of the stock bars is relative to the same parent.
local function positionMirrorZOrder(f, np)
  if not f or not np then
    return
  end
  f:SetFrameStrata("MEDIUM")
  local p = f.GetParent and f:GetParent()
  if p and p == np then
    local base = 5
    if type(EnemyList.GetNameplateStackBase) == "function" then
      pcall(function()
        base = EnemyList.GetNameplateStackBase(np) or base
      end)
    end
    --- Above the stock |UnitFrame|/Plater drawing (sibling under |np|).
    f:SetFrameLevel(base + 45)
  else
    f:SetFrameLevel(80)
  end
end

--- Anchored to the same rect as the stock bars (|unitFrame|) but **parented** to |C_NamePlate| so nothing is clipped
--- under an alpha-0 |UnitFrame| and the threat border (on the nameplate) aligns.
local function ensureMirrorContainer(np)
  local f = np.EnemyListNameplateMirror
  local layoutUf = getMirrorLayoutAnchorUf(np)
  if not layoutUf then
    return nil
  end
  if not f then
    f = CreateFrame("Frame", nil, np)
    f._elNameplateMirrorHost = true
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    --- Solid black filled the area below a scaled row and read as a "spell" sliver; use a light dim only.
    bg:SetColorTexture(0, 0, 0, 0.2)
    f._elOpaqueBg = bg
    f:EnableMouse(false)
    if f.SetMouseClickEnabled then
      f:SetMouseClickEnabled(false)
    end
    if f.SetMouseMotionEnabled then
      f:SetMouseMotionEnabled(false)
    end
    np.EnemyListNameplateMirror = f
  end
  pcall(function()
    f:SetParent(np)
  end)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", layoutUf, "TOPLEFT", MIRROR_INSET_LEFT, -MIRROR_INSET_TOP)
  f:SetPoint("BOTTOMRIGHT", layoutUf, "BOTTOMRIGHT", -MIRROR_INSET_RIGHT, MIRROR_INSET_BOTTOM)
  f._elNameplateMirrorHost = true
  pcall(function()
    if f.SetClipsChildren then
      f:SetClipsChildren(true)
    end
  end)
  --- Sibling of |UnitFrame| under the nameplate root: no inherited alpha; ignore line kept for safety.
  pcall(function()
    if f.SetIgnoreParentAlpha then
      f:SetIgnoreParentAlpha(true)
    end
  end)
  pcall(f.SetAlpha, f, 1)
  f:Show()
  if f._elOpaqueBg then
    f._elOpaqueBg:Show()
  end
  return f
end

local function updateNameplateMirror(unit, data)
  if not canUseNamePlates() or not unit or not UnitExists(unit) then
    return
  end
  if not UnitCanAttack("player", unit) then
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    hideMirror(np)
    return
  end
  if not optionOn() then
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    hideMirror(np)
    return
  end
  if type(EnemyList.ApplyNameplateMirrorBarRow) ~= "function" then
    return
  end
  local np = C_NamePlate.GetNamePlateForUnit(unit)
  if not np then
    return
  end
  if not data then
    if not EnemyList.GetEnemyRows then
      return
    end
    local ok, d = pcall(EnemyList.GetEnemyRows)
    if not ok or type(d) ~= "table" then
      hideMirror(np)
      return
    end
    data = d
  end
  local entry = findEntryForUnit(unit, data)
  if not entry then
    hideMirror(np)
    return
  end
  local npW = np.GetWidth and np:GetWidth() or 0
  local npH = np.GetHeight and np:GetHeight() or 0
  if npW < 16 then
    npW = 180
  end
  if npH < 8 then
    npH = 40
  end
  local container = ensureMirrorContainer(np)
  if not container then
    return
  end
  do
    if container and container.GetWidth and container.GetHeight then
      local w2 = container:GetWidth() or 0
      local h2 = container:GetHeight() or 0
      if w2 > 12 then
        npW = w2
      end
      if h2 > 4 then
        npH = h2
      end
    end
  end
  positionMirrorZOrder(container, np)
  --- Always re-apply: Blizzard/Plater can |Show|/|SetAlpha| the stock plate between our passes.
  persistSuppressPlateUnitFrames(np, true)
  local ok = pcall(EnemyList.ApplyNameplateMirrorBarRow, container, unit, entry, npW, npH)
  if not ok then
    persistSuppressPlateUnitFrames(np, false)
    hideMirror(np)
  else
    reapplyUfVisualHideForPlate(np)
  end
end

local function hideAllMirrors()
  if not canUseNamePlates() then
    return
  end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) then
      local np = C_NamePlate.GetNamePlateForUnit(u)
      hideMirror(np)
    end
  end
end

function EnemyList.RefreshNameplateListMirrors(force)
  if not canUseNamePlates() or not EnemyList.GetEnemyRows then
    return
  end
  if not optionOn() then
    hideAllMirrors()
    return
  end
  if type(EnemyList.ApplyNameplateMirrorBarRow) ~= "function" then
    return
  end
  local now = GetTime and GetTime() or 0
  if not force and (now - lastFull) < FULL_INTERVAL then
    return
  end
  lastFull = now
  local ok, data = pcall(EnemyList.GetEnemyRows)
  if not ok or type(data) ~= "table" then
    return
  end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and UnitCanAttack("player", u) then
      updateNameplateMirror(u, data)
    end
  end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
pcall(function()
  frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end)

frame:SetScript("OnEvent", function(_, event, arg1)
  if not canUseNamePlates() or not EnemyList.GetEnemyRows then
    return
  end
  if event == "PLAYER_LOGIN" then
    EnemyList.RefreshNameplateListMirrors(true)
    return
  end
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(arg1) == "string" and optionOn() then
      lastFull = 0
      updateNameplateMirror(arg1, nil)
    elseif not optionOn() and type(arg1) == "string" then
      pcall(function()
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
          hideMirror(C_NamePlate.GetNamePlateForUnit(arg1))
        end
      end)
    end
    return
  end
  if event == "NAME_PLATE_UNIT_REMOVED" then
    EnemyList.RefreshNameplateListMirrors(true)
  end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
  if not optionOn() or not canUseNamePlates() then
    return
  end
  local e = elapsed or 0
  pulseAcc = pulseAcc + e
  squashAcc = squashAcc + e
  local doLight = pulseAcc >= PULSE_INTERVAL
  local doSquash = squashAcc >= SQUASH_MAINTAIN_INTERVAL
  if not doLight and not doSquash then
    return
  end
  if doLight then
    pulseAcc = 0
  end
  if doSquash then
    squashAcc = 0
  end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) then
      local np = C_NamePlate.GetNamePlateForUnit(u)
      if np and mirrorIsShownOnPlate(np) then
        if doLight then
          reapplyUfVisualHideForPlate(np, true)
        end
        if doSquash then
          for _, uff in ipairs(getUnitFrameList(np) or {}) do
            pcall(squashBarSubtreeForMirror, uff, np)
          end
        end
      end
    end
  end
end)
