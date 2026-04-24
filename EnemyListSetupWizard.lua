--- First-run setup wizard. Extracted from EnemyListUI.lua to keep the main UI chunk under Lua 5.1's
--- 200-local-variable limit. Depends on EnemyList._api (populated by EnemyListUI.lua).
--- Load order: must come after EnemyListUI.lua in the .toc.

local _, EnemyList = ...
local L = EnemyList.L

--- All functions in this file resolve |EnemyList._api| at call time, so they tolerate the UI file
--- not being fully initialised yet at chunk-eval (the wizard only opens at PLAYER_LOGIN or later).
local function api() return EnemyList._api end

local setupWizardFrame

local function setupWizardStyleToggleButton(btn, on)
  if not btn or not btn.SetBackdropBorderColor then
    return
  end
  if on then
    btn:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    if btn.GetFontString then
      local fs = btn:GetFontString()
      if fs and fs.SetTextColor then
        fs:SetTextColor(1, 0.82, 0)
      end
    end
  else
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    if btn.GetFontString then
      local fs = btn:GetFontString()
      if fs and fs.SetTextColor then
        fs:SetTextColor(0.7, 0.72, 0.75)
      end
    end
  end
end

local function setupWizardRefreshSelections(f)
  if not f or not f._layoutBtns then
    return
  end
  local g = EnemyListDB.gridMode and true or false
  local s = EnemyListDB.singleColumn and true or false
  setupWizardStyleToggleButton(f._layoutBtns[1], not g and not s)
  setupWizardStyleToggleButton(f._layoutBtns[2], not g and s)
  setupWizardStyleToggleButton(f._layoutBtns[3], g)
  local sm = tonumber(EnemyListDB.sortMode) or 1
  for i, b in ipairs(f._sortBtns or {}) do
    setupWizardStyleToggleButton(b, i == sm)
  end
end

