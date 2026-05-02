--- EnemyListConfigWidgets.lua — small reusable config controls (sliders, segmented “style” buttons, booleans).
--- Single source of truth for padding, column split, and row metrics so all tabs match and resize consistently.

local _, EnemyList = ...
EnemyList.ConfigWidgets = EnemyList.ConfigWidgets or {}
local W = EnemyList.ConfigWidgets

--- Row heights / spacing (keep config UI uniform).
W.ROW_H_SLIDER = 42
W.ROW_H_SEGMENT = 36
W.BUTTON_H = 20
W.BTN_GAP = 2
W.BTN_LEFT_PAD = 4
W.BTN_ROW_TOP = -16

-- --------------------------------------------------------------------------- label / track / value split
function W.SliderLabelValueWidths(inner)
  local leftPad, valPad, gap, tvgap = 8, 6, 12, 10
  local fixed = leftPad + valPad + gap + tvgap
  inner = inner or 300
  --- Value column: reserve enough for "500px" / "100%" / "+50px" on narrow config windows.
  local valW = math.max(118, math.min(152, math.floor(inner * 0.34)))
  local labelW = inner - fixed - valW
  if labelW < 72 then
    valW = math.min(142, math.max(40, inner - fixed - 72))
    labelW = inner - fixed - valW
  end
  if labelW > 214 then
    labelW = 214
    valW = inner - fixed - labelW
    valW = math.max(72, math.min(142, valW))
  end
  return labelW, valW, valPad, leftPad, gap, tvgap
end

function W.LayoutOptionSliderRow(slider, inner)
  if not slider or not slider._elRow or not slider._elLabelFs then
    return
  end
  local row = slider._elRow
  local labelW, valW, valPad, leftPad, gap, trackValGap = W.SliderLabelValueWidths(inner)
  if row.SetWidth then
    row:SetWidth(inner)
  end
  if row.SetClipsChildren then
    pcall(function()
      row:SetClipsChildren(true)
    end)
  end
  local lbl = slider._elLabelFs
  local valFs = slider._elValueFs
  local track = slider._elTrackFrame
  lbl:ClearAllPoints()
  lbl:SetWidth(labelW)
  lbl:SetPoint("LEFT", row, "LEFT", leftPad, 0)
  lbl:SetJustifyH("RIGHT")
  if valFs then
    valFs:ClearAllPoints()
    valFs:SetWidth(valW)
    valFs:SetPoint("RIGHT", row, "RIGHT", -valPad, 0)
  end
  if track then
    track:ClearAllPoints()
    track:SetHeight(24)
    track:SetPoint("LEFT", row, "LEFT", leftPad + labelW + gap, 0)
    if valFs then
      track:SetPoint("RIGHT", valFs, "LEFT", -trackValGap, 0)
    else
      track:SetPoint("RIGHT", row, "RIGHT", -valPad, 0)
    end
    slider:ClearAllPoints()
    slider:SetPoint("TOPLEFT", track, "TOPLEFT", 2, -1)
    slider:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -2, 1)
  else
    slider:ClearAllPoints()
    slider:SetHeight(20)
    slider:SetPoint("LEFT", row, "LEFT", leftPad + labelW + gap, 0)
    if valFs then
      slider:SetPoint("RIGHT", valFs, "LEFT", -8, 0)
    else
      slider:SetPoint("RIGHT", row, "RIGHT", -valPad, 0)
    end
  end
end

