--- Minimap button. Extracted from EnemyListUI.lua to keep the main UI chunk under Lua 5.1's
--- 200-local-variable limit. Depends on EnemyList._api (populated by EnemyListUI.lua).
--- Load order: must come after EnemyListUI.lua in the .toc.
---
--- Exposes:
---   EnemyList._createMinimapButton()            -- create once, then no-op. Also re-applies visibility.
---   EnemyList._applyMinimapButtonVisibility()   -- shows/hides based on EnemyListDB.minimapButtonHidden.

local _, EnemyList = ...
local L = EnemyList.L

local function api() return EnemyList._api end

local function enemyListMinimapPlaceButton(button, angleDeg)
  if not button or not Minimap then
    return
  end
  local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
  }
  local edgePad = 5
  local angle = math.rad(tonumber(angleDeg) or 220)
  local x, y = math.cos(angle), math.sin(angle)
  local q = 1
  if x < 0 then
    q = q + 1
  end
  if y > 0 then
    q = q + 2
  end
  local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
  local quadTable = minimapShapes[shape] or minimapShapes["ROUND"]
  local w = (Minimap:GetWidth() / 2) + edgePad
  local h = (Minimap:GetHeight() / 2) + edgePad
  if quadTable[q] then
    x, y = x * w, y * h
  else
    local diagRadiusW = math.sqrt(2 * (w ^ 2)) - 10
    local diagRadiusH = math.sqrt(2 * (h ^ 2)) - 10
    x = math.max(-w, math.min(x * diagRadiusW, w))
    y = math.max(-h, math.min(y * diagRadiusH, h))
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function enemyListApplyMinimapButtonVisibility()
  local b = _G.EnemyListMinimapBtn
  if not b then
    return
  end
  if type(EnemyListDB) == "table" and EnemyListDB.minimapButtonHidden then
    b:Hide()
  else
    b:Show()
  end
end

local function enemyListShowMinimapContextMenu(anchor)
  local list = {
    {
      text = L.MINIMAP_MENU_OPEN_SETTINGS,
      notCheckable = true,
      func = function()
        if CloseMenus then
          CloseMenus()
        end
        if EnemyList.ShowConfig then
          EnemyList.ShowConfig()
        end
      end,
    },
  }
  if type(EasyMenu) == "function" then
    EasyMenu(list, anchor, "cursor", 0, 0, "MENU", 2)
  elseif EnemyList.ShowConfig then
    EnemyList.ShowConfig()
  end
end

local function createMinimapButton()
  if _G.EnemyListMinimapBtn then
    enemyListApplyMinimapButtonVisibility()
    return
  end
  local btn = CreateFrame("Button", "EnemyListMinimapBtn", Minimap)
  --- Match LibDBIcon default (classic/mainline use same frame size; textures differ).
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  local hlOk = pcall(function()
    btn:SetHighlightTexture(136477)
  end)
  if not hlOk then
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  end

  local border = btn:CreateTexture(nil, "OVERLAY")
  local borderOk = pcall(function()
    border:SetTexture(136430)
  end)
  if not borderOk then
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  end
  local pid, pmain = _G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE
  local isMainline = pid and pmain and pid == pmain
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", 0, 0)
  if isMainline then
    border:SetSize(50, 50)
  else
    border:SetSize(53, 53)
  end

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  local bgOk = pcall(function()
    bg:SetTexture(136467)
  end)
  if not bgOk then
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  end
  bg:ClearAllPoints()
  if isMainline then
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER", 0, 0)
  else
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
  end

  local icon = btn:CreateTexture(nil, "ARTWORK")
  --- Addon asset (square PNG with circular art — matches LibDBIcon-style ring).
  icon:SetTexture("Interface\\AddOns\\EnemyList\\minimapicon.png")
  icon:SetTexCoord(0, 1, 0, 1)
  icon:ClearAllPoints()
  if isMainline then
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
  else
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
  end

  local function updatePosition()
    enemyListMinimapPlaceButton(btn, tonumber(EnemyListDB.minimapButtonAngle) or 220)
  end
  updatePosition()
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.MINIMAP_TOOLTIP_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(L.TOOLTIP_MINIMAP_BUTTON, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
  btn:SetScript("OnDragStart", function(self)
    GameTooltip_Hide()
    self._dragging = true
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      cx, cy = cx / scale, cy / scale
      local ang = math.atan2(cy - my, cx - mx)
      EnemyListDB.minimapButtonAngle = math.deg(ang) % 360
      updatePosition()
    end)
  end)
  btn:SetScript("OnDragStop", function(self)
    self._dragging = false
    self:SetScript("OnUpdate", nil)
  end)
  btn:SetScript("OnClick", function(self, button)
    local A = api()
    if button == "MiddleButton" then
      if type(EnemyListDB) == "table" then
        EnemyListDB.minimapButtonHidden = true
      end
      enemyListApplyMinimapButtonVisibility()
      if A and A.setConfigMinimapCheck then
        A.setConfigMinimapCheck(false)
      end
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MINIMAP_BTN_HIDDEN_CHAT)
      return
    end
    if button == "RightButton" then
      enemyListShowMinimapContextMenu(self)
      return
    end
    local m = A and A.main()
    if m then
      if m:IsShown() then
        m:Hide()
        EnemyListDB.hidden = true
      else
        m:Show()
        EnemyListDB.hidden = false
        A.layoutRows()
      end
    end
  end)
  enemyListApplyMinimapButtonVisibility()
end

EnemyList._createMinimapButton              = createMinimapButton
EnemyList._applyMinimapButtonVisibility     = enemyListApplyMinimapButtonVisibility