local function setupWizardRebuildCopyList(f)
  local parent = f._copyList
  if not parent then
    return
  end
  for _, b in ipairs(parent._btns or {}) do
    b:Hide()
  end
  parent._btns = parent._btns or {}
  local y = 0
  local A = api()
  local cur = A.elPlayerProfileKey()
  local others = {}
  A.initAccountDB()
  for pk, ent in pairs(EnemyListAccountDB.profiles or {}) do
    if pk ~= cur and type(ent) == "table" and type(ent.data) == "table" then
      others[#others + 1] = pk
    end
  end
  table.sort(others)
  local totalOthers = #others
  local more = false
  if totalOthers > 6 then
    more = true
    while #others > 6 do
      table.remove(others)
    end
  end
  f._copyNoneFs:SetShown(totalOthers == 0)
  if f._copyMoreFs then
    f._copyMoreFs:SetShown(more)
  end
  parent:ClearAllPoints()
  if totalOthers == 0 then
    parent:SetPoint("TOPLEFT", f._copyNoneFs, "BOTTOMLEFT", 0, -4)
  elseif more then
    parent:SetPoint("TOPLEFT", f._copyMoreFs, "BOTTOMLEFT", 0, -4)
  else
    parent:SetPoint("TOPLEFT", f._copyHdr, "BOTTOMLEFT", 0, -4)
  end
  parent:SetShown(totalOthers > 0)
  local rowH = 24
  parent:SetHeight(math.max(28, #others * rowH + 4))
  for i, pk in ipairs(others) do
    local b = parent._btns[i]
    if not b then
      local bdMixin = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
      b = CreateFrame("Button", nil, parent, bdMixin)
      b:SetSize(420, 22)
      if b.SetBackdrop then
        b:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          edgeSize = 1,
          insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        b:SetBackdropColor(0.12, 0.12, 0.14, 0.85)
      end
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetPoint("LEFT", 6, 0)
      fs:SetJustifyH("LEFT")
      b:SetFontString(fs)
      parent._btns[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    y = y - rowH
    b:Show()
    b:GetFontString():SetText(string.format(L.SETUP_COPY_APPLY, pk))
    b._elProfileKey = pk
    b:SetScript("OnClick", function(self)
      local ent = EnemyListAccountDB.profiles[self._elProfileKey]
      if ent and type(ent.data) == "table" then
        local AA = api()
        AA.enemyListApplyProfileData(ent.data)
        AA.initDB()
        setupWizardRefreshSelections(f)
        if f._partyCheck then
          f._partyCheck:SetChecked(EnemyListDB.showPartyFrames and true or false)
        end
        if f._cliqueFs then
          f._cliqueFs:SetShown(EnemyListDB.showPartyFrames and true or false)
        end
        AA.layoutRows()
        AA.applyUiScale()
      end
    end)
  end
end

local function setupWizardComplete(f, done)
  local A = api()
  if done then
    EnemyListDB.setupWizardCompleted = true
    if EnemyList.SaveAccountProfileSnapshot then EnemyList.SaveAccountProfileSnapshot() end
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_SETUP_DONE)
  else
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_SETUP_LATER)
  end
  EnemyListDB.testMode = false
  if type(EnemyList.IsTestModeOn) == "function" then
    EnemyListDB.testMode = EnemyList.IsTestModeOn()
  end
  if f then
    f:Hide()
  end
  if A.main() then
    A.layoutRows()
    A.applyUiScale()
  end
  if EnemyListDB.showPartyFrames then
    A.elSafe("showPartyFrames", A.showPartyFrames)
  else
    A.hidePartyFrames()
  end
end

local function ensureSetupWizardFrame()
  if setupWizardFrame then
    return setupWizardFrame
  end
  local A = api()
  local bd = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  local f = CreateFrame("Frame", "EnemyListSetupWizard", UIParent, bd)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(250)
  f:SetSize(492, 560)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  A.applyMaterialSurface(f)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(L.SETUP_TITLE)

  local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  intro:SetWidth(460)
  intro:SetJustifyH("LEFT")
  intro:SetText(L.SETUP_INTRO)

  local curFs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  curFs:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
  curFs:SetWidth(460)
  curFs:SetJustifyH("LEFT")
  f._curFs = curFs

  local copyHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  copyHdr:SetPoint("TOPLEFT", curFs, "BOTTOMLEFT", 0, -10)
  copyHdr:SetText(L.SETUP_COPY_HEADER)
  f._copyHdr = copyHdr

  local copyNone = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  copyNone:SetPoint("TOPLEFT", copyHdr, "BOTTOMLEFT", 0, -4)
  copyNone:SetWidth(440)
  copyNone:SetJustifyH("LEFT")
  copyNone:SetText(L.SETUP_COPY_NONE)
  f._copyNoneFs = copyNone

  local copyMore = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  copyMore:SetPoint("TOPLEFT", copyHdr, "BOTTOMLEFT", 0, -4)
  copyMore:SetWidth(440)
  copyMore:SetJustifyH("LEFT")
  copyMore:SetText(L.SETUP_COPY_MORE)
  copyMore:Hide()
  f._copyMoreFs = copyMore

  local copyList = CreateFrame("Frame", nil, f)
  copyList:SetPoint("TOPLEFT", copyHdr, "BOTTOMLEFT", 0, -4)
  copyList:SetSize(420, 28)
  f._copyList = copyList

  local layHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  layHdr:SetPoint("TOPLEFT", copyList, "BOTTOMLEFT", 0, -12)
  layHdr:SetText(L.SETUP_LAYOUT_HEADER)

  local layoutRow = CreateFrame("Frame", nil, f)
  layoutRow:SetSize(440, 52)
  layoutRow:SetPoint("TOPLEFT", layHdr, "BOTTOMLEFT", 0, -4)
  f._layoutBtns = {}
  local bdMixin = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  local function mkLayBtn(x, label, desc, onClick)
    local b = CreateFrame("Button", nil, layoutRow, bdMixin)
    b:SetSize(140, 48)
    b:SetPoint("TOPLEFT", layoutRow, "TOPLEFT", x, 0)
    if b.SetBackdrop then
      b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      b:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOP", 0, -4)
    fs:SetText(label)
    local d = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d:SetPoint("TOP", fs, "BOTTOM", 0, -2)
    d:SetWidth(132)
    d:SetJustifyH("CENTER")
    d:SetText(desc)
    b:SetScript("OnClick", function()
      onClick()
      setupWizardRefreshSelections(f)
      local AA = api()
      AA.layoutRows()
      AA.applyUiScale()
    end)
    return b
  end
  f._layoutBtns[1] = mkLayBtn(0, L.SETUP_LAYOUT_DOUBLE, L.SETUP_LAYOUT_DOUBLE_DESC, function()
    EnemyListDB.gridMode = false
    EnemyListDB.singleColumn = false
  end)
  f._layoutBtns[2] = mkLayBtn(148, L.SETUP_LAYOUT_SINGLE, L.SETUP_LAYOUT_SINGLE_DESC, function()
    EnemyListDB.gridMode = false
    EnemyListDB.singleColumn = true
  end)
  f._layoutBtns[3] = mkLayBtn(296, L.SETUP_LAYOUT_GRID, L.SETUP_LAYOUT_GRID_DESC, function()
    EnemyListDB.gridMode = true
    EnemyListDB.singleColumn = false
  end)

  local sortHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sortHdr:SetPoint("TOPLEFT", layoutRow, "BOTTOMLEFT", 0, -10)
  sortHdr:SetText(L.SETUP_SORT_HEADER)
  local sortHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sortHint:SetPoint("TOPLEFT", sortHdr, "BOTTOMLEFT", 0, -2)
  sortHint:SetWidth(440)
  sortHint:SetJustifyH("LEFT")
  sortHint:SetText(L.SETUP_SORT_HINT)

  local sortRow = CreateFrame("Frame", nil, f)
  sortRow:SetSize(440, 26)
  sortRow:SetPoint("TOPLEFT", sortHint, "BOTTOMLEFT", 0, -6)
  f._sortBtns = {}
  local sortLabels = { L.SORT_AGGRO_HI, L.SORT_AGGRO_LO, L.SORT_HP_HI, L.SORT_HP_LO }
  local sw = math.floor(434 / 4)
  for j = 1, 4 do
    local b = CreateFrame("Button", nil, sortRow, bdMixin)
    b:SetSize(sw - 2, 22)
    b:SetPoint("TOPLEFT", sortRow, "TOPLEFT", (j - 1) * sw, 0)
    if b.SetBackdrop then
      b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      b:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(sortLabels[j])
    b:SetFontString(fs)
    local idx = j
    b:SetScript("OnClick", function()
      EnemyListDB.sortMode = idx
      setupWizardRefreshSelections(f)
      api().layoutRows()
    end)
    f._sortBtns[j] = b
  end

  local partyHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  partyHdr:SetPoint("TOPLEFT", sortRow, "BOTTOMLEFT", 0, -12)
  partyHdr:SetText(L.SETUP_PARTY_HEADER)

  local partyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  partyCheck:SetPoint("TOPLEFT", partyHdr, "BOTTOMLEFT", 0, -4)
  local partyLbl = A.setCheckButtonLabel(partyCheck, L.SETUP_PARTY_ENABLE)
  if partyLbl then
    partyLbl:SetTextColor(0.85, 0.87, 0.90)
  end
  f._partyCheck = partyCheck
  partyCheck:SetScript("OnClick", function(self)
    EnemyListDB.showPartyFrames = self:GetChecked() and true or false
    if f._cliqueFs then
      f._cliqueFs:SetShown(EnemyListDB.showPartyFrames)
    end
  end)

  local partyExp = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  partyExp:SetPoint("TOPLEFT", partyCheck, "BOTTOMLEFT", 24, 4)
  partyExp:SetWidth(420)
  partyExp:SetJustifyH("LEFT")
  partyExp:SetText(L.SETUP_PARTY_EXPLAIN)

  local cliqueFs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cliqueFs:SetPoint("TOPLEFT", partyExp, "BOTTOMLEFT", 0, -6)
  cliqueFs:SetWidth(420)
  cliqueFs:SetJustifyH("LEFT")
  cliqueFs:SetText(L.SETUP_PARTY_CLIQUE)
  cliqueFs:SetTextColor(0.75, 0.88, 1)
  cliqueFs:Hide()
  f._cliqueFs = cliqueFs

  local laterBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  laterBtn:SetSize(120, 24)
  laterBtn:SetPoint("BOTTOMLEFT", 16, 14)
  laterBtn:SetText(L.SETUP_LATER)
  laterBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.SETUP_LATER_HINT, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  laterBtn:SetScript("OnLeave", GameTooltip_Hide)
  laterBtn:SetScript("OnClick", function()
    setupWizardComplete(f, false)
  end)

  local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  doneBtn:SetSize(140, 24)
  doneBtn:SetPoint("BOTTOMRIGHT", -16, 14)
  doneBtn:SetText(L.SETUP_DONE)
  doneBtn:SetScript("OnClick", function()
    setupWizardComplete(f, true)
  end)

  setupWizardFrame = f
  return f
end

function EnemyList.ShowSetupWizard(force)
  local A = api()
  A.elSafe("initDB", A.initDB)
  if not A.elSafe("createMainFrame", A.createMainFrame) or not A.main() then
    A.elPrintErr("setup wizard", L.ERR_MAIN_FRAME_FAILED)
    return
  end
  if not force and EnemyListDB.setupWizardCompleted then
    return
  end
  local f = ensureSetupWizardFrame()
  f._curFs:SetText(string.format(L.SETUP_COPY_CURRENT, A.elPlayerProfileKey()))
  setupWizardRebuildCopyList(f)
  f._partyCheck:SetChecked(EnemyListDB.showPartyFrames and true or false)
  f._cliqueFs:SetShown(EnemyListDB.showPartyFrames and true or false)
  setupWizardRefreshSelections(f)
  EnemyListDB.testMode = true
  A.main():Show()
  A.layoutRows()
  A.applyUiScale()
  f:Show()
  if f.Raise then
    f:Raise()
  end
end