-- --------------------------------------------------------------------------- slider (numeric option row)
function W.CreateOptionSlider(row, opts)
  opts = opts or {}
  local labelText = opts.label or ""
  local tooltip = opts.tooltip
  local minV = opts.min or 0
  local maxV = opts.max or 1
  local step = opts.step or 1
  local isInt = opts.integer ~= false
  local formatVal = opts.format or tostring
  local onChange = opts.onChange
  local dbWriteGate = opts.dbWriteGate
  local rowInner = opts.rowInnerWidth or 300
  local labelColW = opts.labelColWidth
  local LABEL_LEFT_PAD, COL_GAP, VALUE_W, VALUE_RIGHT_PAD, trackValGap
  if not labelColW then
    labelColW, VALUE_W, VALUE_RIGHT_PAD, LABEL_LEFT_PAD, COL_GAP, trackValGap = W.SliderLabelValueWidths(rowInner)
  else
    LABEL_LEFT_PAD = 8
    COL_GAP = 12
    VALUE_W = 94
    VALUE_RIGHT_PAD = 6
    trackValGap = 10
  end
  local labelFontName = _G.GameFontNormal and "GameFontNormal" or "GameFontNormalSmall"
  local lbl = row:CreateFontString(nil, "OVERLAY", labelFontName)
  lbl:SetPoint("LEFT", row, "LEFT", LABEL_LEFT_PAD, 0)
  lbl:SetWidth(labelColW)
  lbl:SetJustifyH("RIGHT")
  lbl:SetTextColor(0.9, 0.92, 0.96)
  lbl:SetShadowColor(0, 0, 0, 1)
  lbl:SetShadowOffset(1, -1)
  lbl:SetText(labelText)
  local valFontName = _G.GameFontHighlightSmall and "GameFontHighlightSmall" or "GameFontNormalSmall"
  local valFs = row:CreateFontString(nil, "OVERLAY", valFontName)
  valFs:SetPoint("RIGHT", row, "RIGHT", -VALUE_RIGHT_PAD, 0)
  valFs:SetWidth(VALUE_W)
  valFs:SetJustifyH("RIGHT")
  valFs:SetTextColor(0.62, 0.86, 1)
  valFs:SetShadowColor(0, 0, 0, 1)
  valFs:SetShadowOffset(1, -1)
  local trackBd = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  local trackFrame = CreateFrame("Frame", nil, row, trackBd)
  trackFrame:SetFrameLevel((row:GetFrameLevel() or 0) + 2)
  trackFrame:SetHeight(24)
  trackFrame:SetPoint("LEFT", row, "LEFT", LABEL_LEFT_PAD + labelColW + COL_GAP, 0)
  trackFrame:SetPoint("RIGHT", valFs, "LEFT", -(trackValGap or 10), 0)
  if trackFrame.SetBackdrop then
    pcall(function()
      trackFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      trackFrame:SetBackdropColor(0.14, 0.15, 0.18, 0.98)
      trackFrame:SetBackdropBorderColor(0.42, 0.48, 0.56, 0.75)
    end)
  end
  local groove = trackFrame:CreateTexture(nil, "ARTWORK")
  groove:SetColorTexture(0.06, 0.07, 0.09, 1)
  groove:SetPoint("TOPLEFT", trackFrame, "TOPLEFT", 8, -8)
  groove:SetPoint("BOTTOMRIGHT", trackFrame, "BOTTOMRIGHT", -8, 8)
  local slider = CreateFrame("Slider", nil, trackFrame)
  slider:SetFrameLevel(trackFrame:GetFrameLevel() + 3)
  pcall(function()
    slider:SetOrientation("HORIZONTAL")
  end)
  slider:EnableMouse(true)
  slider:ClearAllPoints()
  slider:SetPoint("TOPLEFT", trackFrame, "TOPLEFT", 2, -1)
  slider:SetPoint("BOTTOMRIGHT", trackFrame, "BOTTOMRIGHT", -2, 1)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
  thumb:SetSize(14, 20)
  thumb:SetVertexColor(0.5, 0.78, 1, 1)
  local okThumb = pcall(function()
    slider:SetThumbTexture(thumb)
  end)
  if not okThumb then
    pcall(function()
      slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end)
  end
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then
    pcall(function()
      slider:SetObeyStepOnDrag(true)
    end)
  end
  slider._elLabelFs = lbl
  slider._elRow = row
  slider._elValueFs = valFs
  slider._elTrackFrame = trackFrame
  slider._elGrooveTex = groove
  local function snap(v)
    if isInt then
      return math.max(minV, math.min(maxV, math.floor(v + 0.5)))
    end
    local st = step > 0 and step or 0.01
    local snapped = math.floor(v / st + 0.5) * st
    if snapped < minV then
      snapped = minV
    end
    if snapped > maxV then
      snapped = maxV
    end
    return snapped
  end
  slider:SetScript("OnValueChanged", function(self, raw)
    if self._elIgnore then
      return
    end
    local v = snap(raw)
    if math.abs(v - raw) > 1e-4 then
      self._elIgnore = true
      self:SetValue(v)
      self._elIgnore = false
    end
    valFs:SetText(formatVal(v))
    if onChange and (not dbWriteGate or dbWriteGate()) then
      onChange(v)
    end
  end)
  slider._elThumbTex = thumb
  local function sliderShowTooltip()
    if tooltip and tooltip ~= "" then
      GameTooltip:SetOwner(slider, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end
  end
  local function sliderOnEnter()
    if thumb and thumb.SetVertexColor then
      thumb:SetVertexColor(0.82, 0.94, 1, 1)
    end
    if trackFrame.SetBackdropBorderColor then
      pcall(function()
        trackFrame:SetBackdropBorderColor(0.55, 0.68, 0.88, 0.9)
      end)
    end
    sliderShowTooltip()
  end
  local function sliderOnLeave()
    if thumb and thumb.SetVertexColor then
      thumb:SetVertexColor(0.5, 0.78, 1, 1)
    end
    if trackFrame.SetBackdropBorderColor then
      pcall(function()
        trackFrame:SetBackdropBorderColor(0.42, 0.48, 0.56, 0.75)
      end)
    end
    GameTooltip_Hide()
  end
  slider:SetScript("OnEnter", sliderOnEnter)
  slider:SetScript("OnLeave", sliderOnLeave)
  function slider:setValueSilent(v)
    v = snap(v)
    self._elIgnore = true
    self:SetValue(v)
    self._elIgnore = false
    valFs:SetText(formatVal(v))
  end
  return slider
end

-- --------------------------------------------------------------------------- segmented “style” buttons (HP position, name position, …)
function W.LayoutStyleButtonRow(row, rowW, n)
  if not row or not row._btns or not rowW or rowW < 60 or not n or n < 1 then
    return
  end
  local leftPad, btnGap, rowTop = W.BTN_LEFT_PAD, W.BTN_GAP, W.BTN_ROW_TOP
  local gaps = (n - 1) * btnGap
  local usable = rowW - leftPad * 2 - gaps
  local btnW = math.max(1, math.floor(usable / n))
  if 2 * leftPad + n * btnW + gaps > rowW then
    btnW = math.max(1, math.floor((rowW - 2 * leftPad - gaps) / n))
  end
  row:SetWidth(rowW)
  for j, b in ipairs(row._btns) do
    if b and b.SetSize and b.SetPoint then
      b:SetSize(btnW, W.BUTTON_H)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", row, "TOPLEFT", leftPad + (j - 1) * (btnW + btnGap), rowTop)
      local fs = b.GetFontString and b:GetFontString()
      if fs and fs.SetWidth and fs.SetJustifyH then
        fs:SetWidth(math.max(4, btnW - 6))
        fs:SetJustifyH("CENTER")
      end
    end
  end
  if row.SetClipsChildren then
    pcall(function()
      row:SetClipsChildren(true)
    end)
  end
end

--- @param o.placeAfter  anchor frame; row is |TOPLEFT| of |placeAfter| |BOTTOMLEFT| + (o.offsetX, o.offsetY).
function W.CreateStyleButtonRow(parent, o)
  o = o or {}
  local placeAfter = o.placeAfter
  local rowW = o.rowWidth or 300
  local ids = o.ids
  if type(ids) ~= "table" or #ids < 1 or not placeAfter then
    return nil, function() end
  end
  local title = o.titleText
  local getLabel = o.getLabel
  if type(getLabel) ~= "function" then
    return nil, function() end
  end
  local getCurrent = o.getCurrent
  local onPick = o.onPick
  if type(getCurrent) ~= "function" or type(onPick) ~= "function" then
    return nil, function() end
  end
  local perTooltip = o.tooltipFor
  local sharedTooltip = o.tooltip
  local offsetX = o.offsetX or 0
  local offsetY = o.offsetY or -4
  local bdMixin = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(rowW, W.ROW_H_SEGMENT)
  row:SetPoint("TOPLEFT", placeAfter, "BOTTOMLEFT", offsetX, offsetY)
  if title then
    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", row, "TOPLEFT", W.BTN_LEFT_PAD, 0)
    lbl:SetTextColor(0.74, 0.77, 0.82)
    lbl:SetText(title)
  end
  local n = #ids
  local btns = {}
  for i, id in ipairs(ids) do
    local b = CreateFrame("Button", nil, row, bdMixin)
    b:SetSize(40, W.BUTTON_H)
    b:SetPoint("TOPLEFT", row, "TOPLEFT", W.BTN_LEFT_PAD, W.BTN_ROW_TOP)
    if b.SetBackdrop then
      b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
    end
    b:SetNormalFontObject("GameFontNormalSmall")
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(getLabel(id) or tostring(id))
    b:SetFontString(fs)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      local have = false
      if type(perTooltip) == "function" then
        local tt = perTooltip(id)
        if tt and tt ~= "" then
          GameTooltip:SetText(tt, nil, nil, nil, nil, true)
          have = true
        end
      end
      if not have and sharedTooltip and sharedTooltip ~= "" then
        GameTooltip:SetText(sharedTooltip, nil, nil, nil, nil, true)
        have = true
      end
      if have then
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    btns[i] = b
  end
  W.LayoutStyleButtonRow(row, rowW, n)
  local function updateSelection()
    local cur = getCurrent()
    for i, id in ipairs(ids) do
      local b = btns[i]
      if b then
        local active = (id == cur)
        if b.SetBackdropColor then
          b:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
          if active then
            b:SetBackdropBorderColor(1, 0.82, 0, 0.9)
          else
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
          end
        end
        local fss = b:GetFontString()
        if fss then
          fss:SetTextColor(active and 1 or 0.7, active and 0.82 or 0.72, active and 0 or 0.75)
        end
      end
    end
  end
  for i = 1, n do
    if btns[i] then
      btns[i]:SetScript("OnClick", function()
        onPick(ids[i])
        updateSelection()
      end)
    end
  end
  updateSelection()
  row._btns = btns
  row._rebuildWidths = function(w)
    W.LayoutStyleButtonRow(row, w, n)
  end
  if row.SetClipsChildren then
    pcall(function()
      row:SetClipsChildren(true)
    end)
  end
  return row, updateSelection
end

-- --------------------------------------------------------------------------- boolean = checkbox
local function setCheckText(btn, text)
  if btn.Text and btn.Text.SetText then
    btn.Text:SetText(text)
    return btn.Text
  end
  local name = btn:GetName()
  if name then
    local fs = _G[name .. "Text"]
    if fs and fs.SetText then
      fs:SetText(text)
      return fs
    end
  end
  for i = 1, select("#", btn:GetRegions()) do
    local r = select(i, btn:GetRegions())
    if r and r.GetObjectType and r:GetObjectType() == "FontString" then
      r:SetText(text)
      return r
    end
  end
end

function W.SetBooleanLabel(btn, text)
  return setCheckText(btn, text)
end

--- @param o.placeAfter| o.point — either anchor (frame + offset) or explicit SetPoint in |o|.
function W.CreateBooleanOption(parent, o)
  o = o or {}
  local check = CreateFrame("CheckButton", nil, parent, o.template or "UICheckButtonTemplate")
  if o.placeAfter then
    check:SetPoint("TOPLEFT", o.placeAfter, o.relPoint or "BOTTOMLEFT", o.offsetX or 0, o.offsetY or -4)
  elseif o.point and o.ref then
    check:SetPoint(o.point, o.ref, o.relPoint, o.x or 0, o.y or 0)
  else
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  end
  local text = o.text or ""
  local fs = setCheckText(check, text)
  local c = o.textColor
  if fs and c and fs.SetTextColor then
    if type(c) == "table" then
      fs:SetTextColor(c[1] or 0.85, c[2] or 0.87, c[3] or 0.9)
    else
      fs:SetTextColor(0.85, 0.87, 0.9)
    end
  elseif fs and fs.SetTextColor then
    fs:SetTextColor(0.85, 0.87, 0.9)
  end
  if o.onClick then
    check:SetScript("OnClick", o.onClick)
  end
  if o.onEnter or o.tooltip then
    check:SetScript("OnEnter", function(s)
      if o.onEnter then
        o.onEnter(s)
      elseif o.tooltip and o.tooltip ~= "" then
        GameTooltip:SetOwner(s, o.tooltipAnchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(o.tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
      end
    end)
  end
  if o.onLeave then
    check:SetScript("OnLeave", o.onLeave)
  elseif o.onEnter or o.tooltip then
    check:SetScript("OnLeave", GameTooltip_Hide)
  end
  return check, fs
end
