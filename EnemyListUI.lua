local addonName, EnemyList = ...
local L = EnemyList.L

--- ==============================================================================================
--- EnemyListUI.lua — main UI. Contains: DB defaults, profile switching, main frame, row / grid
--- rendering, layoutRows, party frames, config window, login/slash frame.
---
--- *** Lua 5.1 hard-limits every function (including the main chunk) to 200 |local| variables. ***
---
--- This file is already close to that ceiling. Before adding a new top-level |local function X|
--- or |local x|, consider one of these instead:
---   1. Put the function on |_EL.X| (namespace table declared below) — costs zero new locals.
---   2. Put it on |EnemyList.X| if other files need it — also zero new locals.
---   3. Put it in its own sibling file (see EnemyListSetupWizard.lua / EnemyListMinimap.lua for
---      the pattern: depend on EnemyList._api, add to the .toc after EnemyListUI.lua).
--- When code for a feature naturally clusters (wizard, minimap, config tab, …) prefer (3): split
--- it into a new file so each file has its own 200-local budget.
--- ==============================================================================================

local defaults = {
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = 0,
  width = 200,
  barHeight = 34,
  compactRow = false,
  --- Truncate long enemy names with an ellipsis so they don't overflow past the row/cell bounds.
  truncateLongNames = true,
  maxNameLength = 14,
  showBackground = true,
  barOpacity = 0.85,
  singleColumn = false,
  sortMode = 1, --- 1=highest aggro, 2=lowest aggro, 3=highest hp, 4=lowest hp
  fontPreset = 3,
  maxEnemiesAggro = 10,
  maxEnemiesOther = 10,
  uiScale = 1,
  locked = false,
  hidden = false,
  testMode = false,
  --- Verbose chat logging: |cffffcc00/el debug|r to toggle.
  debug = false,
  --- Batch list redraws (~10/sec) for FPS; uncheck to test legacy “every event” mode (heavier).
  coalesceUIRefresh = true,
  --- Mirror error lines into SavedVariables when |cffffcc00/el logsave on|r (see chat hint).
  saveCombatLogToDB = false,
  combatLogMaxLines = 500,
  configWindowWidth = 452,
  configWindowHeight = 436,
  --- Raise nameplateMaxDistance toward client max (Plater-style) so distant mobs get nameplateN tokens for threat.
  extendNameplateRange = true,
  --- Colored border on hostile nameplates from threat (tank lose-aggro pulse when |rawThreatPct| is available).
  nameplateThreatOverlay = false,
  --- Mirror the enemy-list row (distance / threat / target) on the nameplate (above the bar).
  nameplateListMirror = false,
  --- When the player is 2nd on the mob’s threat (by group |UnitDetailedThreatSituation|), use a separate border color (Nameplates tab).
  nameplateThreatSecondStyle = false,
  --- Put 2nd-on-threat mobs in the same “aggressives” list column (Appearance tab; uses rank, not just %).
  listShowSecondInAggroSection = false,
  --- Feature: fade out of combat
  showRaidMarkers = true,
  showCastBar = true,
  healthBarHeight = 14,
  castBarHeight = 10,
  showThreatBar = true,
  threatBarHeight = 5,
  --- Runner-up threat bar (enemy list): shows the top N non-tanking threat holders so the current
  --- tank can see how close the 2nd / 3rd place is to pulling. Count clamped 1–5.
  showRunnerUpBars = false,
  runnerUpBarCount = 3,
  runnerUpBarHeight = 4,
  --- One bar under your threat: who is 2nd on the full threat table (uses same height as runner-up bars).
  showSecondOnThreatBar = true,
  showSelfToT = false,
  fadeOutOfCombat = false,
  --- Feature: healer mode
  healerMode = false,
  gridMode = false,
  gridCellSize = 50,
  gridColumns = 3,
  --- Feature: minimap button angle
  minimapButtonAngle = 220,
  --- Feature: party frames with color-coded borders
  showPartyFrames = false,
  partyFrameSize = 40,
  partyFrameVertical = false,
  partyFrameUnitGap = 2,
  partyFrameGroupGap = 6,
  partyFrameShowHpDeficit = true,
  partyFrameShowDebuffs = true,
  partyFrameHealthBarHeight = 8,
  partyFrameHpDeficitTextR = 1,
  partyFrameHpDeficitTextG = 0.42,
  partyFrameHpDeficitTextB = 0.32,
  partyFrameHpDeficitBorderR = 0,
  partyFrameHpDeficitBorderG = 0,
  partyFrameHpDeficitBorderB = 0,
  --- Lost HP number on party bar: multiplier for base font height (0.5–2.0).
  partyFrameHpDeficitFontScale = 1,
  --- Party frame center: enemies-attacking count (RGB + font scale).
  partyFrameAggroCountTextR = 1,
  partyFrameAggroCountTextG = 1,
  partyFrameAggroCountTextB = 1,
  partyFrameAggroCountFontScale = 1,
  --- When true, minimap button is hidden (middle-click or option); use |cffffcc00/el minimap show|r to restore.
  minimapButtonHidden = false,
  --- Seconds without combat-log activity before an enemy row is dropped (1–60).
  enemyInactivityFilterSec = 5,
  --- Show party/raid combat on the list when you are not in combat yet.
  showPartyCombatEnemies = false,
  --- Grid2-style profile switching. |profiles| stores a snapshot per group type; |activeProfileName| is the currently loaded one.
  --- When |autoSwitchProfile| is on, entering a raid swaps to the raid profile and leaving returns to party.
  autoSwitchProfile = true,
  activeProfileName = "party",
  profiles = nil,
  --- Configurable colors for the enemy row bars (grid + rows share the same palette).
  enemyHpBarR = 0.1, enemyHpBarG = 0.9, enemyHpBarB = 0.1,
  enemyAggroBarR = 0.9, enemyAggroBarG = 0.1, enemyAggroBarB = 0.1,
  enemyCastBarR = 0.2, enemyCastBarG = 0.7, enemyCastBarB = 1.0,
  --- Party frame HP bar palette.
  useClassColorsParty = true,
  partyHpFallbackR = 0.2, partyHpFallbackG = 0.8, partyHpFallbackB = 0.2,
  partyHpOutOfRangeR = 0.24, partyHpOutOfRangeG = 0.24, partyHpOutOfRangeB = 0.26,
  --- Mana / primary power bar on party frames (opt-in: mana, rage, energy, focus drawn in the same slot).
  showPartyManaBars = false,
  partyManaBarHeight = 4,
  partyManaBarR = 0.16, partyManaBarG = 0.44, partyManaBarB = 0.9,
  usePowerTypeColorsParty = true,
  --- Debuff-strip colors on party frames. One triple per dispel type. Defaults match the original hardcoded palette.
  debuffCurseR   = 0.55, debuffCurseG   = 0.28, debuffCurseB   = 0.88,
  debuffDiseaseR = 0.92, debuffDiseaseG = 0.82, debuffDiseaseB = 0.18,
  debuffMagicR   = 0.22, debuffMagicG   = 0.55, debuffMagicB   = 1.00,
  debuffPoisonR  = 0.25, debuffPoisonG  = 0.88, debuffPoisonB  = 0.35,
  debuffHealingR = 0.92, debuffHealingG = 0.22, debuffHealingB = 0.22,
  --- Raid-specific toggles (applied regardless of profile — group-state gated at read time).
  hidePartyFramesInRaid = false,
  --- Profile-scoped: show the attacker-count digit on the player's own party/raid frame.
  --- Off hides only the digit (background + borders still light up when mobs target you).
  showSelfAggroCount = true,
  --- Party frame bar orientation (each bar independent — "mixed" = H+V combo). Legacy keys kept
  --- so old DBs don't lose a user's vertical toggle; read path prefers |partyHpBarPosition|.
  partyHpBarVertical   = false,
  partyManaBarVertical = false,
  --- Per-bar edge placement: "bottom" | "top" | "left" | "right". Controls both orientation and
  --- anchor side. If both bars land on the same edge, the mana bar stacks next to the hp bar.
  partyHpBarPosition   = "bottom",
  partyManaBarPosition = "top",
  --- Party frame: show unit name as overlay text. Position picks which edge the name anchors to
  --- — "top" (default) collides with the debuff strip, so raid healers usually want "bottom".
  --- |*OffsetX|/|*OffsetY| nudge the anchor in pixels (+X = right, +Y = up, WoW convention).
  partyFrameShowName     = false,
  --- Show party/raid member pets as their own frames. Owner's pet appears in the owner's subgroup
  --- (or group 1 for non-raid). Hunter / warlock / mage / DK pets, plus your own |pet| token. Off by
  --- default so the layout doesn't suddenly grow when an addon update lands.
  partyShowPets = false,
  --- Show buff icons cast BY THE PLAYER on each party/raid member (Renew, PW:Shield, Prayer of
  --- Mending, Lifebloom, Beacon of Light, etc.). Filter is |caster == "player"|, so other people's
  --- HoTs aren't shown — keeps the strip focused on what you can actually refresh / manage.
  partyShowPlayerBuffs = false,
  partyPlayerBuffSlotCount = 5,
  partyPlayerBuffIconSize = 14,
  --- Max base duration (seconds) to show. Filters out auras / blessings / mark of the wild that
  --- last 5–30 minutes — they're not what healers/DPS-buff-trackers want to see refreshed. Set to
  --- 0 to disable the filter (show everything you cast). Permanent buffs (duration == 0 in the API)
  --- are always hidden when the filter is active.
  partyPlayerBuffMaxDuration = 60,
  --- Where the buff icon strip sits on each unit frame. "top" / "bottom" run horizontal; "left" /
  --- "right" stack the icons vertically. X/Y offsets nudge the row in pixels (-50..50).
  partyPlayerBuffAnchor = "bottom",
  partyPlayerBuffOffsetX = 0,
  partyPlayerBuffOffsetY = 0,
  --- Role icon (tank/healer/damager) in the top-left corner of each party/raid frame. Classic lacks
  --- |UnitGroupRolesAssigned|, so live mode only resolves MAINTANK via |GetPartyAssignment|; test
  --- mode uses a fixed fake role cycle so the user can preview the feature.
  partyShowRoleIcon = false,
  partyRoleIconSize = 12,
  partyFrameNameFontScale = 1.0,
  partyFrameNamePosition = "top",
  partyFrameNameOffsetX  = 0,
  partyFrameNameOffsetY  = 0,
  --- Aggro border — the colored ring around a unit when enemies are attacking them.
  partyShowAggroBorder         = true,
  partyUseCustomAggroBorderColor = false,
  partyAggroBorderR            = 1.0, partyAggroBorderG = 0.2, partyAggroBorderB = 0.2,
  partyAggroBorderThickness    = 2,
  --- Aggro-count digit pixel offsets (±50 px, +X right, +Y up).
  partyAggroCountOffsetX       = 0,
  partyAggroCountOffsetY       = 0,
  --- Incoming-heal prediction overlay. Uses UnitGetIncomingHeals() when the client exposes it
  --- (Retail + any Classic build that has the API); on older clients the bar just stays empty.
  partyShowIncomingHeals = false,
  partyIncomingHealR = 0.40, partyIncomingHealG = 1.00, partyIncomingHealB = 0.40,
  partySelfHealR     = 0.30, partySelfHealG     = 0.85, partySelfHealB     = 1.00,
  --- Low-state border flash (red for HP, blue for mana by default — both configurable).
  partyLowHpFlashEnabled   = false,
  partyLowHpThreshold      = 30,
  partyLowHpFlashR         = 1.00, partyLowHpFlashG = 0.15, partyLowHpFlashB = 0.15,
  partyLowManaFlashEnabled = false,
  partyLowManaThreshold    = 20,
  partyLowManaFlashR       = 0.30, partyLowManaFlashG = 0.50, partyLowManaFlashB = 1.00,
}

local RESIZE_MIN_W = 240
local RESIZE_MAX_W = 1000
local CONFIG_RESIZE_MIN_W = 380
local CONFIG_RESIZE_MAX_W = 780
local CONFIG_RESIZE_MIN_H = 320
local CONFIG_RESIZE_MAX_H = 800
local CONFIG_SECTION_LINE_TRIM = 8
--- Rate-limit chat when row pool is empty during combat (avoid spam from OnUpdate).
local lastSecureRowCombatWarn = 0
local SECURE_ROW_COMBAT_WARN_INTERVAL = 10

local main, mainScaleRoot, mainScaleBackdrop, rowContainer, configFrame, mainFadeTickerFrame
--- Filled after createConfigOptionSlider; used by syncConfigInnerLayout for column widths.
local layoutConfigOptionSliderColumns
--- (spell config rows removed; variable kept for backwards compat with syncConfigInnerLayout)
local layoutConfigSpellRows
--- Bump when config layout changes so /el config rebuilds (avoids stuck broken frames).
local CONFIG_UI_BUILD = 84
local rowsAggro = {}
local rowsOther = {}
local gridCells = {}
local GRID_CASTBAR_H = 12
local GRID_GAP = 2
local GRID_NAME_H = 14
local SECTION_HEAD_H = 16
local COL_GAP = 6
local ROW_TOP_PAD = 4
local ROW_GAP = 4
--- Extra column height so the last row (fonts, pct bar) stays inside the backdrop.
local LAYOUT_COL_BOTTOM_PAD = 2
local PCT_BAR_HEIGHT = 5
local ROW_TEXT_PAD = 14
--- Space reserved above row columns (thin drag strip only; no title bar).
local MAIN_HEADER_OFFSET = 12
local MAIN_BOTTOM_PAD = 4
local FONT_PRESET_MAX = 8
local MAX_ENEMIES_CAP = 20
local ENEMY_INACTIVITY_FILTER_SEC_MIN = 1
local ENEMY_INACTIVITY_FILTER_SEC_MAX = 60
local BAR_HEIGHT_MIN = 16
local BAR_HEIGHT_MAX = 56
local UI_SCALE_MIN = 0.5
local UI_SCALE_MAX = 1.5

local PROFILE_SNAPSHOT_SKIP = {
  combatLogLines = true,
  setupWizardCompleted = true,
}

--- Keys that are NOT swapped when switching between party and raid profiles.
--- Housekeeping, window state, and the profile machinery itself stay account-/character-wide.
local PROFILE_NON_SCOPED = {
  combatLogLines = true,
  combatLogMaxLines = true,
  saveCombatLogToDB = true,
  setupWizardCompleted = true,
  debug = true,
  coalesceUIRefresh = true,
  testMode = true,
  hidden = true,
  locked = true,
  configWindowWidth = true,
  configWindowHeight = true,
  minimapButtonHidden = true,
  minimapButtonAngle = true,
  point = true,
  relPoint = true,
  x = true,
  y = true,
  profiles = true,
  activeProfileName = true,
  autoSwitchProfile = true,
}

local function initAccountDB()
  if type(EnemyListAccountDB) ~= "table" then
    EnemyListAccountDB = {}
  end
  if type(EnemyListAccountDB.profiles) ~= "table" then
    EnemyListAccountDB.profiles = {}
  end
end

local function elPlayerProfileKey()
  local n = UnitName("player")
  local r = (GetRealmName and GetRealmName()) or ""
  if n and r ~= "" then
    return n .. "-" .. r
  end
  if n then
    return n .. "-?"
  end
  return "?"
end

local function elDeepCopy(val, depth)
  depth = (depth or 0) + 1
  if depth > 24 then
    return nil
  end
  local tv = type(val)
  if tv == "table" then
    local c = {}
    for k, v in pairs(val) do
      c[k] = elDeepCopy(v, depth)
    end
    return c
  end
  if tv == "userdata" then
    return nil
  end
  return val
end

local function enemyListProfileSnapshot(db)
  if type(db) ~= "table" then
    return {}
  end
  local out = {}
  for k, v in pairs(db) do
    if not PROFILE_SNAPSHOT_SKIP[k] and type(k) == "string" and (not k:find("^_el")) then
      out[k] = elDeepCopy(v)
    end
  end
  return out
end

function EnemyList.SaveAccountProfileSnapshot()
  initAccountDB()
  local key = elPlayerProfileKey()
  local snap = enemyListProfileSnapshot(EnemyListDB)
  EnemyListAccountDB.profiles[key] = {
    ts = (type(time) == "function" and time()) or 0,
    data = snap,
  }
  --- Cap account snapshots so SavedVariables stay bounded.
  local profiles = EnemyListAccountDB.profiles
  local list = {}
  for pk, ent in pairs(profiles) do
    if type(ent) == "table" then
      list[#list + 1] = { k = pk, ts = tonumber(ent.ts) or 0 }
    end
  end
  table.sort(list, function(a, b)
    return a.ts > b.ts
  end)
  for i = 25, #list do
    profiles[list[i].k] = nil
  end
end

local function enemyListApplyProfileData(data)
  if type(data) ~= "table" or type(EnemyListDB) ~= "table" then
    return
  end
  for k, v in pairs(data) do
    if k ~= "setupWizardCompleted" and k ~= "combatLogLines" and type(k) == "string" then
      EnemyListDB[k] = elDeepCopy(v)
    end
  end
end

--- Desired profile name based on current group state (Grid2-style: raid vs party).
local function enemyListDesiredProfileName()
  if IsInRaid and IsInRaid() then
    return "raid"
  end
  return "party"
end

local function enemyListProfileLabel(name)
  if name == "raid" then
    return EnemyList.L and EnemyList.L.OPT_PROFILE_RAID or "Raid"
  end
  return EnemyList.L and EnemyList.L.OPT_PROFILE_PARTY or "Party"
end

--- Snapshot top-level scoped keys into |EnemyListDB.profiles[name]|.
local function enemyListCaptureProfile(name)
  if type(EnemyListDB) ~= "table" then return end
  if type(EnemyListDB.profiles) ~= "table" then
    EnemyListDB.profiles = {}
  end
  local snap = {}
  for k, v in pairs(EnemyListDB) do
    if type(k) == "string" and not PROFILE_NON_SCOPED[k] and not k:find("^_") then
      snap[k] = elDeepCopy(v)
    end
  end
  EnemyListDB.profiles[name] = snap
end

--- Pull |EnemyListDB.profiles[name]| onto top-level scoped keys. Missing keys revert to |defaults|.
local function enemyListLoadProfile(name)
  if type(EnemyListDB) ~= "table" then return end
  local p = EnemyListDB.profiles and EnemyListDB.profiles[name]
  if type(p) ~= "table" then
    --- First switch ever into this profile name: seed from current values.
    enemyListCaptureProfile(name)
    EnemyListDB.activeProfileName = name
    return
  end
  --- Clear scoped keys so the target profile fully replaces the previous state.
  for k in pairs(EnemyListDB) do
    if type(k) == "string" and not PROFILE_NON_SCOPED[k] and not k:find("^_") then
      EnemyListDB[k] = nil
    end
  end
  for k, v in pairs(p) do
    EnemyListDB[k] = elDeepCopy(v)
  end
  for k, v in pairs(defaults) do
    if EnemyListDB[k] == nil and not PROFILE_NON_SCOPED[k] then
      EnemyListDB[k] = v
    end
  end
  EnemyListDB.activeProfileName = name
end

--- Forward declarations: these UI helpers are defined later in the file but used from the profile switch.
local refreshConfigFieldsFromDB
local layoutRows
local updatePartyFrameSize
local applyMainBackground
local togglePartyFramesVisibility
--- All the color / toggle / reapply helpers added for the Colors tab live on a single namespace table
--- so they don't each consume a top-level |local| slot (Lua 5.1 caps the main chunk at 200 locals).
local _EL = {}

local function enemyListAfterProfileLoad()
  if type(refreshConfigFieldsFromDB) == "function" and configFrame then
    pcall(refreshConfigFieldsFromDB, configFrame)
  end
  if type(applyMainBackground) == "function" then
    pcall(applyMainBackground)
  end
  if type(layoutRows) == "function" then
    pcall(layoutRows)
  end
  if type(togglePartyFramesVisibility) == "function" then
    pcall(togglePartyFramesVisibility)
  end
  if type(updatePartyFrameSize) == "function" then
    pcall(updatePartyFrameSize)
  end
  if type(_EL.reapplyEnemyBarColors) == "function" then
    pcall(_EL.reapplyEnemyBarColors)
  end
  if type(_EL.reapplyPartyBarColors) == "function" then
    pcall(_EL.reapplyPartyBarColors)
  end
  if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
    pcall(EnemyList.RefreshNameplateThreatOverlays, true)
  end
  if type(EnemyList.RefreshNameplateListMirrors) == "function" then
    pcall(EnemyList.RefreshNameplateListMirrors, true)
  end
  if type(EnemyList.UpdateFadeOutCombatTicker) == "function" then
    pcall(EnemyList.UpdateFadeOutCombatTicker)
  end
end

--- Called on login / group changes. Captures the current active profile before swapping to the desired one.
local function enemyListApplyGroupProfileSwitch(force)
  if type(EnemyListDB) ~= "table" then return end
  if EnemyListDB.autoSwitchProfile == false and not force then
    --- Still record the current state under the active slot so user edits survive.
    enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
    return
  end
  --- Combat lockdown: DB reshuffle is safe, but secure frame updates should wait.
  --- We still swap DB values (no protected calls) and flag a deferred re-layout.
  local desired = enemyListDesiredProfileName()
  local active = EnemyListDB.activeProfileName or "party"
  if active == desired and not force then
    return
  end
  enemyListCaptureProfile(active)
  enemyListLoadProfile(desired)
  enemyListAfterProfileLoad()
end

EnemyList.ApplyGroupProfileSwitch = enemyListApplyGroupProfileSwitch
EnemyList.CaptureActiveProfile = function()
  if type(EnemyListDB) == "table" then
    enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
  end
end

--- One-time: remove global keys and |clickBinds| from older EnemyList versions (keybind UI removed; use Clique).
local function enemyListClearLegacyAddonKeybinds()
  if type(EnemyListDB) ~= "table" or EnemyListDB._enemyListKeybindsPurge1854 then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local binds = EnemyListDB.clickBinds
  if type(binds) == "table" then
    for _, bind in ipairs(binds) do
      if type(bind) == "table" then
        local key = tostring(bind.key or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if key ~= "" and not key:find("BUTTON%d") then
          pcall(function() SetBinding(key, nil) end)
        end
      end
    end
  end
  for i = 1, 32 do
    local cmd = "CLICK EnemyListClickBind" .. i .. ":LeftButton"
    pcall(function()
      if GetBindingKey then
        local k1, k2 = GetBindingKey(cmd)
        if k1 and k1 ~= "" then
          SetBinding(k1, nil)
        end
        if k2 and k2 ~= "" then
          SetBinding(k2, nil)
        end
      end
    end)
  end
  if SaveBindings and GetCurrentBindingSet then
    pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  end
  EnemyListDB.clickBinds = nil
  EnemyListDB.spellName = nil
  EnemyListDB.spellName2 = nil
  EnemyListDB.spellName3 = nil
  EnemyListDB.spellTot1 = nil
  EnemyListDB.spellTot2 = nil
  EnemyListDB.spellTot3 = nil
  EnemyListDB._enemyListKeybindsPurge1854 = true
end

--- Saved vars must run after BAR_HEIGHT_* / FONT_PRESET_MAX exist (used for clamping).
local function initDB()
  if type(EnemyListDB) ~= "table" then
    EnemyListDB = {}
  end
  --- Per-character first-run wizard: absent key = new or legacy; legacy saves have at least one stored key.
  if EnemyListDB.setupWizardCompleted == nil then
    local hasSavedData = false
    for k in pairs(EnemyListDB) do
      if k ~= "setupWizardCompleted" and k ~= "combatLogLines" then
        hasSavedData = true
        break
      end
    end
    --- |true| = skip wizard (this character already had saved data); |false| = show first-time setup.
    EnemyListDB.setupWizardCompleted = hasSavedData
  end
  if EnemyListDB.maxEnemiesAggro == nil and EnemyListDB.maxEnemiesOther == nil and type(EnemyListDB.maxEnemiesShown) == "number" then
    local n = math.max(1, math.min(20, math.floor(EnemyListDB.maxEnemiesShown + 0.5)))
    EnemyListDB.maxEnemiesAggro = n
    EnemyListDB.maxEnemiesOther = n
  end
  for k, v in pairs(defaults) do
    if EnemyListDB[k] == nil then
      EnemyListDB[k] = v
    end
  end
  if type(EnemyListDB.width) == "number" then
    EnemyListDB.width = math.max(80, math.min(500, math.floor(EnemyListDB.width + 0.5)))
  end
  if type(EnemyListDB.maxEnemiesAggro) == "number" then
    EnemyListDB.maxEnemiesAggro = math.max(1, math.min(20, math.floor(EnemyListDB.maxEnemiesAggro + 0.5)))
  end
  if type(EnemyListDB.maxEnemiesOther) == "number" then
    EnemyListDB.maxEnemiesOther = math.max(1, math.min(20, math.floor(EnemyListDB.maxEnemiesOther + 0.5)))
  end
  if type(EnemyListDB.barHeight) == "number" then
    EnemyListDB.barHeight = math.max(BAR_HEIGHT_MIN, math.min(BAR_HEIGHT_MAX, math.floor(EnemyListDB.barHeight + 0.5)))
  end
  if type(EnemyListDB.fontPreset) == "number" then
    EnemyListDB.fontPreset = math.max(2, math.min(FONT_PRESET_MAX, math.floor(EnemyListDB.fontPreset + 0.5)))
  end
  if type(EnemyListDB.uiScale) == "number" then
    EnemyListDB.uiScale = math.max(0.5, math.min(1.5, EnemyListDB.uiScale))
  end
  if type(EnemyListDB.configWindowWidth) == "number" then
    EnemyListDB.configWindowWidth = math.max(CONFIG_RESIZE_MIN_W, math.min(CONFIG_RESIZE_MAX_W, math.floor(EnemyListDB.configWindowWidth + 0.5)))
  end
  if type(EnemyListDB.configWindowHeight) == "number" then
    EnemyListDB.configWindowHeight = math.max(CONFIG_RESIZE_MIN_H, math.min(CONFIG_RESIZE_MAX_H, math.floor(EnemyListDB.configWindowHeight + 0.5)))
  end
  if type(EnemyListDB.combatLogLines) ~= "table" then
    EnemyListDB.combatLogLines = {}
  end
  if type(EnemyListDB.combatLogMaxLines) == "number" then
    EnemyListDB.combatLogMaxLines = math.max(50, math.min(5000, math.floor(EnemyListDB.combatLogMaxLines + 0.5)))
  end
  if type(EnemyListDB.enemyInactivityFilterSec) == "number" then
    EnemyListDB.enemyInactivityFilterSec = math.max(ENEMY_INACTIVITY_FILTER_SEC_MIN, math.min(ENEMY_INACTIVITY_FILTER_SEC_MAX, math.floor(EnemyListDB.enemyInactivityFilterSec + 0.5)))
  end
  if type(EnemyListDB.partyFrameHealthBarHeight) == "number" then
    EnemyListDB.partyFrameHealthBarHeight = math.max(4, math.min(60, math.floor(EnemyListDB.partyFrameHealthBarHeight + 0.5)))
  end
  for _, colKey in ipairs({
    "partyFrameHpDeficitTextR", "partyFrameHpDeficitTextG", "partyFrameHpDeficitTextB",
    "partyFrameHpDeficitBorderR", "partyFrameHpDeficitBorderG", "partyFrameHpDeficitBorderB",
  }) do
    if type(EnemyListDB[colKey]) == "number" then
      EnemyListDB[colKey] = math.max(0, math.min(1, EnemyListDB[colKey]))
    end
  end
  if type(EnemyListDB.partyFrameHpDeficitFontScale) == "number" then
    EnemyListDB.partyFrameHpDeficitFontScale = math.max(0.5, math.min(2.0, EnemyListDB.partyFrameHpDeficitFontScale))
  end
  for _, colKey in ipairs({
    "partyFrameAggroCountTextR", "partyFrameAggroCountTextG", "partyFrameAggroCountTextB",
  }) do
    if type(EnemyListDB[colKey]) == "number" then
      EnemyListDB[colKey] = math.max(0, math.min(1, EnemyListDB[colKey]))
    end
  end
  if type(EnemyListDB.partyFrameAggroCountFontScale) == "number" then
    EnemyListDB.partyFrameAggroCountFontScale = math.max(0.5, math.min(2.0, EnemyListDB.partyFrameAggroCountFontScale))
  end
  EnemyListDB.minimapButtonHidden = EnemyListDB.minimapButtonHidden == true
  if type(EnemyList.ApplyNameplateRangePreference) == "function" then
    EnemyList.ApplyNameplateRangePreference()
  end
  if type(EnemyList.IsTestModeOn) == "function" then
    EnemyListDB.testMode = EnemyList.IsTestModeOn()
  end
  enemyListClearLegacyAddonKeybinds()
  initAccountDB()
end

--- Config uses FULLSCREEN_DIALOG; default ColorPicker sits lower — bump picker above it.
local function enemyListRaiseColorPickerFrame()
  local f = ColorPickerFrame
  if not f or not f.SetFrameStrata then
    return
  end
  f:SetFrameStrata("TOOLTIP")
  if f.SetToplevel then
    f:SetToplevel(true)
  end
  f:Raise()
  local osf = _G.OpacitySliderFrame
  if osf and osf.SetFrameStrata and osf:IsShown() then
    osf:SetFrameStrata("TOOLTIP")
    osf:Raise()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if f:IsShown() then
        f:SetFrameStrata("TOOLTIP")
        f:Raise()
        local o2 = _G.OpacitySliderFrame
        if o2 and o2:IsShown() and o2.SetFrameStrata then
          o2:SetFrameStrata("TOOLTIP")
          o2:Raise()
        end
      end
    end)
  end
end

--- Opens the client color picker; calls onRgb(r, g, b) while adjusting and on cancel (restored).
local function enemyListOpenRgbColorPicker(r0, g0, b0, onRgb)
  if type(onRgb) ~= "function" or not ColorPickerFrame then
    return
  end
  local sR, sG, sB = r0, g0, b0
  local function apply(r, g, b)
    onRgb(r, g, b)
  end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r0,
      g = g0,
      b = b0,
      hasOpacity = false,
      swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply(r, g, b)
      end,
      cancelFunc = function()
        apply(sR, sG, sB)
      end,
    })
    enemyListRaiseColorPickerFrame()
    return
  end
  ColorPickerFrame.previousValues = { r0, g0, b0 }
  ColorPickerFrame.cancelFunc = function()
    local pr, pg, pb = unpack(ColorPickerFrame.previousValues)
    ColorPickerFrame:SetColorRGB(pr, pg, pb)
    apply(pr, pg, pb)
  end
  ColorPickerFrame.func = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    apply(r, g, b)
  end
  ColorPickerFrame.opacity = 1
  ColorPickerFrame:Show()
  enemyListRaiseColorPickerFrame()
end

local function elDebugEnabled()
  return type(EnemyListDB) == "table" and EnemyListDB.debug and true or false
end

local function elInCombatLockdown()
  return InCombatLockdown and InCombatLockdown()
end

--- Plain chat lines (no |c color tokens) so you can copy from the chat log without broken markup.
local function elChatCopyLine(msg)
  local s = tostring(msg or ""):gsub("|", "/")
  print("[EnemyList] " .. s)
end

local function elDebug(msg, ...)
  if not elDebugEnabled() then
    return
  end
  local ok, s = pcall(string.format, msg, ...)
  if not ok then
    s = tostring(msg)
  end
  elChatCopyLine("DEBUG " .. tostring(s))
end

local function elPrintErr(phase, err)
  local e = err and tostring(err) or "unknown error"
  e = e:gsub("|", "/")
  local ph = tostring(phase):gsub("|", "/")
  print("|cffff4444[EnemyList ERROR]|r " .. ph .. ": " .. e)
  elChatCopyLine("ERROR " .. ph .. ": " .. e)
  if elDebugEnabled() and debugstack then
    pcall(function()
      local st = debugstack(3, 12, 0) or ""
      for line in string.gmatch(st, "[^\n]+") do
        elChatCopyLine("TRACE " .. line)
      end
    end)
  end
  if type(EnemyList.AppendCombatLogLine) == "function" then
    EnemyList.AppendCombatLogLine("[EnemyList] ERROR " .. ph .. ": " .. e)
  end
end

local function elSafe(phase, fn, ...)
  local ok, a, b = pcall(fn, ...)
  if not ok then
    elPrintErr(phase, a)
    return false
  end
  return true, a, b
end

--- Flat dark surface + hairline border (Material-style card on dark UI).
local function applyMaterialSurface(frame, opts)
  opts = opts or {}
  if not frame or not frame.SetBackdrop then
    return false
  end
  local inset = opts.inset or 1
  --- Retail-style clients error on SetBackdrop without BackdropTemplate; do not abort callers.
  return pcall(function()
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false,
      edgeSize = 1,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame:SetBackdropColor(opts.bgR or 0.122, opts.bgG or 0.125, opts.bgB or 0.131, opts.bgA or 0.97)
    frame:SetBackdropBorderColor(opts.borderR or 1, opts.borderG or 1, opts.borderB or 1, opts.borderA or 0.11)
  end)
end
function applyMainBackground()
  local f = mainScaleBackdrop or mainScaleRoot or main
  if not f or not f.SetBackdrop then
    return
  end
  if EnemyListDB and EnemyListDB.showBackground == false then
    pcall(function()
      f:SetBackdropColor(0, 0, 0, 0)
      f:SetBackdropBorderColor(0, 0, 0, 0)
    end)
  else
    pcall(function()
      f:SetBackdropColor(0.122, 0.125, 0.131, 0.97)
      f:SetBackdropBorderColor(1, 1, 1, 0.11)
    end)
  end
end

--- 1 = smallest … 8 = largest (readable UI fonts only; avoids blocky number fonts such as NumberFontNormalSmall).
local fonts = {}
do
  local names = {
    "GameFontDisableSmall",
    "GameFontHighlightSmall",
    "GameFontNormalSmall",
    "GameFontNormal",
    "GameFontNormalLarge",
    "GameFontHighlightLarge",
    "QuestFontNormalLarge",
    "QuestTitleFont",
  }
  local last = _G.GameFontNormalSmall or _G.GameFontNormal
  for i, n in ipairs(names) do
    local f = _G[n]
    if f then
      last = f
    end
    fonts[i] = last
  end
end

local function fontForPreset(p)
  local i = math.min(FONT_PRESET_MAX, math.max(1, math.floor(tonumber(p) or 3)))
  return fonts[i] or fonts[3]
end

local function fontMetaForPreset(p)
  local i = math.min(FONT_PRESET_MAX, math.max(1, math.floor(tonumber(p) or 3)))
  local mi = math.max(1, i - 1)
  return fonts[mi] or fonts[1]
end

local function relIsUIParent(rel)
  return rel == UIParent or (rel and rel.GetName and rel:GetName() == "UIParent")
end

--- After |StopMovingOrSizing| on a scaled frame, |GetLeft|/|GetTop| can disagree with |SetPoint| offsets.
--- Normalize to a single |TOPLEFT|→|UIParent TOPLEFT| using |GetPoint(1)| when possible.
local function reanchorFrameTopLeftUIParent(frame)
  if not frame then
    return
  end
  local n = frame.GetNumPoints and frame:GetNumPoints() or 0
  if n >= 1 then
    local pt, rel, relPt, xOfs, yOfs = frame:GetPoint(1)
    if pt == "TOPLEFT" and relIsUIParent(rel) and relPt == "TOPLEFT" and type(xOfs) == "number" and type(yOfs) == "number" then
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOfs, yOfs)
      return
    end
  end
  local left = frame:GetLeft()
  local top = frame:GetTop()
  local parentTop = UIParent:GetTop() or 0
  if left and top then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, -(parentTop - top))
  end
end

local function saveFrameTopLeftToDB(frame, keyX, keyY)
  if not frame or type(EnemyListDB) ~= "table" then
    return
  end
  local n = frame.GetNumPoints and frame:GetNumPoints() or 0
  if n >= 1 then
    local pt, rel, relPt, xOfs, yOfs = frame:GetPoint(1)
    if pt == "TOPLEFT" and relIsUIParent(rel) and relPt == "TOPLEFT" and type(xOfs) == "number" and type(yOfs) == "number" then
      EnemyListDB[keyX] = xOfs
      EnemyListDB[keyY] = yOfs
      return
    end
  end
  local left = frame:GetLeft()
  local top = frame:GetTop()
  local parentTop = UIParent:GetTop() or 0
  if left and top then
    EnemyListDB[keyX] = left
    EnemyListDB[keyY] = -(parentTop - top)
  end
end

--- Scale applies to |mainScaleRoot| only; |main| stays at scale 1 so |TOPLEFT| matches drag/save.
local function applyUiScale()
  if not main or not mainScaleRoot or not mainScaleRoot.SetScale then
    return
  end
  if elInCombatLockdown() then
    return
  end
  local s = tonumber(EnemyListDB.uiScale) or 1
  s = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, s))
  EnemyListDB.uiScale = s
  local W = main:GetWidth()
  local H = main:GetHeight()
  if type(W) ~= "number" or type(H) ~= "number" or W <= 0 or H <= 0 then
    return
  end
  mainScaleRoot:SetSize(W, H)
  mainScaleRoot:ClearAllPoints()
  --- Pivot ~ center: keep the scaled surface's top-left aligned with |main|'s top-left.
  local k = (1 - s) * 0.5
  mainScaleRoot:SetPoint("TOPLEFT", main, "TOPLEFT", -k * W, -k * H)
  mainScaleRoot:SetScale(s)
end

local function safeFontHeight(fontObj, fallback)
  if not fontObj or not fontObj.GetHeight then
    return fallback
  end
  local ok, h = pcall(fontObj.GetHeight, fontObj)
  if ok and type(h) == "number" and h > 0 then
    return h
  end
  return fallback
end

--- Row height = sum of visible bar heights.
local function effectiveRowHeight()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local hpH = math.max(6, math.min(40, tonumber(db.healthBarHeight) or defaults.healthBarHeight))
  local threatH = (db.showThreatBar ~= false) and math.max(3, math.min(20, tonumber(db.threatBarHeight) or defaults.threatBarHeight)) or 0
  local castH = (db.showCastBar ~= false) and math.max(3, math.min(20, tonumber(db.castBarHeight) or defaults.castBarHeight)) or 0
  local runnerH = 0
  if db.showRunnerUpBars == true and db.showThreatBar ~= false then
    runnerH = math.max(2, math.min(16, tonumber(db.runnerUpBarHeight) or defaults.runnerUpBarHeight))
  end
  local secondH = 0
  if db.showSecondOnThreatBar ~= false and db.showThreatBar ~= false then
    secondH = math.max(2, math.min(16, tonumber(db.runnerUpBarHeight) or defaults.runnerUpBarHeight)) + 1
  end
  return hpH + threatH + castH + secondH + runnerH
end

local function savePosition()
  if not main then
    return
  end
  reanchorFrameTopLeftUIParent(main)
  saveFrameTopLeftToDB(main, "x", "y")
  --- Width is now bar width, not frame width. Don't overwrite from frame size.
end

local function hideBarRow(r, ooc)
  if not r then
    return
  end
  if ooc then
    local par = r:GetParent()
    if par and r.SetFrameLevel then
      r:SetFrameLevel((par:GetFrameLevel() or 0) + 2)
    end
    if r.pctBar then r.pctBar:Hide() end
    if r._elSecondThreatBar then r._elSecondThreatBar:Hide() end
    if r.castBar then r.castBar:Hide() end
    if r.targetHighlight then for _, tex in ipairs(r.targetHighlight) do tex:Hide() end end
    if r.aggroFlash then r.aggroFlash:Hide() end
    if r.raidMarkerIcon then r.raidMarkerIcon:Hide() end
    r:SetAlpha(1)
    r:Hide()
    return
  end
  if r.pctBar then r.pctBar:Hide() end
  if r._elSecondThreatBar then r._elSecondThreatBar:Hide() end
  if r.castBar then r.castBar:Hide() end
  if r.targetHighlight then for _, tex in ipairs(r.targetHighlight) do tex:Hide() end end
  if r.aggroFlash then r.aggroFlash:Hide() end
  if r.raidMarkerIcon then r.raidMarkerIcon:Hide() end
  r:Hide()
end


local function createBarRow(parent, frameName)
  local r = CreateFrame("Frame", frameName, parent)
  --- Click-to-target is insecure: the |OnMouseUp| handler at the bottom of this function calls
  --- |TargetUnit| on left-click. We used to layer a SecureActionButtonTemplate child here so the
  --- click worked in combat, but that tainted the entire list hierarchy — every ancestor (|main|,
  --- |mainScaleRoot|, column frames) became protected, and routine Show / Hide / SetSize calls
  --- during a pull would trip "ADDON BLOCKED". The cost of giving that up is minor: |TargetUnit|
  --- still works for hostile units on Classic / Anniversary; on Retail it's blocked in combat,
  --- which is acceptable since Retail users can bind Clique-style click-casting instead.

  r.threatBg = r:CreateTexture(nil, "BACKGROUND", nil, -8)
  r.threatBg:SetAllPoints()
  pcall(function()
    r.threatBg:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
  end)

  --- Border removed; bars fill the full row now.

  r.pctBar = CreateFrame("StatusBar", nil, r)
  r.pctBar:SetFrameLevel((r:GetFrameLevel() or 0) + 3)
  r.pctBar:SetMinMaxValues(0, 100)
  r.pctBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  r.pctBar.threatFs = r.pctBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.pctBar.threatFs:SetPoint("CENTER", r.pctBar, "CENTER", 0, 0)
  r.pctBar.threatFs:SetJustifyH("CENTER")
  r.pctBar.threatFs:SetShadowOffset(1, -1)
  r.pctBar.threatFs:SetShadowColor(0, 0, 0, 1)
  r.pctBar.threatFs:SetTextColor(1, 1, 1, 0.9)
  local barBg = r.pctBar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetColorTexture(0, 0, 0, 0.5)

  --- Who is 2nd on the mob’s threat list — one thin bar directly under the player’s threat bar.
  r._elSecondThreatBar = CreateFrame("StatusBar", nil, r)
  r._elSecondThreatBar:SetFrameLevel((r:GetFrameLevel() or 0) + 3)
  r._elSecondThreatBar:SetMinMaxValues(0, 100)
  r._elSecondThreatBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  r._elSecondThreatBar:SetStatusBarColor(0.35, 0.55, 0.95, 0.9)
  local stBg = r._elSecondThreatBar:CreateTexture(nil, "BACKGROUND")
  stBg:SetAllPoints()
  stBg:SetColorTexture(0, 0, 0, 0.4)
  r._elSecondThreatBar.nameFs = r._elSecondThreatBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r._elSecondThreatBar.nameFs:SetPoint("LEFT", r._elSecondThreatBar, "LEFT", 3, 0)
  r._elSecondThreatBar.nameFs:SetJustifyH("LEFT")
  r._elSecondThreatBar.nameFs:SetWordWrap(false)
  r._elSecondThreatBar.nameFs:SetShadowOffset(1, -1)
  r._elSecondThreatBar.nameFs:SetShadowColor(0, 0, 0, 1)
  r._elSecondThreatBar.nameFs:SetTextColor(1, 1, 1, 1)
  r._elSecondThreatBar.pctFs = r._elSecondThreatBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r._elSecondThreatBar.pctFs:SetPoint("RIGHT", r._elSecondThreatBar, "RIGHT", -3, 0)
  r._elSecondThreatBar.pctFs:SetJustifyH("RIGHT")
  r._elSecondThreatBar.pctFs:SetWordWrap(false)
  r._elSecondThreatBar.pctFs:SetShadowOffset(1, -1)
  r._elSecondThreatBar.pctFs:SetShadowColor(0, 0, 0, 1)
  r._elSecondThreatBar.pctFs:SetTextColor(1, 1, 1, 1)
  r._elSecondThreatBar:Hide()

  --- Health bar: fills from left, overlays the threat background.
  r.hpBar = CreateFrame("StatusBar", nil, r)
  r.hpBar:SetFrameLevel((r:GetFrameLevel() or 0) + 1)
  r.hpBar:SetMinMaxValues(0, 1)
  r.hpBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  do local rr, gg, bb = _EL.enemyHpBarRGB(); r.hpBar:SetStatusBarColor(rr, gg, bb, 0.4) end
  --- hpBar position set in applyBarRow; don't SetAllPoints here.
  local hpBg = r.hpBar:CreateTexture(nil, "BACKGROUND")
  hpBg:SetAllPoints()
  hpBg:SetColorTexture(0, 0, 0, 0.3)
  r._hpBg = hpBg

  --- Per-row ToT indicator: non-secure square that shows who this enemy is targeting.
  --- Only visible when this row's enemy is the player's current target.
  r.totIndicator = CreateFrame("Frame", nil, r)
  r.totIndicator:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 0)
  r.totIndicator:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
  r.totIndicator:SetFrameLevel((r:GetFrameLevel() or 0) + 4)
  r.totIndicator:EnableMouse(false) --- Don't consume clicks; let secure frames underneath handle them.
  r.totIndicator:Hide()
  r.totIndicator.bg = r.totIndicator:CreateTexture(nil, "BACKGROUND")
  r.totIndicator.bg:SetAllPoints()
  r.totIndicator.bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
  r.totIndicator.nameFs = r.totIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.totIndicator.nameFs:SetPoint("CENTER")
  r.totIndicator.nameFs:SetJustifyH("CENTER")
  r.totIndicator.nameFs:SetWordWrap(true)
  r.totIndicator.nameFs:SetShadowOffset(1, -1)
  r.totIndicator.nameFs:SetShadowColor(0, 0, 0, 1)
  --- Color-coded border textures for party matching (Feature: party frames).
  local totBw = 2
  r.totIndicator.borderTop = r.totIndicator:CreateTexture(nil, "OVERLAY", nil, 7)
  r.totIndicator.borderTop:SetPoint("TOPLEFT", r.totIndicator, "TOPLEFT", 0, 0)
  r.totIndicator.borderTop:SetPoint("TOPRIGHT", r.totIndicator, "TOPRIGHT", 0, 0)
  r.totIndicator.borderTop:SetHeight(totBw)
  r.totIndicator.borderBot = r.totIndicator:CreateTexture(nil, "OVERLAY", nil, 7)
  r.totIndicator.borderBot:SetPoint("BOTTOMLEFT", r.totIndicator, "BOTTOMLEFT", 0, 0)
  r.totIndicator.borderBot:SetPoint("BOTTOMRIGHT", r.totIndicator, "BOTTOMRIGHT", 0, 0)
  r.totIndicator.borderBot:SetHeight(totBw)
  r.totIndicator.borderLeft = r.totIndicator:CreateTexture(nil, "OVERLAY", nil, 7)
  r.totIndicator.borderLeft:SetPoint("TOPLEFT", r.totIndicator, "TOPLEFT", 0, 0)
  r.totIndicator.borderLeft:SetPoint("BOTTOMLEFT", r.totIndicator, "BOTTOMLEFT", 0, 0)
  r.totIndicator.borderLeft:SetWidth(totBw)
  r.totIndicator.borderRight = r.totIndicator:CreateTexture(nil, "OVERLAY", nil, 7)
  r.totIndicator.borderRight:SetPoint("TOPRIGHT", r.totIndicator, "TOPRIGHT", 0, 0)
  r.totIndicator.borderRight:SetPoint("BOTTOMRIGHT", r.totIndicator, "BOTTOMRIGHT", 0, 0)
  r.totIndicator.borderRight:SetWidth(totBw)

  --- Feature 1: target highlight border — on textOverlay so it renders above all bars.
  --- (Created after textOverlay below.)

  --- Feature 2: aggro swap flash overlay
  r.aggroFlash = r:CreateTexture(nil, "OVERLAY", nil, 6)
  r.aggroFlash:SetAllPoints()
  r.aggroFlash:SetColorTexture(1, 0, 0, 0.35)
  r.aggroFlash:Hide()

  --- Feature 5: cast bar
  r.castBar = CreateFrame("StatusBar", nil, r)
  r.castBar:SetFrameLevel((r:GetFrameLevel() or 0) + 3)
  r.castBar:SetMinMaxValues(0, 1)
  r.castBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  do local rr, gg, bb = _EL.enemyCastBarRGB(); r.castBar:SetStatusBarColor(rr, gg, bb, 0.85) end
  r.castBar:SetHeight(4)
  r.castBar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 3, 0)
  r.castBar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -3, 0)
  local castBg = r.castBar:CreateTexture(nil, "BACKGROUND")
  castBg:SetAllPoints()
  castBg:SetColorTexture(0.1, 0.1, 0.2, 0.7)
  r.castBar.nameFs = r.castBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.castBar.nameFs:SetPoint("LEFT", r.castBar, "LEFT", 2, 0)
  r.castBar.nameFs:SetJustifyH("LEFT")
  r.castBar.nameFs:SetTextColor(1, 1, 1, 0.9)
  r.castBar:Hide()

  --- Runner-up threat bars: up to 5 mini StatusBars showing the top non-tanking threat holders.
  --- Layout happens in |applyBarRow| once the row's width is known; bars stack vertically (one per
  --- line) with the player name overlaid on the bar and the percentage right-aligned.
  r._elRunnerUpRow = CreateFrame("Frame", nil, r)
  r._elRunnerUpRow:SetFrameLevel((r:GetFrameLevel() or 0) + 3)
  r._elRunnerUpRow:Hide()
  r._elRunnerUpBars = {}
  for i = 1, 5 do
    local mb = CreateFrame("StatusBar", nil, r._elRunnerUpRow)
    mb:SetMinMaxValues(0, 100)
    mb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mb:SetStatusBarColor(0.3, 0.9, 0.3, 0.9)
    local mbBg = mb:CreateTexture(nil, "BACKGROUND")
    mbBg:SetAllPoints()
    mbBg:SetColorTexture(0, 0, 0, 0.4)
    --- Name FontString (left-aligned on the bar).
    mb.nameFs = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mb.nameFs:SetPoint("LEFT", mb, "LEFT", 3, 0)
    mb.nameFs:SetJustifyH("LEFT")
    mb.nameFs:SetWordWrap(false)
    mb.nameFs:SetShadowOffset(1, -1)
    mb.nameFs:SetShadowColor(0, 0, 0, 1)
    mb.nameFs:SetTextColor(1, 1, 1, 1)
    --- Percentage FontString (right-aligned on the bar).
    mb.pctFs = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mb.pctFs:SetPoint("RIGHT", mb, "RIGHT", -3, 0)
    mb.pctFs:SetJustifyH("RIGHT")
    mb.pctFs:SetWordWrap(false)
    mb.pctFs:SetShadowOffset(1, -1)
    mb.pctFs:SetShadowColor(0, 0, 0, 1)
    mb.pctFs:SetTextColor(1, 1, 1, 1)
    mb:Hide()
    r._elRunnerUpBars[i] = mb
  end

  --- Text overlay: sits above all bars so text is never hidden by health/threat fills.
  r.textOverlay = CreateFrame("Frame", nil, r)
  r.textOverlay:SetAllPoints()
  r.textOverlay:SetFrameLevel((r:GetFrameLevel() or 0) + 5)
  r.textOverlay:EnableMouse(false)  --- Don't block clicks from reaching secure frames above.

  --- Raid marker: on textOverlay so it's above all bars. Positioned top-left corner.
  r.raidMarkerIcon = r.textOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
  r.raidMarkerIcon:SetSize(14, 14)
  r.raidMarkerIcon:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -2)
  r.raidMarkerIcon:Hide()

  --- Target highlight border: on textOverlay so it renders above all bars.
  r.targetHighlight = {}
  local hlColor = { 1, 0.82, 0, 0.9 }
  local hlThick = 2
  for _, info in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, hlThick },
    { "BOTTOMLEFT", "BOTTOMRIGHT", nil, hlThick },
    { "TOPLEFT", "BOTTOMLEFT", hlThick, nil },
    { "TOPRIGHT", "BOTTOMRIGHT", hlThick, nil },
  }) do
    local hl = r.textOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    hl:SetColorTexture(hlColor[1], hlColor[2], hlColor[3], hlColor[4])
    hl:SetPoint(info[1], r, info[1], 0, 0)
    hl:SetPoint(info[2], r, info[2], 0, 0)
    if info[3] then hl:SetWidth(info[3]) end
    if info[4] then hl:SetHeight(info[4]) end
    hl:Hide()
    r.targetHighlight[#r.targetHighlight + 1] = hl
  end

  r.nameFs = r.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.nameFs:SetJustifyH("LEFT")
  r.nameFs:SetWordWrap(false)
  r.nameFs:SetShadowOffset(1, -1)
  r.nameFs:SetShadowColor(0, 0, 0, 1)

  r.metaFs = r.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.metaFs:SetJustifyH("LEFT")
  r.metaFs:SetWordWrap(false)
  r.metaFs:SetShadowOffset(1, -1)
  r.metaFs:SetShadowColor(0, 0, 0, 1)

  r:SetScript("OnEnter", function(self)
    --- Feature 4: nameplate highlight on hover
    if self._elUnit and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
      pcall(function()
        local np = C_NamePlate.GetNamePlateForUnit(self._elUnit)
        if np then
          if not self._elNpGlow then
            self._elNpGlow = np:CreateTexture(nil, "OVERLAY")
            self._elNpGlow:SetAllPoints()
            self._elNpGlow:SetColorTexture(1, 1, 0.4, 0.3)
          else
            self._elNpGlow:SetParent(np)
            self._elNpGlow:SetAllPoints()
          end
          self._elNpGlow:Show()
        end
      end)
    end
  end)
  r:SetScript("OnLeave", function(self)
    --- Feature 4: clear nameplate highlight
    if self._elNpGlow then
      self._elNpGlow:Hide()
    end
  end)

  --- Feature 9: right-click context menu + left-click insecure targeting.
  r:EnableMouse(true)
  r:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      --- Insecure target via |RunMacroText|. |TargetUnit| is a protected function and even inside
      --- |pcall| it emits "ADDON FORBIDDEN" in combat — the macro path is the only truly safe insecure
      --- targeting mechanism, and even it is blocked in combat. Out of combat both paths work. In
      --- combat, we no-op silently; users who want combat click-targeting should bind via Clique.
      if InCombatLockdown() then return end
      local u = self._elUnit
      local nm = (type(self._elName) == "string" and self._elName ~= "") and self._elName or nil
      if u and UnitExists(u) then
        nm = nm or UnitName(u)
      end
      if nm then
        pcall(function() RunMacroText("/target " .. nm) end)
      end
      return
    end
    if button ~= "RightButton" then return end
    local unit = self._elUnit
    if not unit or not UnitExists(unit) then return end
    local menuList = {}
    --- Mark submenu
    local markers = {
      { text = "Skull", id = 8 }, { text = "Cross", id = 7 },
      { text = "Square", id = 6 }, { text = "Moon", id = 5 },
      { text = "Triangle", id = 4 }, { text = "Diamond", id = 3 },
      { text = "Circle", id = 2 }, { text = "Star", id = 1 },
      { text = "Clear", id = 0 },
    }
    for _, m in ipairs(markers) do
      menuList[#menuList + 1] = {
        text = "Mark: " .. m.text,
        func = function() pcall(SetRaidTarget, unit, m.id) end,
        notCheckable = true,
      }
    end
    menuList[#menuList + 1] = {
      text = "Focus",
      func = function()
        if FocusUnit then
          pcall(FocusUnit, unit)
        else
          pcall(function() RunMacroText("/focus " .. (UnitName(unit) or "")) end)
        end
      end,
      notCheckable = true,
    }
    local announceUnit = unit
    menuList[#menuList + 1] = {
      text = "Announce in /say",
      func = function()
        pcall(function()
          local nm = UnitName(announceUnit) or "?"
          local hp = UnitHealth(announceUnit) or 0
          local hpMax = UnitHealthMax(announceUnit) or 1
          local pct = hpMax > 0 and math.floor(hp / hpMax * 100 + 0.5) or 0
          SendChatMessage(string.format("[EnemyList] %s - %d%% HP", nm, pct), "SAY")
        end)
      end,
      notCheckable = true,
    }
    --- Use EasyMenu if available, else UIDropDownMenu
    if not self._elContextMenu then
      self._elContextMenu = CreateFrame("Frame", "EnemyListCtxMenu" .. tostring(self):gsub("[^%w]", ""), UIParent, "UIDropDownMenuTemplate")
    end
    if EasyMenu then
      EasyMenu(menuList, self._elContextMenu, "cursor", 0, 0, "MENU")
    end
  end)

  return r
end

--- Grid mode: square cells with vertical aggro (left) + hp (right) bars and a cast bar below.
--- Border color = aggro status (red=aggro, white=not aggro). No name text on cell.
local function createGridCell(parent, cellName)
  local c = CreateFrame("Frame", cellName, parent)
  --- No secure overlay here — see |createBarRow| for the rationale. The grid layout code installs
  --- an |OnMouseUp| handler per-cell that handles both left-click (target the mob) and right-click
  --- (target-of-target) via insecure |TargetUnit|.

  --- Background
  c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -8)
  c.bg:SetAllPoints()
  c.bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)

  --- Aggro status border (4 edges, colored red or white).
  c.aggroBorder = {}
  local bThick = 2
  for _, info in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, bThick },     -- top
    { "BOTTOMLEFT", "BOTTOMRIGHT", nil, bThick }, -- bottom
    { "TOPLEFT", "BOTTOMLEFT", bThick, nil },    -- left
    { "TOPRIGHT", "BOTTOMRIGHT", bThick, nil },  -- right
  }) do
    local edge = c:CreateTexture(nil, "OVERLAY", nil, 6)
    edge:SetColorTexture(1, 1, 1, 0.8)
    edge:SetPoint(info[1], c, info[1], 0, 0)
    edge:SetPoint(info[2], c, info[2], 0, 0)
    if info[3] then edge:SetWidth(info[3]) end
    if info[4] then edge:SetHeight(info[4]) end
    c.aggroBorder[#c.aggroBorder + 1] = edge
  end

  --- Left half: aggro bar (fills from bottom up)
  c.aggroBar = CreateFrame("StatusBar", nil, c)
  c.aggroBar:SetFrameLevel((c:GetFrameLevel() or 0) + 1)
  c.aggroBar:SetOrientation("VERTICAL")
  c.aggroBar:SetMinMaxValues(0, 100)
  c.aggroBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  do local rr, gg, bb = _EL.enemyAggroBarRGB(); c.aggroBar:SetStatusBarColor(rr, gg, bb, 0.9) end
  local aggroBg = c.aggroBar:CreateTexture(nil, "BACKGROUND")
  aggroBg:SetAllPoints()
  aggroBg:SetColorTexture(0.3, 0.05, 0.05, 0.6)
  c._aggroBg = aggroBg

  --- Right half: hp bar (fills from bottom up)
  c.hpBar = CreateFrame("StatusBar", nil, c)
  c.hpBar:SetFrameLevel((c:GetFrameLevel() or 0) + 1)
  c.hpBar:SetOrientation("VERTICAL")
  c.hpBar:SetMinMaxValues(0, 1)
  c.hpBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  do local rr, gg, bb = _EL.enemyHpBarRGB(); c.hpBar:SetStatusBarColor(rr, gg, bb, 0.9) end
  local hpBg = c.hpBar:CreateTexture(nil, "BACKGROUND")
  hpBg:SetAllPoints()
  hpBg:SetColorTexture(0.05, 0.2, 0.05, 0.6)
  c._hpBg = hpBg

  --- Cast bar at the bottom
  c.castBar = CreateFrame("StatusBar", nil, c)
  c.castBar:SetFrameLevel((c:GetFrameLevel() or 0) + 2)
  c.castBar:SetMinMaxValues(0, 1)
  c.castBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  do local rr, gg, bb = _EL.enemyCastBarRGB(); c.castBar:SetStatusBarColor(rr, gg, bb, 1.0) end
  local castBg = c.castBar:CreateTexture(nil, "BACKGROUND")
  castBg:SetAllPoints()
  castBg:SetColorTexture(0, 0, 0, 0.5)
  c.castBar.nameFs = c.castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.castBar.nameFs:SetAllPoints()
  c.castBar.nameFs:SetJustifyH("CENTER")
  c.castBar.nameFs:SetTextColor(1, 1, 1)
  c.castBar.nameFs:SetShadowOffset(1, -1)
  c.castBar.nameFs:SetShadowColor(0, 0, 0, 1)
  c.castBar:Hide()

  --- Text overlay (above bars)
  c.textOverlay = CreateFrame("Frame", nil, c)
  c.textOverlay:SetAllPoints()
  c.textOverlay:SetFrameLevel((c:GetFrameLevel() or 0) + 5)

  --- Aggro value text (centered on left bar)
  c.aggroFs = c.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.aggroFs:SetJustifyH("CENTER")
  c.aggroFs:SetTextColor(1, 1, 1)
  c.aggroFs:SetShadowOffset(1, -1)
  c.aggroFs:SetShadowColor(0, 0, 0, 1)

  --- HP value text (centered on right bar)
  c.hpFs = c.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.hpFs:SetJustifyH("CENTER")
  c.hpFs:SetTextColor(1, 1, 1)
  c.hpFs:SetShadowOffset(1, -1)
  c.hpFs:SetShadowColor(0, 0, 0, 1)

  --- Raid marker (centered)
  c.raidMarkerIcon = c.textOverlay:CreateTexture(nil, "OVERLAY", nil, 5)
  c.raidMarkerIcon:SetSize(12, 12)
  c.raidMarkerIcon:Hide()

  --- Target highlight (bright gold border, thicker, on top of aggro border)
  c.targetHighlight = {}
  local hlColor = { 1, 0.82, 0, 1.0 }
  local hlThick = 3
  for _, info in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, hlThick },
    { "BOTTOMLEFT", "BOTTOMRIGHT", nil, hlThick },
    { "TOPLEFT", "BOTTOMLEFT", hlThick, nil },
    { "TOPRIGHT", "BOTTOMRIGHT", hlThick, nil },
  }) do
    local hl = c:CreateTexture(nil, "OVERLAY", nil, 7)
    hl:SetColorTexture(hlColor[1], hlColor[2], hlColor[3], hlColor[4])
    hl:SetPoint(info[1], c, info[1], 0, 0)
    hl:SetPoint(info[2], c, info[2], 0, 0)
    if info[3] then hl:SetWidth(info[3]) end
    if info[4] then hl:SetHeight(info[4]) end
    hl:Hide()
    c.targetHighlight[#c.targetHighlight + 1] = hl
  end

  c:EnableMouse(true)
  return c
end

--- Get the base font file path (cached).
local _gridFontFile
local function getGridFontFile()
  if _gridFontFile then return _gridFontFile end
  local base = _G.GameFontNormalSmall or _G.GameFontNormal
  if base and base.GetFont then
    local file = base:GetFont()
    if file then _gridFontFile = file end
  end
  if not _gridFontFile then _gridFontFile = "Fonts\\FRIZQT__.TTF" end
  return _gridFontFile
end

--- Apply a pixel-sized font directly to a FontString for the given cell size.
local function applyGridFont(fs, cellSize)
  if not fs then
    return
  end
  local sz = math.max(6, math.floor(cellSize * 0.12))
  local file = getGridFontFile()
  if fs._elGridFontSize == sz and fs._elGridFontFile == file then
    return
  end
  local ok = pcall(function()
    fs:SetFont(file, sz, "OUTLINE")
  end)
  if ok then
    fs._elGridFontSize = sz
    fs._elGridFontFile = file
  end
end

local function applyGridCell(c, entry, cellSize)
  local castH = math.max(8, math.floor(cellSize * 0.15))
  local pad = 3
  local barH = cellSize - castH - pad * 2
  local halfW = math.floor((cellSize - pad * 2) / 2)

  c:SetSize(cellSize, cellSize)

  --- Stash unit + name on the cell so the layout-installed OnMouseUp handler can target on click.
  c._elUnit = entry and entry.unit or nil
  c._elName = entry and entry.name or nil

  --- Scale font to fit cell.
  applyGridFont(c.aggroFs, cellSize)
  applyGridFont(c.hpFs, cellSize)
  if c.castBar and c.castBar.nameFs then
    applyGridFont(c.castBar.nameFs, cellSize)
  end

  local userOpacity = (type(EnemyListDB) == "table" and tonumber(EnemyListDB.barOpacity)) or defaults.barOpacity

  --- Position bars.
  c.aggroBar:ClearAllPoints()
  c.aggroBar:SetPoint("TOPLEFT", c, "TOPLEFT", pad, -pad)
  c.aggroBar:SetSize(halfW, barH)

  c.hpBar:ClearAllPoints()
  c.hpBar:SetPoint("TOPRIGHT", c, "TOPRIGHT", -pad, -pad)
  c.hpBar:SetSize(halfW, barH)

  c.castBar:ClearAllPoints()
  c.castBar:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", pad, pad)
  c.castBar:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -pad, pad)
  c.castBar:SetHeight(castH)

  --- Aggro value.
  local ti = entry.threatInfo
  local threatPct = ti and ti.threatPct or 0
  local threatVal = ti and ti.threatValue or nil
  c.aggroBar:SetValue(math.min(100, threatPct))
  c.aggroFs:ClearAllPoints()
  c.aggroFs:SetPoint("CENTER", c.aggroBar, "CENTER", 0, 0)
  c.aggroFs:SetWidth(0)
  --- Compact threat text for grid: no decimals, short as possible.
  local aggroText
  if threatVal and type(threatVal) == "number" then
    local v = threatVal / 100 -- WoW returns threat * 100
    if v >= 1000000 then
      aggroText = math.floor(v / 1000000 + 0.5) .. "M"
    elseif v >= 1000 then
      aggroText = math.floor(v / 1000 + 0.5) .. "k"
    else
      aggroText = math.floor(v + 0.5)
    end
  else
    aggroText = math.floor(threatPct + 0.5) .. "%"
  end
  c.aggroFs:SetText(aggroText)

  --- Aggro bar color: always red, border indicates aggro status.
  do local rr, gg, bb = _EL.enemyAggroBarRGB(); c.aggroBar:SetStatusBarColor(rr, gg, bb, userOpacity) end
  c._aggroBg:SetColorTexture(0.3, 0.05, 0.05, userOpacity * 0.6)

  --- Aggro status border: red = aggro on us, white = not aggro on us.
  local isAggroOnUs = ti and (ti.isTanking or ti.targetingPlayer or ti.status == 2 or ti.status == 1)
  local borderR, borderG, borderB = 1, 1, 1  -- white default
  if isAggroOnUs then
    borderR, borderG, borderB = 1, 0.1, 0.1  -- red
  end
  for _, edge in ipairs(c.aggroBorder) do
    edge:SetColorTexture(borderR, borderG, borderB, 0.9)
  end

  --- HP value.
  local hp = entry.health or 0
  local hpMax = entry.healthMax or 1
  local hpPct = hpMax > 0 and (hp / hpMax) or 1
  c.hpBar:SetValue(hpPct)
  c.hpFs:ClearAllPoints()
  c.hpFs:SetPoint("CENTER", c.hpBar, "CENTER", 0, 0)
  c.hpFs:SetWidth(0)
  --- Compact HP text: missing HP as -425 style when damaged; else short current/percent.
  local hpText
  local deficit = hpMax > 0 and (hpMax - hp) or 0
  if deficit > 0 then
    hpText = string.format(L.HP_DEFICIT, math.floor(deficit + 0.5))
    c.hpFs:SetTextColor(1, 0.45, 0.35)
  else
    c.hpFs:SetTextColor(1, 1, 1)
    local hpAbs = hpMax > 0 and hp or 0
    if hpAbs >= 1000000 then
      hpText = math.floor(hpAbs / 1000000 + 0.5) .. "M"
    elseif hpAbs >= 1000 then
      hpText = math.floor(hpAbs / 1000 + 0.5) .. "k"
    elseif hpAbs > 0 then
      hpText = math.floor(hpAbs + 0.5)
    else
      hpText = math.floor(hpPct * 100 + 0.5) .. "%"
    end
  end
  c.hpFs:SetText(hpText)

  --- HP bar color.
  do local rr, gg, bb = _EL.enemyHpBarRGB(); c.hpBar:SetStatusBarColor(rr, gg, bb, userOpacity) end
  c._hpBg:SetColorTexture(0.05, 0.2, 0.05, userOpacity * 0.6)

  --- Cast bar.
  if entry.castName and entry.castEnd then
    local now = GetTime()
    local total = (entry.castEnd - (entry.castStart or now))
    local remaining = entry.castEnd - now
    if total > 0 and remaining > 0 then
      c.castBar:SetValue(remaining / total)
      c.castBar.nameFs:SetText(entry.castName)
      c.castBar:Show()
    else
      c.castBar:Hide()
    end
  else
    c.castBar:Hide()
  end

  --- Raid marker (centered in cell).
  if entry.raidMarker and entry.raidMarker >= 1 and entry.raidMarker <= 8 then
    c.raidMarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. entry.raidMarker)
    c.raidMarkerIcon:ClearAllPoints()
    c.raidMarkerIcon:SetPoint("CENTER", c, "CENTER", 0, 0)
    c.raidMarkerIcon:Show()
  else
    c.raidMarkerIcon:Hide()
  end

  --- Target highlight (gold, thicker, over aggro border).
  local isTarget = layoutTargetGuid and entry.guid and (entry.guid == layoutTargetGuid) or false
  for _, hl in ipairs(c.targetHighlight) do
    if isTarget then hl:Show() else hl:Hide() end
  end

  --- Background opacity.
  c.bg:SetColorTexture(0.08, 0.08, 0.1, userOpacity)

  c._elEntry = entry
  c:Show()
end

local function hideGridCell(c)
  if not c then return end
  c:Hide()
end

--- 15 visually distinct aggro colors for ToT indicators and party frames.
local PARTY_COLORS = {
  { 1.0, 0.4, 0.7 },  { 0.4, 0.7, 1.0 },  { 1.0, 0.7, 0.2 },
  { 0.5, 1.0, 0.4 },  { 0.9, 0.4, 1.0 },  { 1.0, 1.0, 0.3 },
  { 0.3, 1.0, 0.9 },  { 1.0, 0.3, 0.3 },  { 0.6, 0.8, 1.0 },
  { 1.0, 0.5, 0.0 },  { 0.7, 1.0, 0.7 },  { 0.8, 0.5, 0.2 },
  { 0.6, 0.4, 1.0 },  { 1.0, 0.8, 0.6 },  { 0.4, 1.0, 0.6 },
}
local PARTY_UNIT_COLOR = { player = 1, party1 = 2, party2 = 3, party3 = 4, party4 = 5 }
for i = 1, 40 do PARTY_UNIT_COLOR["raid" .. i] = ((i - 1) % #PARTY_COLORS) + 1 end

--- Module scope: avoid allocating tables every row refresh (Grid2-style file caches).
local CREATURE_TYPE_NAME_COLORS = {
  Undead = { 0.7, 0.4, 0.9 },
  Demon = { 0.9, 0.2, 0.2 },
  Humanoid = { 0.9, 0.75, 0.6 },
  Beast = { 0.7, 0.5, 0.3 },
  Elemental = { 0.3, 0.6, 1.0 },
  Dragonkin = { 0.8, 0.3, 0.3 },
  Mechanical = { 0.7, 0.7, 0.7 },
  Giant = { 0.8, 0.7, 0.4 },
  Aberration = { 0.5, 0.8, 0.5 },
  Critter = { 0.6, 0.8, 0.6 },
}
local EL_TEST_PARTY_NAMES = {
  UnitName("player") or "You", "Healbot", "Tankadin", "Shadowmage", "Stabbyrogue",
  "Arrowrain", "Moonfire", "Holylight", "Frostbolt", "Backstab",
  "Chainlightning", "Lifetap", "Earthshock", "Mortalstrike", "Renew",
  "Starfall", "Eviscerate", "Flamestrike", "Shieldwall", "Tranquility",
  "Mindblast", "Soulfire", "Thunderclap", "Swiftmend", "Aimshot",
}
local EL_TEST_PARTY_CLASSES = {
  "PALADIN", "PRIEST", "WARRIOR", "MAGE", "ROGUE",
  "HUNTER", "DRUID", "PALADIN", "MAGE", "ROGUE",
  "SHAMAN", "WARLOCK", "SHAMAN", "WARRIOR", "PRIEST",
  "DRUID", "ROGUE", "MAGE", "WARRIOR", "DRUID",
  "PRIEST", "WARLOCK", "WARRIOR", "DRUID", "HUNTER",
}
local layoutTargetGuid
local layoutPartyColorByGuid = {}

local function rebuildLayoutPartyColorByGuid()
  for k in pairs(layoutPartyColorByGuid) do
    layoutPartyColorByGuid[k] = nil
  end
  local gPlayer = UnitGUID("player")
  if gPlayer then
    layoutPartyColorByGuid[gPlayer] = PARTY_UNIT_COLOR.player
  end
  for i = 1, 4 do
    local tok = "party" .. i
    local g = UnitGUID(tok)
    if g then
      layoutPartyColorByGuid[g] = PARTY_UNIT_COLOR[tok]
    end
  end
  for i = 1, 40 do
    local tok = "raid" .. i
    local g = UnitGUID(tok)
    if g then
      layoutPartyColorByGuid[g] = PARTY_UNIT_COLOR[tok]
    end
  end
end

local function getPartyColorForUnit(unitTarget)
  if not unitTarget or not UnitExists(unitTarget) then
    return nil
  end
  if UnitExists("player") and UnitIsUnit(unitTarget, "player") then
    return PARTY_UNIT_COLOR.player
  end
  for i = 1, 4 do
    local tok = "party" .. i
    if UnitExists(tok) and UnitIsUnit(unitTarget, tok) then
      return PARTY_UNIT_COLOR[tok]
    end
  end
  for i = 1, 40 do
    local tok = "raid" .. i
    if UnitExists(tok) and UnitIsUnit(unitTarget, tok) then
      return PARTY_UNIT_COLOR[tok]
    end
  end
  return nil
end

--- Track aggro count per party member. Key = color index, value = number of enemies attacking.
local partyMemberAttacked = {}
--- Assigned after party frames exist; refreshes border/aggro count when the enemy list layout runs.
local applyPartyFrameAggroAttackedChrome
--- Forward-declare |partyFrameContainer| here (its real |local| + assignment live far below, near the
--- party-frame UI builder). |_EL.refreshAggroCounters| references it as an upvalue at parse time —
--- without this declaration that reference would bind to the global |partyFrameContainer| (always
--- nil) and the fast aggro-counter tick would silently no-op.
local partyFrameContainer

--- Populate |partyMemberAttacked| from a list of enemy entries. Runs independently of which render
--- path (grid/single/dual) layoutRowsImpl takes, so the per-member counters stay in sync even when
--- the row-level ToT indicator is disabled or when grid mode skips applyBarRow entirely.
local function populatePartyMemberAttacked(aggroFull, otherFull)
  local isTestMode = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
  local testNames = EL_TEST_PARTY_NAMES
  local showSelfCountOpt = (EnemyListDB and EnemyListDB.showSelfAggroCount ~= false)
  local function tallyEntry(entry)
    if not entry then return end
    if isTestMode then
      --- Mirror applyBarRow test logic: non-self enemies map via guid hash to a stable fake member.
      local ti = entry.threatInfo
      local isAggroOnUs = ti and (ti.targetingPlayer or ti.isTanking)
      if isAggroOnUs then
        --- Count toward player slot so the self-aggro digit ticks up too.
        if showSelfCountOpt then
          partyMemberAttacked[PARTY_UNIT_COLOR.player] = (partyMemberAttacked[PARTY_UNIT_COLOR.player] or 0) + 1
        end
      else
        local hash = 1
        if entry.guid then
          for ch in entry.guid:gmatch(".") do hash = hash + ch:byte() end
        end
        local memberIdx = ((hash - 1) % 25) + 1
        local cidx = ((memberIdx - 1) % #PARTY_COLORS) + 1
        partyMemberAttacked[cidx] = (partyMemberAttacked[cidx] or 0) + 1
      end
    else
      if entry.unit and UnitExists(entry.unit) then
        local etarget = entry.unit .. "target"
        if UnitExists(etarget) then
          local tg = UnitGUID(etarget)
          local cidx = tg and layoutPartyColorByGuid[tg] or getPartyColorForUnit(etarget)
          if cidx then partyMemberAttacked[cidx] = (partyMemberAttacked[cidx] or 0) + 1 end
        end
      end
    end
  end
  if aggroFull then for i = 1, #aggroFull do tallyEntry(aggroFull[i]) end end
  if otherFull then for i = 1, #otherFull do tallyEntry(otherFull[i]) end end
end

--- Fast path: recompute per-member aggro counters + refresh party-frame chrome without doing a
--- full layoutRows. Called from the party frame OnUpdate tick so counter digits reflect target
--- switches within ~0.25s rather than waiting for the next coalesced list redraw.
function _EL.refreshAggroCounters()
  if not applyPartyFrameAggroAttackedChrome then return end
  if not partyFrameContainer or not partyFrameContainer:IsShown() then return end
  for k in pairs(partyMemberAttacked) do partyMemberAttacked[k] = nil end
  rebuildLayoutPartyColorByGuid()
  local getRows = EnemyList.GetEnemyRows
  if type(getRows) == "function" then
    local ok, data = pcall(getRows)
    if ok and type(data) == "table" then
      populatePartyMemberAttacked(data.aggro, data.other)
    end
  end
  applyPartyFrameAggroAttackedChrome()
end

local function applyBarRow(r, entry, barW, h, castStripW, ooc, font, metaFont)
  if ooc then
    local par = r:GetParent()
    if par and r.SetFrameLevel then
      r:SetFrameLevel((par:GetFrameLevel() or 0) + 3)
    end
    r:SetWidth(barW)
    r:SetHeight(h)
  else
    --- Row size is required for font strings to draw; warm pool may never have run OOC (e.g. reload in combat).
    pcall(function()
      r:SetWidth(barW)
      r:SetHeight(h)
    end)
  end

  --- Click-to-target for this row runs through the OnMouseUp handler installed in |createBarRow|,
  --- which reads |r._elUnit| / |r._elName|. No secure work to do here.

  --- ToT indicator: shows who this enemy is targeting (non-secure, moves with the row).
  if r.totIndicator then
    local showToT = false
    local totName, totClassR, totClassG, totClassB
    local isTestMode = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
    if isTestMode then
      --- Test mode: cycle through fake party members for non-aggro entries.
      local testNames = EL_TEST_PARTY_NAMES
      local testClasses = EL_TEST_PARTY_CLASSES
      local ti = entry.threatInfo
      local isAggroOnUs = ti and (ti.targetingPlayer or ti.isTanking)
      if not isAggroOnUs then
        local hash = 1
        if entry.guid then
          for ch in entry.guid:gmatch(".") do hash = hash + ch:byte() end
        end
        local memberIdx = ((hash - 1) % 25) + 1
        showToT = true
        totName = testNames[memberIdx]
        local cls = testClasses[memberIdx]
        if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
          local c = RAID_CLASS_COLORS[cls]
          totClassR, totClassG, totClassB = c.r, c.g, c.b
        end
      end
    else
      --- Live: show ToT for enemies targeting party/raid members (and optionally the player).
      local showSelf = EnemyListDB and EnemyListDB.showSelfToT
      if entry.unit and UnitExists(entry.unit) then
        local enemyTarget = entry.unit .. "target"
        if UnitExists(enemyTarget) then
          local isPlayer = UnitIsUnit(enemyTarget, "player")
          if not isPlayer or showSelf then
            showToT = true
            totName = UnitName(enemyTarget) or "?"
            local _, cls = UnitClass(enemyTarget)
            if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
              local c = RAID_CLASS_COLORS[cls]
              totClassR, totClassG, totClassB = c.r, c.g, c.b
            end
          end
        end
      end
    end
    if r._elNameplateMirrorNoTot then
      showToT = false
    end
    if showToT and totName then
      r.totIndicator:SetWidth(h)
      r.totIndicator.nameFs:ClearAllPoints()
      r.totIndicator.nameFs:SetPoint("TOPLEFT", r.totIndicator, "TOPLEFT", 1, -1)
      r.totIndicator.nameFs:SetPoint("BOTTOMRIGHT", r.totIndicator, "BOTTOMRIGHT", -1, 1)
      r.totIndicator.nameFs:SetWordWrap(true)
      --- Scale font to fit. Break long single words into lines manually.
      applyGridFont(r.totIndicator.nameFs, h * 1.2)
      --- Estimate chars per line based on font size and square width.
      local fontSize = math.max(6, math.floor(h * 1.2 * 0.12))
      local charsPerLine = math.max(2, math.floor((h - 2) / (fontSize * 0.6)))
      local display = totName
      if #display > charsPerLine and not display:find(" ") then
        --- Single long word: insert newlines.
        local lines = {}
        for j = 1, #display, charsPerLine do
          lines[#lines + 1] = display:sub(j, j + charsPerLine - 1)
        end
        display = table.concat(lines, "\n")
      end
      r.totIndicator.nameFs:SetText(display)
      if totClassR then
        r.totIndicator.bg:SetColorTexture(totClassR * 0.4, totClassG * 0.4, totClassB * 0.4, 0.9)
        r.totIndicator.nameFs:SetTextColor(totClassR, totClassG, totClassB)
      else
        r.totIndicator.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        r.totIndicator.nameFs:SetTextColor(1, 1, 1)
      end
      --- Color-coded border. The per-member aggro counters are populated centrally by
      --- |populatePartyMemberAttacked| in |layoutRowsImpl| (decoupled from render mode) so we only
      --- resolve |cidx| for the border tint here — no increment.
      local cidx
      if entry.unit and UnitExists(entry.unit) then
        local etarget = entry.unit .. "target"
        if UnitExists(etarget) then
          local tg = UnitGUID(etarget)
          cidx = tg and layoutPartyColorByGuid[tg] or getPartyColorForUnit(etarget)
        end
      elseif totName then
        --- Test mode: match by name (border tint only).
        local testNames = EL_TEST_PARTY_NAMES
        for ti2 = 1, 25 do
          if totName == testNames[ti2] then
            cidx = ((ti2 - 1) % #PARTY_COLORS) + 1
            break
          end
        end
      end
      if cidx and PARTY_COLORS[cidx] and r.totIndicator.borderTop then
        local pc = PARTY_COLORS[cidx]
        r.totIndicator.borderTop:SetColorTexture(pc[1], pc[2], pc[3], 1)
        r.totIndicator.borderBot:SetColorTexture(pc[1], pc[2], pc[3], 1)
        r.totIndicator.borderLeft:SetColorTexture(pc[1], pc[2], pc[3], 1)
        r.totIndicator.borderRight:SetColorTexture(pc[1], pc[2], pc[3], 1)
        r.totIndicator.borderTop:Show()
        r.totIndicator.borderBot:Show()
        r.totIndicator.borderLeft:Show()
        r.totIndicator.borderRight:Show()
      elseif r.totIndicator.borderTop then
        r.totIndicator.borderTop:Hide()
        r.totIndicator.borderBot:Hide()
        r.totIndicator.borderLeft:Hide()
        r.totIndicator.borderRight:Hide()
      end
      r.totIndicator:Show()
    else
      r.totIndicator:Hide()
    end
  end

  local userOpacity = (type(EnemyListDB) == "table" and tonumber(EnemyListDB.barOpacity)) or defaults.barOpacity

  local ti = entry.threatInfo
  local rgbaFn = EnemyList.GetThreatBackgroundRGBA
  local br, bg, bb, ba = 0.15, 0.15, 0.18, 0.85
  if type(rgbaFn) == "function" then
    br, bg, bb, ba = rgbaFn(ti)
  end
  ba = math.min(1, math.max(0, userOpacity))
  --- Hide the full-row threatBg; individual bars have their own backgrounds now.
  r.threatBg:Hide()

  --- Bar stack (top to bottom): health → aggro → cast. All flush to frame edges.
  local showThreatBar = EnemyListDB.showThreatBar ~= false
  local threatBarH = math.max(3, math.min(20, tonumber(EnemyListDB.threatBarHeight) or defaults.threatBarHeight))
  local showCastBarOpt = EnemyListDB.showCastBar ~= false
  local castBarH = math.max(3, math.min(20, tonumber(EnemyListDB.castBarHeight) or defaults.castBarHeight))
  local hpBarH = math.max(6, math.min(40, tonumber(EnemyListDB.healthBarHeight) or defaults.healthBarHeight))
  local barR, barG, barB = br * 1.05 + 0.08, math.max(0, bg * 0.9), math.min(0.2, bb + 0.05)

  --- Calculate ToT width early so all bars can avoid it.
  local totW = (r.totIndicator and r.totIndicator:IsShown()) and h or 0

  local topStack = 0  -- offset from top (grows downward)

  --- 1) Health bar (top).
  if r.hpBar then
    local hp = entry.health or 0
    local hpMax = entry.healthMax or 1
    r.hpBar:ClearAllPoints()
    r.hpBar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -topStack)
    r.hpBar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -totW, -topStack)
    r.hpBar:SetHeight(hpBarH)
    if hpMax > 0 then r.hpBar:SetValue(hp / hpMax) else r.hpBar:SetValue(1) end
    do local rr, gg, bb = _EL.enemyHpBarRGB(); r.hpBar:SetStatusBarColor(rr, gg, bb, userOpacity) end
    if r._hpBg then r._hpBg:SetColorTexture(0, 0, 0, userOpacity * 0.5) end
    --- HP text: name left, value right.
    if not r._hpNameFs then
      r._hpNameFs = r.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      r._hpNameFs:SetJustifyH("LEFT")
      r._hpNameFs:SetWordWrap(false)
      r._hpNameFs:SetShadowOffset(1, -1)
      r._hpNameFs:SetShadowColor(0, 0, 0, 1)
    end
    if not r._hpValueFs then
      r._hpValueFs = r.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      r._hpValueFs:SetJustifyH("RIGHT")
      r._hpValueFs:SetWordWrap(false)
      r._hpValueFs:SetShadowOffset(1, -1)
      r._hpValueFs:SetShadowColor(0, 0, 0, 1)
      r._hpValueFs:SetTextColor(1, 1, 1, 0.8)
    end
    topStack = topStack + hpBarH
  end

  --- 2) Aggro/threat bar (below health).
  local showPct = showThreatBar and ti and ti.hasAPI and (ti.isTanking or type(ti.threatPct) == "number")
  local tvFmt = ti and EnemyList.FormatThreatShort and EnemyList.FormatThreatShort(ti.threatValue) or nil
  r.pctBar:ClearAllPoints()
  r.pctBar:SetHeight(threatBarH)
  r.pctBar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -topStack)
  r.pctBar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -totW, -topStack)
  if not r.pctBar.threatFs then
    r.pctBar.threatFs = r.pctBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.pctBar.threatFs:SetPoint("CENTER", r.pctBar, "CENTER", 0, 0)
    r.pctBar.threatFs:SetJustifyH("CENTER")
    r.pctBar.threatFs:SetWordWrap(false)
    r.pctBar.threatFs:SetShadowOffset(1, -1)
    r.pctBar.threatFs:SetShadowColor(0, 0, 0, 1)
    r.pctBar.threatFs:SetTextColor(1, 1, 1, 0.9)
  end
  applyGridFont(r.pctBar.threatFs, threatBarH * 5)
  topStack = topStack + threatBarH
  if showPct then
    local v = ti.isTanking and 100 or (ti.threatPct or 0)
    r.pctBar:SetValue(math.max(0, math.min(100, v)))
    r.pctBar:SetStatusBarColor(barR, barG, barB, 0.95)
    r.pctBar.threatFs:SetText(tvFmt or "")
    r.pctBar:Show()
  else
    r.pctBar:SetValue(0)
    r.pctBar.threatFs:SetText("")
    r.pctBar:Hide()
  end
  if r._threatValueFs then r._threatValueFs:SetText("") end

  --- 2a) Second on full threat list (one bar under the player’s threat; uses runner-up bar height).
  if r._elSecondThreatBar then
    local sdb2 = type(EnemyListDB) == "table" and EnemyListDB or defaults
    local want2 = sdb2.showSecondOnThreatBar ~= false and showThreatBar
    local st2 = entry.secondOnThreat
    local isTm = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
    local can2 = (entry.unit and UnitExists(entry.unit)) or isTm
    if want2 and st2 and st2.name and can2 then
      local mb2 = _EL.runnerUpBarHeight()
      local gap2 = 1
      topStack = topStack + gap2
      r._elSecondThreatBar:ClearAllPoints()
      r._elSecondThreatBar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -topStack)
      r._elSecondThreatBar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -totW, -topStack)
      r._elSecondThreatBar:SetHeight(mb2)
      local p2 = math.max(0, math.min(100, st2.pct or 0))
      r._elSecondThreatBar:SetValue(p2)
      local r2, g2, b2
      if p2 >= 90 then     r2, g2, b2 = 1.00, 0.30, 0.30
      elseif p2 >= 70 then r2, g2, b2 = 1.00, 0.85, 0.25
      else                 r2, g2, b2 = 0.28, 0.60, 0.95
      end
      r._elSecondThreatBar:SetStatusBarColor(r2, g2, b2, 0.95)
      if r._elSecondThreatBar.nameFs and r._elSecondThreatBar.pctFs then
        applyGridFont(r._elSecondThreatBar.nameFs, mb2 * 5)
        applyGridFont(r._elSecondThreatBar.pctFs, mb2 * 5)
        r._elSecondThreatBar.nameFs:SetText(_EL.truncateName(st2.name or ""))
        r._elSecondThreatBar.pctFs:SetText(math.floor(p2 + 0.5) .. "%")
      end
      r._elSecondThreatBar:Show()
      topStack = topStack + mb2
    else
      r._elSecondThreatBar:Hide()
    end
  end

  --- 2b) Runner-up threat bars — top N non-tanking threats on this enemy, stacked vertically
  --- (one per line) with the player name on the bar and the percentage right-aligned.
  --- Colors: green 0-70%, yellow 70-90%, red 90-100%+. Hidden for stub rows without a unit token.
  if r._elRunnerUpRow and r._elRunnerUpBars then
    local hasUnit = entry.unit and UnitExists(entry.unit)
    local show = _EL.showRunnerUpBars() and (hasUnit or entry.runnerUpThreats) and showThreatBar
    if show then
      local limit   = _EL.runnerUpBarCount()
      local mbH     = _EL.runnerUpBarHeight()
      local threats = entry.runnerUpThreats or _EL.computeRunnerUpThreats(entry.unit, limit)
      local rowW    = (barW or r:GetWidth() or 200) - totW
      local shown   = 0
      for i = 1, limit do if threats[i] then shown = shown + 1 end end
      local vgap    = 1
      local blockH  = shown > 0 and (shown * mbH + math.max(0, shown - 1) * vgap) or 0
      r._elRunnerUpRow:ClearAllPoints()
      r._elRunnerUpRow:SetPoint("TOPLEFT",  r, "TOPLEFT",  0, -topStack)
      r._elRunnerUpRow:SetPoint("TOPRIGHT", r, "TOPRIGHT", -totW, -topStack)
      r._elRunnerUpRow:SetHeight(math.max(1, blockH))
      if shown > 0 then r._elRunnerUpRow:Show() else r._elRunnerUpRow:Hide() end
      local slot = 0
      for i = 1, 5 do
        local mb = r._elRunnerUpBars[i]
        local t  = threats[i]
        if i <= limit and t and mb then
          mb:ClearAllPoints()
          mb:SetPoint("TOPLEFT", r._elRunnerUpRow, "TOPLEFT", 0, -(slot * (mbH + vgap)))
          mb:SetSize(rowW, mbH)
          local p = math.max(0, math.min(100, t.pct))
          mb:SetValue(p)
          local rr, gg, bb
          if p >= 90 then     rr, gg, bb = 1.00, 0.30, 0.30
          elseif p >= 70 then rr, gg, bb = 1.00, 0.85, 0.25
          else                rr, gg, bb = 0.30, 0.90, 0.30
          end
          mb:SetStatusBarColor(rr, gg, bb, 0.95)
          if mb.nameFs then
            applyGridFont(mb.nameFs, mbH * 5)
            mb.nameFs:SetText(_EL.truncateName(t.name or ""))
          end
          if mb.pctFs then
            applyGridFont(mb.pctFs, mbH * 5)
            mb.pctFs:SetText(math.floor(p + 0.5) .. "%")
          end
          mb:Show()
          slot = slot + 1
        elseif mb then
          mb:Hide()
        end
      end
      topStack = topStack + blockH
    else
      r._elRunnerUpRow:Hide()
      for i = 1, 5 do
        if r._elRunnerUpBars[i] then r._elRunnerUpBars[i]:Hide() end
      end
    end
  end

  --- 3) Cast bar (below aggro).
  if showCastBarOpt then
    r.castBar:ClearAllPoints()
    r.castBar:SetHeight(castBarH)
    r.castBar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -topStack)
    r.castBar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -totW, -topStack)
    applyGridFont(r.castBar.nameFs, castBarH * 5)
    topStack = topStack + castBarH
  end

  r._enemyListHasUnit = entry.unit and true or false
  r._elUnit = entry.unit  --- used by OnEnter (nameplate highlight) and OnMouseUp (context menu)
  r._elName = entry.name  --- fallback for |TargetUnit|: CLEU-only stubs have no unit token.

  --- Feature 1: target highlight
  if r.targetHighlight then
    local isTarget = layoutTargetGuid and entry.guid and (entry.guid == layoutTargetGuid) or false
    for _, tex in ipairs(r.targetHighlight) do
      if isTarget then tex:Show() else tex:Hide() end
    end
  end

  --- Feature 2: aggro swap flash
  if r.aggroFlash then
    if entry.aggroSwapped and entry.aggroSwapTime and (GetTime() - entry.aggroSwapTime) < 1.5 then
      local elapsed = GetTime() - entry.aggroSwapTime
      local alpha = math.max(0, 0.45 * (1 - elapsed / 1.5))
      r.aggroFlash:SetColorTexture(1, 0, 0, alpha)
      r.aggroFlash:Show()
    else
      r.aggroFlash:Hide()
    end
  end

  --- Feature 3: raid marker icon (top-left corner, above all bars).
  local showRaidMarkers = EnemyListDB.showRaidMarkers ~= false
  local nameLeftOffset = 6
  if r.raidMarkerIcon then
    local marker = entry.raidMarker
    if showRaidMarkers and marker and marker >= 1 and marker <= 8 then
      r.raidMarkerIcon:ClearAllPoints()
      r.raidMarkerIcon:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -2)
      r.raidMarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. marker)
      r.raidMarkerIcon:Show()
      nameLeftOffset = 20
    else
      r.raidMarkerIcon:Hide()
    end
  end

  --- Feature 5: cast bar with spell name (left) + countdown (right).
  if r.castBar then
    --- Create countdown FontString if needed.
    if not r.castBar._countdownFs then
      r.castBar._countdownFs = r.castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      r.castBar._countdownFs:SetPoint("RIGHT", r.castBar, "RIGHT", -2, 0)
      r.castBar._countdownFs:SetJustifyH("RIGHT")
      r.castBar._countdownFs:SetWordWrap(false)
      r.castBar._countdownFs:SetShadowOffset(1, -1)
      r.castBar._countdownFs:SetShadowColor(0, 0, 0, 1)
      r.castBar._countdownFs:SetTextColor(1, 1, 1, 0.9)
    end
    applyGridFont(r.castBar.nameFs, castBarH * 5)
    applyGridFont(r.castBar._countdownFs, castBarH * 5)
    if showCastBarOpt and entry.castName and entry.castEnd then
      local now = GetTime()
      local remaining = entry.castEnd - now
      local duration = (entry.castStart and entry.castEnd) and (entry.castEnd - entry.castStart) or 1
      local minRem = 0.02
      --- Nameplate mirror: tiny remaining times flicker Show/Hide every refresh (instants / timing).
      if r._elNameplateMirrorNoTot then
        minRem = 0.15
      end
      if remaining > minRem and duration > 0 then
        r.castBar:SetMinMaxValues(0, 1)
        r.castBar:SetValue(1 - (remaining / duration))
        r.castBar.nameFs:SetText(entry.castName)
        r.castBar._countdownFs:SetText(string.format("%.1fs", remaining))
        r.castBar:Show()
        if r._elNameplateMirrorNoTot and r.castBar.SetAlpha then
          r.castBar:SetAlpha(1)
        end
      else
        r.castBar:Hide()
        if r._elNameplateMirrorNoTot and r.castBar.SetAlpha then
          r.castBar:SetAlpha(0)
        end
      end
    else
      r.castBar:Hide()
      if r._elNameplateMirrorNoTot and r.castBar and r.castBar.SetAlpha then
        r.castBar:SetAlpha(0)
      end
    end
  end

  --- Feature 7: creature type colors for name
  local nameR, nameG, nameB = 1, 1, 1
  if entry.creatureType and CREATURE_TYPE_NAME_COLORS[entry.creatureType] then
    local c = CREATURE_TYPE_NAME_COLORS[entry.creatureType]
    nameR, nameG, nameB = c[1], c[2], c[3]
  end

  --- Text on bars: HP band shows name + HP; non-compact adds a second line (distance | aggro | target) on metaFs.

  --- Health bar text: enemy name (left) + HP value (right); optional second line (distance | aggro | target) when not compact.
  local compactLayout = EnemyListDB and EnemyListDB.compactRow and true or false
  local displayName = string.format(L.NAME_WITH_LEVEL, entry.levelText or L.LEVEL_UNKNOWN, _EL.truncateName(entry.name or "?"))
  --- Build the meta line with sections only when they have real data. Distance in particular is
  --- often unresolvable on Classic (|unitDistanceYards| may return nil), and the user doesn't want
  --- a literal "?" cluttering the line — so we omit the distance segment entirely when unknown.
  local mpieces = {}
  if entry.distance and entry.distanceText and entry.distanceText ~= L.DIST_UNKNOWN then
    mpieces[#mpieces + 1] = entry.distanceText
  end
  mpieces[#mpieces + 1] = entry.aggro or L.AGGRO_UNKNOWN
  mpieces[#mpieces + 1] = entry.targetName or L.TARGET_NONE
  local metaLine = table.concat(mpieces, "  |  ")
  if r._hpNameFs and r._hpValueFs and r.metaFs then
    r._hpNameFs:SetTextColor(nameR, nameG, nameB)
    r._hpNameFs:SetText(displayName)
    local hp = entry.health or 0
    local hpMax = entry.healthMax or 1
    local hpPct = hpMax > 0 and (hp / hpMax) or 1
    if hp >= 1000000 then
      r._hpValueFs:SetText(math.floor(hp / 1000000 + 0.5) .. "M")
    elseif hp >= 1000 then
      r._hpValueFs:SetText(math.floor(hp / 1000 + 0.5) .. "k")
    elseif hp > 0 then
      r._hpValueFs:SetText(tostring(math.floor(hp + 0.5)))
    else
      r._hpValueFs:SetText(math.floor(hpPct * 100 + 0.5) .. "%")
    end

    if compactLayout then
      r.metaFs:SetText("")
      r.metaFs:Hide()
      local metaMuted = "|cffb0b8c0" .. metaLine .. "|r"
      r._hpNameFs:SetText(string.format("%s  %s", displayName, metaMuted))
      r._hpNameFs:ClearAllPoints()
      r._hpNameFs:SetPoint("TOPLEFT", r, "TOPLEFT", nameLeftOffset, 0)
      r._hpNameFs:SetPoint("RIGHT", r, "RIGHT", -40 - totW, 0)
      r._hpNameFs:SetHeight(hpBarH)
      r._hpValueFs:ClearAllPoints()
      r._hpValueFs:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2 - totW, 0)
      r._hpValueFs:SetHeight(hpBarH)
      applyGridFont(r._hpNameFs, hpBarH * 4)
      applyGridFont(r._hpValueFs, hpBarH * 4)
    else
      local nh = math.max(7, math.floor(hpBarH * 0.52))
      local mh = math.max(6, hpBarH - nh)
      r.metaFs:Show()
      r.metaFs:SetTextColor(0.74, 0.77, 0.82)
      r.metaFs:SetText(metaLine)
      r._hpValueFs:ClearAllPoints()
      r._hpValueFs:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2 - totW, 0)
      r._hpValueFs:SetHeight(nh)
      r._hpNameFs:ClearAllPoints()
      r._hpNameFs:SetPoint("TOPLEFT", r, "TOPLEFT", nameLeftOffset, 0)
      r._hpNameFs:SetPoint("TOPRIGHT", r._hpValueFs, "TOPLEFT", -4, 0)
      r._hpNameFs:SetHeight(nh)
      r.metaFs:ClearAllPoints()
      r.metaFs:SetPoint("TOPLEFT", r, "TOPLEFT", nameLeftOffset, -nh)
      r.metaFs:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2 - totW, -nh)
      r.metaFs:SetHeight(mh)
      applyGridFont(r._hpNameFs, nh * 4.2)
      applyGridFont(r._hpValueFs, nh * 4.2)
      applyGridFont(r.metaFs, mh * 3.5)
    end
  end

  r.nameFs:SetText("")

  if ooc then
    r:SetAlpha(1)
  end
end

--- Renders a real list row (HP, threat, cast, text, ToT, markers) in place of the stock nameplate
--- (parent should cover the |C_NamePlate| root; |npH| scales the row to fit a short nameplate).
--- Used by |EnemyListNameplateMirror.lua| (load that file *after* this one). Mirror rows: no click/hover.
function EnemyList.ApplyNameplateMirrorBarRow(parentFrame, unit, entry, npW, npH)
  if not createBarRow or not applyBarRow or not parentFrame or not unit or not entry or type(entry) ~= "table" then
    return
  end
  if not UnitExists(unit) then
    return
  end
  local wAvail = (type(npW) == "number" and npW > 24) and (npW - 4) or 200
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local listBarW = math.max(80, math.min(500, tonumber(db.width) or defaults.width))
  local barW
  if parentFrame._elNameplateMirrorHost then
    --- Match the nameplate/Plater |unitFrame| width; centering a narrower list width left a ghost bar offset.
    barW = wAvail
  else
    barW = math.min(listBarW, wAvail)
  end
  local row = parentFrame.EnemyListNmRow
  if not row then
    local guid = (UnitGUID(unit) or "x"):gsub(":", "")
    local name = "EnemyListNm" .. tostring(guid):sub(1, 32)
    local ok, r = pcall(function()
      return createBarRow(parentFrame, name)
    end)
    if not ok or not r then
      return
    end
    row = r
    parentFrame.EnemyListNmRow = row
    row:EnableMouse(false)
    if row.SetMouseClickEnabled then
      row:SetMouseClickEnabled(false)
    end
    if row.SetMouseMotionEnabled then
      row:SetMouseMotionEnabled(false)
    end
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:SetScript("OnMouseUp", nil)
  else
    pcall(function()
      row:SetParent(parentFrame)
    end)
  end
  if parentFrame._elNameplateMirrorHost then
    pcall(function()
      if row.SetIgnoreParentAlpha then
        row:SetIgnoreParentAlpha(true)
      end
      if row.SetAlpha then
        row:SetAlpha(1)
      end
    end)
    --- ToT strip is a tall column on the right; on nameplates it often reads as a "black bar" and clips past borders.
    row._elNameplateMirrorNoTot = true
  else
    row._elNameplateMirrorNoTot = nil
  end
  local e = {}
  for k, v in pairs(entry) do
    e[k] = v
  end
  e.unit = unit
  if (not e.name or e.name == "") and UnitName(unit) then
    e.name = UnitName(unit)
  end
  local h = effectiveRowHeight()
  local font = fontForPreset(db.fontPreset)
  local metaFont = fontMetaForPreset(db.fontPreset)
  local ooc = not (InCombatLockdown and InCombatLockdown())
  local xOff = 0
  if not parentFrame._elNameplateMirrorHost and wAvail > barW + 2 then
    xOff = math.floor((wAvail - barW) * 0.5 + 0.5)
  end
  pcall(function()
    row:ClearAllPoints()
    local pad = parentFrame._elNameplateMirrorHost and 1 or 0
    row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOff + pad, 0)
  end)
  applyBarRow(row, e, barW, h, 0, ooc, font, metaFont)
  local scale = 1
  if type(npH) == "number" and npH > 6 and h > 0 then
    scale = math.min(1, (npH - 2) / h)
  end
  pcall(function()
    row:SetScale(scale)
    row:ClearAllPoints()
    if parentFrame._elNameplateMirrorHost then
      --- |CENTER| + |SetScale| misaligned the row vs the nameplate; pin from the top (same as stock bars).
      local pad = 1
      row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOff + pad, 0)
    else
      row:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
    end
  end)
  pcall(function()
    if parentFrame.SetClipsChildren then
      parentFrame:SetClipsChildren(true)
    end
  end)
  --- Mirror parent is a child with |SetAllPoints| on the nameplate — do not |SetWidth|/|SetHeight| here
  --- (breaks anchor); |npW|/|npH| are only for bar width and row scale.
  row:Show()
  parentFrame:Show()
end

--- Left column = aggroed / high threat; right = not. Lists rebuild every refresh from live threat (see core events).
local function layoutOneColumn(colFrame, headerFs, title, entries, pool, idPrefix, colW, h, castStripW, ooc, font, metaFont)
  local y = -ROW_TOP_PAD
  headerFs:SetText(title)
  headerFs:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 2, y)
  headerFs:SetWidth(math.max(24, colW - 4))
  headerFs:Show()
  y = y - SECTION_HEAD_H

  local combatLayout = InCombatLockdown and InCombatLockdown()
  for i, entry in ipairs(entries) do
    local r = pool[i]
    if not r then
      if combatLayout then
        local now = GetTime()
        if now - lastSecureRowCombatWarn >= SECURE_ROW_COMBAT_WARN_INTERVAL then
          lastSecureRowCombatWarn = now
          elPrintErr("layoutOneColumn:secureEnemyRow", L.ERR_SECURE_ROW_COMBAT)
        end
        break
      end
      r = createBarRow(colFrame, "EnemyList" .. idPrefix .. i)
      pool[i] = r
    elseif r:GetParent() ~= colFrame then
      --- Reparenting non-secure row frames is safe even in combat.
      if not combatLayout then
        r:SetParent(colFrame)
      else
        pcall(function() r:SetParent(colFrame) end)
      end
    end
    applyBarRow(r, entry, colW, h, castStripW, ooc, font, metaFont)
    --- Outer row frame is not a secure button; position/show during lockdown so the list stays visible.
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, y)
    r:Show()
    y = y - h
    if i < #entries then
      y = y - ROW_GAP
    end
  end

  for j = #entries + 1, #pool do
    hideBarRow(pool[j], ooc)
  end

  return -y + LAYOUT_COL_BOTTOM_PAD
end

--- contentHeightOverride: pixels for rowContainer body (avoids relying on GetHeight() in the same frame on some clients).
local function applyMainLayoutSize(wContent, _unused, contentHeightOverride)
  if not main or not rowContainer then
    return
  end
  local ch = type(contentHeightOverride) == "number" and contentHeightOverride or rowContainer:GetHeight()
  local baseH = MAIN_HEADER_OFFSET + ch + MAIN_BOTTOM_PAD
  local ok, errSz = pcall(function()
    local w0, h0 = main:GetWidth(), main:GetHeight()
    if w0 and h0 and math.abs(w0 - wContent) < 0.5 and math.abs(h0 - baseH) < 0.5 then
      if mainScaleRoot then
        mainScaleRoot:SetSize(wContent, baseH)
      end
      return
    end
    main:SetWidth(wContent)
    main:SetHeight(baseH)
  end)
  if not ok then
    elPrintErr(L.ERR_APPLY_MAIN_LAYOUT, errSz)
    return
  end
  if mainScaleRoot then
    mainScaleRoot:SetSize(main:GetWidth(), main:GetHeight())
  end
  if not elInCombatLockdown() then
    applyUiScale()
  end
end

--- Reuse buffers instead of allocating a new table every layout (Grid2-style pooling).
local layoutAggroSlice = {}
local layoutOtherSlice = {}
local layoutGridEntriesSlice = {}
local layoutSingleColSlice = {}

local function reuseSlice(dst, src, n)
  n = math.min(n, #src)
  for i = 1, n do
    dst[i] = src[i]
  end
  for j = n + 1, #dst do
    dst[j] = nil
  end
  return dst
end

local function layoutRowsImpl(opt)
  --- Reset attacked tracking each refresh cycle.
  for k in pairs(partyMemberAttacked) do partyMemberAttacked[k] = nil end
  layoutTargetGuid = UnitGUID("target")
  rebuildLayoutPartyColorByGuid()
  local opts = type(opt) == "table" and opt or nil
  if not rowContainer or not rowContainer.colAggro then
    return
  end
  local getRows = EnemyList.GetEnemyRows
  if type(getRows) ~= "function" then
    return
  end
  local hSaved = EnemyListDB.barHeight or defaults.barHeight
  local w = EnemyListDB.width or defaults.width
  local okData, dataOrErr = pcall(getRows)
  if not okData then
    elPrintErr(L.ERR_GET_ENEMY_ROWS_UI, dataOrErr)
    return
  end
  local data = dataOrErr or {}
  local aggroFull = data.aggro or {}
  local otherFull = data.other or {}
  local totalTracked = data.total or (#aggroFull + #otherFull)
  --- Populate per-member aggro counters BEFORE render branching (grid/single/dual) so the counts
  --- stay current even when applyBarRow never runs for a given refresh. The render path may still
  --- increment these too (applyBarRow's ToT block); that's harmless — the rendered cidx just matches
  --- what we already tallied, and double-counting isn't possible because we reset at the top of the
  --- function and populate once here.
  populatePartyMemberAttacked(aggroFull, otherFull)
  local capA = math.max(1, math.min(MAX_ENEMIES_CAP, math.floor(tonumber(EnemyListDB.maxEnemiesAggro) or defaults.maxEnemiesAggro)))
  local capO = math.max(1, math.min(MAX_ENEMIES_CAP, math.floor(tonumber(EnemyListDB.maxEnemiesOther) or defaults.maxEnemiesOther)))
  EnemyListDB.maxEnemiesAggro = capA
  EnemyListDB.maxEnemiesOther = capO
  local takeA = math.min(#aggroFull, capA)
  local takeO = math.min(#otherFull, capO)
  local aggroList = reuseSlice(layoutAggroSlice, aggroFull, takeA)
  local otherList = reuseSlice(layoutOtherSlice, otherFull, takeO)
  local font = fontForPreset(EnemyListDB.fontPreset)
  local metaFont = fontMetaForPreset(EnemyListDB.fontPreset)
  local rowH = effectiveRowHeight()
  local castStripW = 0
  local ooc = not (InCombatLockdown and InCombatLockdown())
  local innerW = w - 16
  local singleCol = EnemyListDB and EnemyListDB.singleColumn
  --- Bar width = column width. Frame width adjusts: single col = bar + padding, dual col = 2*bar + gap + padding.
  local barW = math.max(80, math.min(500, tonumber(EnemyListDB.width) or defaults.width))
  local colW = barW
  if singleCol then
    w = barW + 16
  else
    w = barW * 2 + COL_GAP + 16
  end
  local innerW = w - 16


  if totalTracked == 0 then
    rowContainer.hdrAggro:Hide()
    rowContainer.hdrOther:Hide()
    for j = 1, #rowsAggro do
      hideBarRow(rowsAggro[j], ooc)
    end
    for j = 1, #rowsOther do
      hideBarRow(rowsOther[j], ooc)
    end
    for j = 1, #gridCells do
      hideGridCell(gridCells[j])
    end
    if not rowContainer.emptyFs then
      rowContainer.emptyFs = rowContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      rowContainer.emptyFs:SetJustifyH("CENTER")
    end
    rowContainer.emptyFs:SetWidth(innerW - 8)
    rowContainer.emptyFs:SetPoint("TOP", rowContainer, "TOP", 0, -ROW_TOP_PAD - 4)
    rowContainer.emptyFs:SetText(L.NO_ENEMIES)
    rowContainer.emptyFs:SetTextColor(0.75, 0.75, 0.78)
    rowContainer.emptyFs:Show()
    local emptyContentH = 28
    rowContainer:SetHeight(emptyContentH)
    applyMainLayoutSize(w, nil,emptyContentH)
    return
  end

  if rowContainer.emptyFs then
    rowContainer.emptyFs:Hide()
  end

  local isGridMode = EnemyListDB and EnemyListDB.gridMode
  if isGridMode then
    --- Grid mode: square cells laid out in a wrapping grid.
    rowContainer.hdrAggro:Hide()
    rowContainer.hdrOther:Hide()
    for j = 1, #rowsAggro do hideBarRow(rowsAggro[j], ooc) end
    for j = 1, #rowsOther do hideBarRow(rowsOther[j], ooc) end
    --- Merge all entries, sort by selected mode.
    local allEntries = {}
    for _, e in ipairs(aggroFull) do allEntries[#allEntries + 1] = e end
    for _, e in ipairs(otherFull) do allEntries[#allEntries + 1] = e end
    local sortMode = tonumber(EnemyListDB.sortMode) or 1
    local sortFn = EnemyList.sortModes and EnemyList.sortModes[sortMode]
    if sortFn then table.sort(allEntries, sortFn) end
    local cap = math.max(1, math.min(MAX_ENEMIES_CAP, capA + capO))
    local entries = reuseSlice(layoutGridEntriesSlice, allEntries, math.min(#allEntries, cap))
    local cellSize = math.max(30, math.min(100, tonumber(EnemyListDB.gridCellSize) or defaults.gridCellSize))
    local cellsPerRow = math.max(1, math.min(5, math.floor(tonumber(EnemyListDB.gridColumns) or defaults.gridColumns)))
    local x, y = 0, -ROW_TOP_PAD
    for i, entry in ipairs(entries) do
      local c = gridCells[i]
      if not c then
        c = createGridCell(rowContainer, "EnemyListGrid" .. i)
        gridCells[i] = c
      end
      applyGridCell(c, entry, cellSize)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", x, y)
      --- Left-click: target this mob. Right-click: target this mob's target (healer-friendly).
      c:SetScript("OnMouseUp", function(self, btn)
        if InCombatLockdown() then return end
        if btn == "LeftButton" then
          local nm = (type(entry.name) == "string" and entry.name ~= "") and entry.name or nil
          if entry.unit and UnitExists(entry.unit) then nm = nm or UnitName(entry.unit) end
          if nm then pcall(function() RunMacroText("/target " .. nm) end) end
        elseif btn == "RightButton" and entry.unit and UnitExists(entry.unit) then
          local totUnit = entry.unit .. "target"
          if UnitExists(totUnit) and not UnitIsUnit(totUnit, "player") then
            local tnm = UnitName(totUnit)
            if tnm then pcall(function() RunMacroText("/target " .. tnm) end) end
          end
        end
      end)
      x = x + cellSize + GRID_GAP
      if ((i) % cellsPerRow) == 0 then
        x = 0
        y = y - cellSize - GRID_GAP
      end
    end
    for j = #entries + 1, #gridCells do
      hideGridCell(gridCells[j])
    end
    local rows = math.ceil(#entries / cellsPerRow)
    local contentH = ROW_TOP_PAD + rows * (cellSize + GRID_GAP)
    --- Grid frame width = cells + gaps + padding.
    local gridW = cellsPerRow * (cellSize + GRID_GAP) - GRID_GAP + 16
    rowContainer:SetHeight(contentH)
    rowContainer.colAggro:SetHeight(contentH)
    rowContainer.colOther:SetHeight(contentH)
    applyMainLayoutSize(gridW, nil, contentH)
    return
  end

  --- Hide grid cells when not in grid mode.
  if not isGridMode then
    for j = 1, #gridCells do
      hideGridCell(gridCells[j])
    end
  end

  if singleCol then
    --- Single-column mode: merge aggro + other, sort by selected mode, show in one list.
    local allEntries = {}
    for _, e in ipairs(aggroFull) do allEntries[#allEntries + 1] = e end
    for _, e in ipairs(otherFull) do allEntries[#allEntries + 1] = e end
    local sortMode = tonumber(EnemyListDB.sortMode) or 1
    local sortFn = EnemyList.sortModes and EnemyList.sortModes[sortMode]
    if sortFn then
      table.sort(allEntries, sortFn)
    end
    local cap = math.max(1, math.min(MAX_ENEMIES_CAP, capA + capO))
    local entries = reuseSlice(layoutSingleColSlice, allEntries, math.min(#allEntries, cap))
    --- Use full width, leave room for ToT square.
    local barW = colW
    rowContainer.colAggro:ClearAllPoints()
    rowContainer.colAggro:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, 0)
    rowContainer.colAggro:SetWidth(colW)
    rowContainer.colOther:ClearAllPoints()
    rowContainer.colOther:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, 0)
    rowContainer.colOther:SetWidth(0)
    rowContainer.hdrOther:Hide()
    for j = 1, #rowsOther do
      hideBarRow(rowsOther[j], ooc)
    end
    local sortLabels = { "Aggro Hi", "Aggro Lo", "HP Hi", "HP Lo" }
    local hA = layoutOneColumn(
      rowContainer.colAggro,
      rowContainer.hdrAggro,
      L.TITLE .. " (" .. (sortLabels[sortMode] or "?") .. ")",
      entries,
      rowsAggro,
      "Aggro",
      barW,
      rowH,
      castStripW,
      ooc,
      font,
      metaFont
    )
    local contentH = math.max(hA, SECTION_HEAD_H + ROW_TOP_PAD + 4)
    rowContainer:SetHeight(contentH)
    rowContainer.colAggro:SetHeight(contentH)
    applyMainLayoutSize(w, nil,contentH)
  else
    --- Two-column mode (default).
    local colW2 = math.max(80, (innerW - COL_GAP) / 2)
    rowContainer.colAggro:ClearAllPoints()
    rowContainer.colAggro:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, 0)
    rowContainer.colAggro:SetWidth(colW2)
    rowContainer.colOther:ClearAllPoints()
    rowContainer.colOther:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", colW2 + COL_GAP, 0)
    rowContainer.colOther:SetWidth(colW2)
    local hA = layoutOneColumn(
      rowContainer.colAggro,
      rowContainer.hdrAggro,
      L.SECTION_AGGRO,
      aggroList,
      rowsAggro,
      "Aggro",
      colW2,
      rowH,
      castStripW,
      ooc,
      font,
      metaFont
    )
    local otherBarW = colW2
    local hO = layoutOneColumn(
      rowContainer.colOther,
      rowContainer.hdrOther,
      L.SECTION_OTHER,
      otherList,
      rowsOther,
      "Other",
      otherBarW,
      rowH,
      castStripW,
      ooc,
      font,
      metaFont
    )
    local contentH = math.max(hA, hO, SECTION_HEAD_H + ROW_TOP_PAD + 4)
    rowContainer:SetHeight(contentH)
    rowContainer.colAggro:SetHeight(contentH)
    rowContainer.colOther:SetHeight(contentH)
    applyMainLayoutSize(w, nil,contentH)
  end
end

function layoutRows(opt)
  local ok, err = pcall(layoutRowsImpl, opt)
  if not ok then
    elPrintErr("layoutRows", err)
  end
  --- Always refresh aggro chrome, including when layoutRowsImpl early-returned (empty list / grid
  --- mode). The counter pass runs before any early-return, so chrome must fire regardless of |ok|
  --- for the counters to visibly update on the party/raid frames.
  if applyPartyFrameAggroAttackedChrome then
    applyPartyFrameAggroAttackedChrome()
  end
  if type(EnemyList.RefreshNameplateListMirrors) == "function" then
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        pcall(EnemyList.RefreshNameplateListMirrors)
      end)
    else
      pcall(EnemyList.RefreshNameplateListMirrors)
    end
  end
end

function EnemyList.OnDataChanged()
  if main then
    layoutRows()
  end
end

--- PARTY_COLORS, PARTY_UNIT_COLOR, getPartyColorForUnit, partyMemberAttacked
--- defined earlier in file (before applyBarRow).

--- Party frames container and unit frames. |partyFrameContainer| is forward-declared earlier so
--- |_EL.refreshAggroCounters| can capture it as an upvalue.
local partyUnitFrames = {}
--- unit token -> party frame (for event-driven health/dispel updates).
local partyUfByUnit = {}
local partyUnitWatchFrame
--- WoW exposes |raid1|–|raid40|. We only had raid20 before; roster slots 21+ are group 5+ in 25-player raids.
local PARTY_FRAME_RAID_UNIT_MAX = 40
local hidePartyDispelIndicators
local syncPartyFrameUnitChrome

local function savePartyFramePosition()
  if not partyFrameContainer then
    return
  end
  --- |reanchorFrameTopLeftUIParent| calls |ClearAllPoints|/|SetPoint| which are protected on the
  --- party container during combat (it holds SecureUnitButtonTemplate children). Skip the
  --- reanchor pass in combat; the next drag-stop OOC will redo it anyway.
  if not (InCombatLockdown and InCombatLockdown()) then
    reanchorFrameTopLeftUIParent(partyFrameContainer)
  end
  saveFrameTopLeftToDB(partyFrameContainer, "partyFrameX", "partyFrameY")
end

local function partyFrameHpBarHeightPx()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local h = tonumber(db.partyFrameHealthBarHeight) or defaults.partyFrameHealthBarHeight
  return math.max(4, math.min(60, math.floor(h + 0.5)))
end

local function partyFrameHpDeficitEnabled()
  if type(EnemyListDB) ~= "table" then
    return defaults.partyFrameShowHpDeficit ~= false
  end
  return EnemyListDB.partyFrameShowHpDeficit ~= false
end

local function partyFrameDebuffsEnabled()
  if type(EnemyListDB) ~= "table" then
    return defaults.partyFrameShowDebuffs ~= false
  end
  return EnemyListDB.partyFrameShowDebuffs ~= false
end

local function partyFrameHpDeficitColorComponent(key)
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = db[key]
  if type(v) ~= "number" or v ~= v then
    return defaults[key]
  end
  return math.max(0, math.min(1, v))
end

local function partyFrameHpDeficitTextRGB()
  return partyFrameHpDeficitColorComponent("partyFrameHpDeficitTextR"),
    partyFrameHpDeficitColorComponent("partyFrameHpDeficitTextG"),
    partyFrameHpDeficitColorComponent("partyFrameHpDeficitTextB")
end

local function partyFrameHpDeficitBorderRGB()
  return partyFrameHpDeficitColorComponent("partyFrameHpDeficitBorderR"),
    partyFrameHpDeficitColorComponent("partyFrameHpDeficitBorderG"),
    partyFrameHpDeficitColorComponent("partyFrameHpDeficitBorderB")
end

--- Truncate long enemy / party names with a trailing "..." when the option is enabled. Length counts
--- *bytes*, which equals characters for the Latin mob names produced by Classic/Anniversary. Uses
--- three ASCII dots rather than the Unicode ellipsis (U+2026) because the default Vanilla font has
--- no glyph for U+2026 and renders it as a literal question mark.
function _EL.truncateName(name)
  if type(name) ~= "string" or name == "" then return name end
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  if not db.truncateLongNames then return name end
  local maxLen = tonumber(db.maxNameLength) or defaults.maxNameLength or 14
  if maxLen < 4 then maxLen = 4 end
  if #name <= maxLen then return name end
  return string.sub(name, 1, maxLen - 3) .. "..."
end

--- Generic RGB getter used by the configurable bar colors (health, aggro, cast, mana, party fallback, etc.).
--- |keyR|/|keyG|/|keyB| are the three DB keys; NaN guard because saved-value corruption produces NaN on some clients.
function _EL.colorRGB(keyR, keyG, keyB)
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local function c(k)
    local v = db[k]
    if type(v) ~= "number" or v ~= v then
      v = defaults[k]
    end
    return math.max(0, math.min(1, v or 1))
  end
  return c(keyR), c(keyG), c(keyB)
end

function _EL.enemyHpBarRGB()      return _EL.colorRGB("enemyHpBarR", "enemyHpBarG", "enemyHpBarB") end
function _EL.enemyAggroBarRGB()   return _EL.colorRGB("enemyAggroBarR", "enemyAggroBarG", "enemyAggroBarB") end
function _EL.enemyCastBarRGB()    return _EL.colorRGB("enemyCastBarR", "enemyCastBarG", "enemyCastBarB") end
function _EL.partyHpFallbackRGB() return _EL.colorRGB("partyHpFallbackR", "partyHpFallbackG", "partyHpFallbackB") end
function _EL.partyHpOOR_RGB()     return _EL.colorRGB("partyHpOutOfRangeR", "partyHpOutOfRangeG", "partyHpOutOfRangeB") end
function _EL.partyManaBarRGB()    return _EL.colorRGB("partyManaBarR", "partyManaBarG", "partyManaBarB") end

--- Debuff-strip DB keys for each dispel type ("Curse" / "Disease" / "Magic" / "Poison" / "Healing").
--- Inlined here rather than as a top-level local table to keep the main-chunk local budget free.
function _EL.debuffKeys(typ)
  if     typ == "Curse"   then return "debuffCurseR",   "debuffCurseG",   "debuffCurseB"
  elseif typ == "Disease" then return "debuffDiseaseR", "debuffDiseaseG", "debuffDiseaseB"
  elseif typ == "Magic"   then return "debuffMagicR",   "debuffMagicG",   "debuffMagicB"
  elseif typ == "Poison"  then return "debuffPoisonR",  "debuffPoisonG",  "debuffPoisonB"
  elseif typ == "Healing" then return "debuffHealingR", "debuffHealingG", "debuffHealingB"
  end
end

function _EL.debuffColorRGB(typ)
  local kR, kG, kB = _EL.debuffKeys(typ)
  if not kR then return 1, 1, 1 end
  return _EL.colorRGB(kR, kG, kB)
end

--- Profile-aware read/write. The Party and Raid tabs each target a specific profile name so the
--- user can edit raid settings while physically in a party (and vice-versa).
---
--- Invariant: |EnemyListDB[key]| mirrors whichever profile is currently active; per-profile
--- storage lives under |EnemyListDB.profiles[name][key]|. Writing to the *active* profile updates
--- both slots; writing to the inactive profile only updates the per-profile table (top-level keeps
--- showing what the game is currently using).
function _EL.profileRead(profileName, key)
  if type(EnemyListDB) ~= "table" then return defaults[key] end
  if EnemyListDB.activeProfileName == profileName and EnemyListDB[key] ~= nil then
    return EnemyListDB[key]
  end
  local p = EnemyListDB.profiles and EnemyListDB.profiles[profileName]
  if p and p[key] ~= nil then return p[key] end
  return defaults[key]
end

function _EL.profileWrite(profileName, key, value)
  if type(EnemyListDB) ~= "table" then return end
  if type(EnemyListDB.profiles) ~= "table" then EnemyListDB.profiles = {} end
  if type(EnemyListDB.profiles[profileName]) ~= "table" then
    EnemyListDB.profiles[profileName] = {}
  end
  EnemyListDB.profiles[profileName][key] = value
  if EnemyListDB.activeProfileName == profileName then
    EnemyListDB[key] = value
  end
end

function _EL.useClassColorsParty()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.useClassColorsParty ~= false
end

function _EL.showPartyManaBars()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.showPartyManaBars == true
end

function _EL.usePowerTypeColorsParty()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.usePowerTypeColorsParty ~= false
end

function _EL.showSelfAggroCount()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.showSelfAggroCount ~= false
end

--- Read an edge-position string ("bottom"/"top"/"left"/"right"), with a legacy fallback so a
--- user's old |partyHpBarVertical| toggle keeps working without a manual migration.
local function _elPartyBarPosition(posKey, legacyVerticalKey, horizontalDefault)
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = db[posKey]
  if type(v) == "string" and (v == "bottom" or v == "top" or v == "left" or v == "right") then
    return v
  end
  --- Migrate old boolean: legacy "vertical=true" used the right edge for HP, the left for mana;
  --- "vertical=false" was the classic horizontal stack (HP bottom, mana top).
  if db[legacyVerticalKey] == true then
    return (legacyVerticalKey == "partyManaBarVertical") and "left" or "right"
  end
  return horizontalDefault
end

function _EL.partyHpBarPosition()
  return _elPartyBarPosition("partyHpBarPosition", "partyHpBarVertical", "bottom")
end

function _EL.partyManaBarPosition()
  return _elPartyBarPosition("partyManaBarPosition", "partyManaBarVertical", "top")
end

--- Thin back-compat shims so any code still asking "is the bar vertical?" keeps working.
function _EL.partyHpBarVertical()
  local p = _EL.partyHpBarPosition()
  return p == "left" or p == "right"
end

function _EL.partyManaBarVertical()
  local p = _EL.partyManaBarPosition()
  return p == "left" or p == "right"
end

function _EL.partyFrameShowName()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyFrameShowName == true
end

--- |profileWrite| mirrors profile values into |EnemyListDB[key]| when the active profile matches,
--- so reading |EnemyListDB[key]| directly is the correct path for "current effective value." Earlier
--- versions of these helpers called |_EL.profileRead(nil, ...)|, which always returned |defaults[key]|
--- because |EnemyListDB.profiles[nil]| is just |nil|.
function _EL.partyShowRoleIcon()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyShowRoleIcon == true
end

--- Whether pet frames (|pet| / |partypetN| / |raidpetN|) should be laid out in the party/raid
--- container. Profile-scoped so users can show pets in party but hide them in raid (or vice versa).
function _EL.partyShowPets()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyShowPets == true
end

--- Whether to show icon strip of buffs cast BY THE PLAYER on each party/raid member.
function _EL.partyShowPlayerBuffs()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyShowPlayerBuffs == true
end

function _EL.partyPlayerBuffSlotCount()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyPlayerBuffSlotCount) or defaults.partyPlayerBuffSlotCount or 5
  return math.max(1, math.min(8, math.floor(v + 0.5)))
end

function _EL.partyPlayerBuffIconSize()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyPlayerBuffIconSize) or defaults.partyPlayerBuffIconSize or 14
  return math.max(8, math.min(32, math.floor(v + 0.5)))
end

--- Max base duration (seconds) for buffs to show. 0 = no filter. >0 hides anything longer (auras /
--- blessings / mark of the wild) and anything with no expiration.
function _EL.partyPlayerBuffMaxDuration()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyPlayerBuffMaxDuration) or defaults.partyPlayerBuffMaxDuration or 60
  return math.max(0, math.min(600, math.floor(v + 0.5)))
end

function _EL.partyPlayerBuffAnchor()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = db.partyPlayerBuffAnchor
  if v == "top" or v == "bottom" or v == "left" or v == "right" then return v end
  return "bottom"
end

local PLAYER_BUFF_OFFSET_MIN, PLAYER_BUFF_OFFSET_MAX = -50, 50
function _EL.partyPlayerBuffOffsetX()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyPlayerBuffOffsetX) or 0
  if v ~= v then v = 0 end
  return math.max(PLAYER_BUFF_OFFSET_MIN, math.min(PLAYER_BUFF_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyPlayerBuffOffsetY()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyPlayerBuffOffsetY) or 0
  if v ~= v then v = 0 end
  return math.max(PLAYER_BUFF_OFFSET_MIN, math.min(PLAYER_BUFF_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyRoleIconSize()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyRoleIconSize) or defaults.partyRoleIconSize or 12
  return math.max(6, math.min(32, v))
end

--- Resolve a unit's role for badge rendering. Returns "TANK" / "HEALER" / "DAMAGER" / nil.
--- Retail / LFG: |UnitGroupRolesAssigned| works. Classic / Anniversary lacks that API, so we fall
--- back to |GetPartyAssignment| ("MAINTANK" = tank). Everything else returns nil — the caller hides
--- the icon, which is the intended behavior when the player hasn't marked anyone.
function _EL.resolveUnitRole(unit)
  if not unit or not UnitExists(unit) then return nil end
  if type(UnitGroupRolesAssigned) == "function" then
    local r = UnitGroupRolesAssigned(unit)
    if r == "TANK" or r == "HEALER" or r == "DAMAGER" then return r end
  end
  if type(GetPartyAssignment) == "function" then
    local okTank = GetPartyAssignment("MAINTANK", unit)
    if okTank then return "TANK" end
  end
  return nil
end

function _EL.partyFrameNameFontScale()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyFrameNameFontScale) or defaults.partyFrameNameFontScale
  return math.max(0.5, math.min(2.0, v))
end

function _EL.partyFrameNamePosition()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = db.partyFrameNamePosition
  if v == "top" or v == "middle" or v == "bottom" then return v end
  return "top"
end

local NAME_OFFSET_MIN, NAME_OFFSET_MAX = -50, 50
function _EL.partyFrameNameOffsetX()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyFrameNameOffsetX) or 0
  if v ~= v then v = 0 end  --- NaN guard.
  return math.max(NAME_OFFSET_MIN, math.min(NAME_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyFrameNameOffsetY()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyFrameNameOffsetY) or 0
  if v ~= v then v = 0 end
  return math.max(NAME_OFFSET_MIN, math.min(NAME_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyShowIncomingHeals()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyShowIncomingHeals == true
end

function _EL.showRunnerUpBars()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.showRunnerUpBars == true
end

function _EL.runnerUpBarCount()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return math.max(1, math.min(5, math.floor(tonumber(db.runnerUpBarCount) or defaults.runnerUpBarCount)))
end

function _EL.runnerUpBarHeight()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return math.max(2, math.min(16, math.floor(tonumber(db.runnerUpBarHeight) or defaults.runnerUpBarHeight)))
end

--- Returns a table of { name, pct, isTanking } for the top |limit| threat holders on |unit|,
--- sorted desc by pct. The current aggro holder (tank) is included at the top, followed by the
--- runner-ups — so a tank reading the bars sees themself first then the DPS climbing behind them.
--- |UnitDetailedThreatSituation| is called for every group member so this works for anyone, not
--- just the local player. Missing API / no-group = empty result. Names are de-duplicated to guard
--- against a unit appearing under more than one token.
function _EL.computeRunnerUpThreats(unit, limit)
  limit = tonumber(limit) or 3
  if not unit or not UnitExists(unit) or type(UnitDetailedThreatSituation) ~= "function" then
    return {}
  end
  local members = { "player" }
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do members[#members + 1] = "raid" .. i end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do members[#members + 1] = "party" .. i end
  end
  local tmp = {}
  local seen = {}
  for _, m in ipairs(members) do
    if UnitExists(m) then
      local nm = UnitName(m)
      if nm and not seen[nm] then
        local ok, isTanking, _, pct, _, _ = pcall(UnitDetailedThreatSituation, m, unit)
        if ok and type(pct) == "number" and pct > 0 then
          tmp[#tmp + 1] = { name = nm, pct = pct, isTanking = isTanking and true or false }
          seen[nm] = true
        end
      end
    end
  end
  table.sort(tmp, function(a, b) return a.pct > b.pct end)
  local out = {}
  for i = 1, math.min(#tmp, limit) do
    out[i] = tmp[i]
  end
  return out
end

function _EL.partyShowAggroBorder()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyShowAggroBorder ~= false
end

function _EL.partyUseCustomAggroBorderColor()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyUseCustomAggroBorderColor == true
end

function _EL.partyAggroBorderRGB() return _EL.colorRGB("partyAggroBorderR", "partyAggroBorderG", "partyAggroBorderB") end

function _EL.partyAggroBorderThickness()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyAggroBorderThickness) or defaults.partyAggroBorderThickness
  return math.max(1, math.min(6, math.floor(v + 0.5)))
end

local AGGRO_COUNT_OFFSET_MIN, AGGRO_COUNT_OFFSET_MAX = -50, 50
function _EL.partyAggroCountOffsetX()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyAggroCountOffsetX) or 0
  if v ~= v then v = 0 end
  return math.max(AGGRO_COUNT_OFFSET_MIN, math.min(AGGRO_COUNT_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyAggroCountOffsetY()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = tonumber(db.partyAggroCountOffsetY) or 0
  if v ~= v then v = 0 end
  return math.max(AGGRO_COUNT_OFFSET_MIN, math.min(AGGRO_COUNT_OFFSET_MAX, math.floor(v + 0.5)))
end

function _EL.partyIncomingHealRGB() return _EL.colorRGB("partyIncomingHealR", "partyIncomingHealG", "partyIncomingHealB") end
function _EL.partySelfHealRGB()     return _EL.colorRGB("partySelfHealR",     "partySelfHealG",     "partySelfHealB")     end

--- Returns (totalIncoming, selfIncoming) in HP; zero when the API is missing or returns nil.
--- Splits self heals from raid heals so the overlay can tint them differently.
function _EL.partyIncomingHealAmounts(unit)
  if type(UnitGetIncomingHeals) ~= "function" or not unit then return 0, 0 end
  local total = 0
  local self_ = 0
  do
    local ok, v = pcall(UnitGetIncomingHeals, unit)
    if ok and type(v) == "number" and v > 0 then total = v end
  end
  do
    local ok, v = pcall(UnitGetIncomingHeals, unit, "player")
    if ok and type(v) == "number" and v > 0 then self_ = v end
  end
  return total, self_
end

function _EL.partyLowHpFlashEnabled()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyLowHpFlashEnabled == true
end

function _EL.partyLowHpThreshold()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return math.max(5, math.min(95, tonumber(db.partyLowHpThreshold) or defaults.partyLowHpThreshold))
end

function _EL.partyLowHpFlashRGB() return _EL.colorRGB("partyLowHpFlashR", "partyLowHpFlashG", "partyLowHpFlashB") end

function _EL.partyLowManaFlashEnabled()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return db.partyLowManaFlashEnabled == true
end

function _EL.partyLowManaThreshold()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  return math.max(5, math.min(95, tonumber(db.partyLowManaThreshold) or defaults.partyLowManaThreshold))
end

function _EL.partyLowManaFlashRGB() return _EL.colorRGB("partyLowManaFlashR", "partyLowManaFlashG", "partyLowManaFlashB") end

local PARTY_HP_DEFICIT_FONT_BASE_PX = 5
local PARTY_HP_DEFICIT_FONT_PX_MIN = 3
local PARTY_HP_DEFICIT_FONT_PX_MAX = 16

local function partyFrameHpDeficitFontScaleValue()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local sc = tonumber(db.partyFrameHpDeficitFontScale) or defaults.partyFrameHpDeficitFontScale
  return math.max(0.5, math.min(2.0, sc))
end

local function partyFrameHpDeficitFontPixelSize()
  return math.max(
    PARTY_HP_DEFICIT_FONT_PX_MIN,
    math.min(
      PARTY_HP_DEFICIT_FONT_PX_MAX,
      math.floor(PARTY_HP_DEFICIT_FONT_BASE_PX * partyFrameHpDeficitFontScaleValue() + 0.5)
    )
  )
end

local function applyPartyHpDeficitFontSize(uf)
  local fs = uf._elHpDeficitFs
  if not fs then
    return
  end
  local px = partyFrameHpDeficitFontPixelSize()
  pcall(function()
    local f0, _ = fs:GetFont()
    if f0 then
      fs:SetFont(f0, px, "")
    end
  end)
end

local function setPartyHpDeficitTextAllLayers(uf, txt)
  if uf._elHpDeficitFs then
    uf._elHpDeficitFs:SetText(txt)
  end
end

local function applyPartyHpDeficitColors(uf)
  local tr, tg, tb = partyFrameHpDeficitTextRGB()
  local br, bg, bb = partyFrameHpDeficitBorderRGB()
  if uf._elHpDeficitFs then
    uf._elHpDeficitFs:SetTextColor(tr, tg, tb)
    --- Single string: border color drives shadow (no stacked offset copies — avoids double-image ghosting).
    uf._elHpDeficitFs:SetShadowColor(br, bg, bb, 1)
    uf._elHpDeficitFs:SetShadowOffset(1, -1)
  end
end

local function syncPartyHpDeficitColorsOnAllFrames()
  for _, uf in ipairs(partyUnitFrames) do
    applyPartyHpDeficitColors(uf)
  end
end

local function refreshPartyHpDeficitColorSwatches()
  local cf = configFrame
  if not cf then
    return
  end
  if cf._elPartyHpDeficitTextSwatchTex then
    local r, g, b = partyFrameHpDeficitTextRGB()
    cf._elPartyHpDeficitTextSwatchTex:SetVertexColor(r, g, b)
  end
  if cf._elPartyHpDeficitBorderSwatchTex then
    local r, g, b = partyFrameHpDeficitBorderRGB()
    cf._elPartyHpDeficitBorderSwatchTex:SetVertexColor(r, g, b)
  end
end

--- Alpha for aggro count digit (RGB comes from color picker).
local PARTY_AGGRO_COUNT_TEXT_ALPHA = 0.9
local PARTY_AGGRO_COUNT_FONT_BASE_PX = 14
local PARTY_AGGRO_COUNT_FONT_PX_MIN = 8
local PARTY_AGGRO_COUNT_FONT_PX_MAX = 30

local function partyFrameAggroCountColorComponent(key)
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local v = db[key]
  if type(v) ~= "number" or v ~= v then
    return defaults[key]
  end
  return math.max(0, math.min(1, v))
end

local function partyFrameAggroCountTextRGB()
  return partyFrameAggroCountColorComponent("partyFrameAggroCountTextR"),
    partyFrameAggroCountColorComponent("partyFrameAggroCountTextG"),
    partyFrameAggroCountColorComponent("partyFrameAggroCountTextB")
end

local function partyFrameAggroCountFontScaleValue()
  local db = type(EnemyListDB) == "table" and EnemyListDB or defaults
  local sc = tonumber(db.partyFrameAggroCountFontScale) or defaults.partyFrameAggroCountFontScale
  return math.max(0.5, math.min(2.0, sc))
end

local function partyFrameAggroCountFontPixelSize()
  return math.max(
    PARTY_AGGRO_COUNT_FONT_PX_MIN,
    math.min(
      PARTY_AGGRO_COUNT_FONT_PX_MAX,
      math.floor(PARTY_AGGRO_COUNT_FONT_BASE_PX * partyFrameAggroCountFontScaleValue() + 0.5)
    )
  )
end

local function applyPartyAggroCountFontSize(uf)
  if not uf._elCountFs then
    return
  end
  local px = partyFrameAggroCountFontPixelSize()
  pcall(function()
    local f0, _ = uf._elCountFs:GetFont()
    if f0 then
      uf._elCountFs:SetFont(f0, px, "")
    end
  end)
end

local function applyPartyAggroCountColors(uf)
  if not uf._elCountFs then
    return
  end
  local r, g, b = partyFrameAggroCountTextRGB()
  uf._elCountFs:SetTextColor(r, g, b, PARTY_AGGRO_COUNT_TEXT_ALPHA)
end

local function syncPartyAggroCountStyleOnAllFrames()
  for _, uf in ipairs(partyUnitFrames) do
    applyPartyAggroCountFontSize(uf)
    applyPartyAggroCountColors(uf)
  end
end

local function refreshPartyAggroCountSwatch()
  local cf = configFrame
  if not cf or not cf._elPartyAggroCountSwatchTex then
    return
  end
  local r, g, b = partyFrameAggroCountTextRGB()
  cf._elPartyAggroCountSwatchTex:SetVertexColor(r, g, b)
end

--- Reapply configured bar colors to every existing enemy row / grid cell. Called when the user
--- picks a new color; otherwise layoutRows() applies them naturally on the next refresh cycle.
function _EL.reapplyEnemyBarColors()
  local hpR, hpG, hpB = _EL.enemyHpBarRGB()
  local agR, agG, agB = _EL.enemyAggroBarRGB()
  local cbR, cbG, cbB = _EL.enemyCastBarRGB()
  for _, r in ipairs(rowsAggro) do
    if r.hpBar and r.hpBar.SetStatusBarColor then r.hpBar:SetStatusBarColor(hpR, hpG, hpB, 0.4) end
    if r.castBar and r.castBar.SetStatusBarColor then r.castBar:SetStatusBarColor(cbR, cbG, cbB, 0.85) end
  end
  for _, r in ipairs(rowsOther) do
    if r.hpBar and r.hpBar.SetStatusBarColor then r.hpBar:SetStatusBarColor(hpR, hpG, hpB, 0.4) end
    if r.castBar and r.castBar.SetStatusBarColor then r.castBar:SetStatusBarColor(cbR, cbG, cbB, 0.85) end
  end
  for _, c in ipairs(gridCells) do
    if c.aggroBar and c.aggroBar.SetStatusBarColor then c.aggroBar:SetStatusBarColor(agR, agG, agB, 0.9) end
    if c.hpBar and c.hpBar.SetStatusBarColor then c.hpBar:SetStatusBarColor(hpR, hpG, hpB, 0.9) end
    if c.castBar and c.castBar.SetStatusBarColor then c.castBar:SetStatusBarColor(cbR, cbG, cbB, 1.0) end
  end
end

--- Lay out a party frame's HP and mana bars given each bar's edge position. Positions are
--- "bottom" | "top" | "left" | "right"; bottom/top imply horizontal, left/right imply vertical.
--- If both bars share the same edge, the second bar stacks next to the first along the edge's
--- perpendicular axis (e.g. both "bottom" = hp as the bottom strip, mana immediately above it).
function _EL.applyPartyBarLayout(uf)
  if not uf or not uf._elHpBar then return end
  local hp = uf._elHpBar
  local mana = uf._elManaBar
  local hpPos = _EL.partyHpBarPosition()
  local manaPos = _EL.partyManaBarPosition()
  local manaOn = _EL.showPartyManaBars()
  local hpSize = partyFrameHpBarHeightPx()
  local manaSize = math.max(2, math.min(40, tonumber(EnemyListDB and EnemyListDB.partyManaBarHeight) or defaults.partyManaBarHeight))
  local inset = 2

  --- Anchor a single bar to its edge. |stackOn| is the frame this bar should stack against
  --- (only used when both HP and mana chose the same edge — the second bar nests next to it).
  local function anchorBar(bar, pos, thickness, stackOn)
    bar:ClearAllPoints()
    if pos == "left" then
      bar:SetOrientation("VERTICAL")
      if stackOn then
        bar:SetPoint("TOPLEFT", stackOn, "TOPRIGHT", 1, 0)
        bar:SetPoint("BOTTOMLEFT", stackOn, "BOTTOMRIGHT", 1, 0)
      else
        bar:SetPoint("TOPLEFT", uf, "TOPLEFT", inset, -inset)
        bar:SetPoint("BOTTOMLEFT", uf, "BOTTOMLEFT", inset, inset)
      end
      bar:SetWidth(thickness)
    elseif pos == "right" then
      bar:SetOrientation("VERTICAL")
      if stackOn then
        bar:SetPoint("TOPRIGHT", stackOn, "TOPLEFT", -1, 0)
        bar:SetPoint("BOTTOMRIGHT", stackOn, "BOTTOMLEFT", -1, 0)
      else
        bar:SetPoint("TOPRIGHT", uf, "TOPRIGHT", -inset, -inset)
        bar:SetPoint("BOTTOMRIGHT", uf, "BOTTOMRIGHT", -inset, inset)
      end
      bar:SetWidth(thickness)
    elseif pos == "top" then
      bar:SetOrientation("HORIZONTAL")
      if stackOn then
        bar:SetPoint("TOPLEFT", stackOn, "BOTTOMLEFT", 0, -1)
        bar:SetPoint("TOPRIGHT", stackOn, "BOTTOMRIGHT", 0, -1)
      else
        bar:SetPoint("TOPLEFT", uf, "TOPLEFT", inset, -inset)
        bar:SetPoint("TOPRIGHT", uf, "TOPRIGHT", -inset, -inset)
      end
      bar:SetHeight(thickness)
    else  -- "bottom" (default)
      bar:SetOrientation("HORIZONTAL")
      if stackOn then
        bar:SetPoint("BOTTOMLEFT", stackOn, "TOPLEFT", 0, 1)
        bar:SetPoint("BOTTOMRIGHT", stackOn, "TOPRIGHT", 0, 1)
      else
        bar:SetPoint("BOTTOMLEFT", uf, "BOTTOMLEFT", inset, inset)
        bar:SetPoint("BOTTOMRIGHT", uf, "BOTTOMRIGHT", -inset, inset)
      end
      bar:SetHeight(thickness)
    end
  end

  anchorBar(hp, hpPos, hpSize, nil)
  if mana then
    anchorBar(mana, manaPos, manaSize, hpPos == manaPos and hp or nil)
    --- Visibility is owned by |_EL.updatePartyUnitFrame| (which also checks whether the unit has
    --- a primary power > 0). This helper used to |SetShown(manaOn)| too, but that raced the next
    --- update tick and produced a visible flash every 0.25s when the bar ended up hidden anyway.
    --- If the config toggle is off, hide it here so a freshly-positioned bar doesn't pop in for
    --- one frame before update() hides it; otherwise leave it alone.
    if not manaOn then mana:Hide() end
  end
end

--- Reapply party HP / mana colors across every mounted party frame. |_EL.updatePartyUnitFrame| is
--- assigned later in the file; table lookup is deferred to call time, so ordering doesn't matter.
function _EL.reapplyPartyBarColors()
  for _, uf in ipairs(partyUnitFrames) do
    if uf and uf._elUnit and UnitExists(uf._elUnit) then
      if _EL.updatePartyUnitFrame then _EL.updatePartyUnitFrame(uf) end
    end
  end
end

function updatePartyFrameSize()
  if not partyFrameContainer then return end
  --- Everything below touches |SetPoint| / |SetSize| on secure children (the uf buttons) and on
  --- the container. Blocked during combat — most callers already guard, but keep a belt-and-
  --- braces early return so anything that forgets doesn't spam "ADDON BLOCKED".
  if InCombatLockdown and InCombatLockdown() then return end
  local sz = math.max(25, math.min(80, tonumber(EnemyListDB.partyFrameSize) or defaults.partyFrameSize))
  local gap = math.max(0, math.min(10, tonumber(EnemyListDB.partyFrameUnitGap) or defaults.partyFrameUnitGap))
  local groupGap = math.max(0, math.min(20, tonumber(EnemyListDB.partyFrameGroupGap) or defaults.partyFrameGroupGap))
  local vertical = EnemyListDB and EnemyListDB.partyFrameVertical
  local isTestMode = type(EnemyListDB) == "table" and EnemyListDB.testMode
  --- In a real raid, |player| and |party1-4| are the same people as |raid1+| roster entries.
  --- Laying them out as subgroup 1 (old default) stacked them on top of raid column 1 → e.g. 10 icons in “group 1”.
  local inRaid = false
  if not isTestMode and IsInRaid then
    inRaid = IsInRaid() and true or false
  end

  --- Collect only visible/existing units, grouped by raid subgroup.
  --- group[n] = list of unit frame references in that group.
  local showPets = _EL.partyShowPets()
  local function isPetUnit(u)
    if type(u) ~= "string" then return false end
    return u == "pet" or u:match("^partypet%d+$") or u:match("^raidpet%d+$")
  end
  --- Test mode: scope the preview to the active profile's group size, otherwise all 90 frames
  --- (player + party + pet + partypet + 40 raid + 40 raidpet) flood the screen and the party
  --- config tab looks broken. Party profile shows player+party1-4+pets; Raid shows raid1-40+pets.
  local activeProfile = (type(EnemyListDB) == "table" and EnemyListDB.activeProfileName) or "party"
  local function inActiveTestProfile(u)
    if not isTestMode then return true end
    if activeProfile == "raid" then
      return type(u) == "string" and (u:match("^raid%d") and not u:match("^raidpet")) or (u and u:match("^raidpet%d"))
    end
    --- Party / custom profiles preview as 5-man.
    return u == "player" or (type(u) == "string" and (u:match("^party%d+$") or u == "pet" or u:match("^partypet%d+$")))
  end
  local groups = {}
  for fi, uf in ipairs(partyUnitFrames) do
    local unit = uf._elUnit
    local petUnit = isPetUnit(unit)
    local exists = isTestMode or (unit and UnitExists(unit))
    --- Pet frames are skipped unless the toggle is on.
    if petUnit and not showPets then exists = false end
    --- Test mode: filter to profile-appropriate units only.
    if isTestMode and not inActiveTestProfile(unit) then exists = false end
    --- Omit player/party slots from the raid grid; only |raidN| frames represent the roster.
    local skipDuplicateRosterSlot = inRaid and unit
      and (unit == "player" or (type(unit) == "string" and unit:match("^party%d+$")))
    if exists and not skipDuplicateRosterSlot then
      --- Test mode: force-show frames that RegisterUnitWatch would hide.
      if isTestMode and not uf:IsShown() and not InCombatLockdown() then
        UnregisterUnitWatch(uf)
        uf:Show()
        uf._elTestShown = true
      end
      --- Determine raid subgroup (1-based). Party / solo: everyone in logical group 1. Pets follow
      --- their owner's group: |raidpetN| → subgroup of |raidN|; |pet| / |partypetN| → group 1.
      local subgroup = 1
      if isTestMode then
        if unit == "pet" or (type(unit) == "string" and unit:match("^partypet%d+$")) then
          --- Owner is player / partyN → group 1 in test mode (same as the 5-man party block).
          subgroup = 1
        elseif type(unit) == "string" and unit:match("^raidpet%d+$") then
          --- Mirror raidN's test subgroup. Test mode buckets raid units by the same |fi/5| math, so
          --- compute the raid index → its fi (11 + N - 1) → its bucket.
          local raidIdx = tonumber(unit:match("^raidpet(%d+)$")) or 1
          local ownerFi = 10 + raidIdx
          subgroup = math.floor((ownerFi - 1) / 5) + 1
        else
          subgroup = math.floor((fi - 1) / 5) + 1
        end
      elseif unit and unit:match("^raid%d") and not unit:match("^raidpet") then
        local raidIdx = tonumber(unit:match("^raid(%d+)$"))
        if raidIdx and GetRaidRosterInfo then
          local ok, _, _, sg = pcall(GetRaidRosterInfo, raidIdx)
          if ok and type(sg) == "number" and sg >= 1 then subgroup = sg end
        end
      elseif unit and unit:match("^raidpet%d") then
        local raidIdx = tonumber(unit:match("^raidpet(%d+)$"))
        if raidIdx and GetRaidRosterInfo then
          local ok, _, _, sg = pcall(GetRaidRosterInfo, raidIdx)
          if ok and type(sg) == "number" and sg >= 1 then subgroup = sg end
        end
      end
      if not groups[subgroup] then groups[subgroup] = { members = {}, pets = {} } end
      local bucket = petUnit and groups[subgroup].pets or groups[subgroup].members
      bucket[#bucket + 1] = uf
    elseif skipDuplicateRosterSlot and exists then
      --- Park duplicate roster UI off-screen (same as unused slots).
      uf:ClearAllPoints()
      uf:SetPoint("CENTER", UIParent, "CENTER", -9999, -9999)
      uf:SetSize(1, 1)
    else
      --- Re-register unit watch if leaving test mode.
      if uf._elTestShown and not InCombatLockdown() then
        uf._elTestShown = nil
        RegisterUnitWatch(uf)
      end
      --- Hide and move off-screen.
      uf:ClearAllPoints()
      uf:SetPoint("CENTER", UIParent, "CENTER", -9999, -9999)
      uf:SetSize(1, 1)
    end
  end

  --- Sort group keys and lay out. Each group has a |members| list and a |pets| list. Members fill
  --- the primary lane (column for vertical layout, row for horizontal); pets occupy a secondary lane
  --- right after, separated by a small extra |petGap| so they read as a distinct strip.
  local sortedGroups = {}
  for g in pairs(groups) do sortedGroups[#sortedGroups + 1] = g end
  table.sort(sortedGroups)

  local maxPerGroup = 0
  local maxPetsPerGroup = 0
  for _, g in ipairs(sortedGroups) do
    local gd = groups[g]
    maxPerGroup = math.max(maxPerGroup, #gd.members)
    maxPetsPerGroup = math.max(maxPetsPerGroup, #gd.pets)
  end
  local petGap = (maxPetsPerGroup > 0) and math.max(gap + 4, 6) or 0

  --- Use actual group number (1-based) as the position index so empty groups leave gaps.
  local maxGroupNum = 0
  for _, g in ipairs(sortedGroups) do
    local gd = groups[g]
    local members = gd.members
    local pets    = gd.pets
    local gPos = g - 1  -- 0-based position matching the group number
    for m, uf in ipairs(members) do
      uf:SetSize(sz, sz)
      uf:ClearAllPoints()
      if vertical then
        local x = gPos * (sz + groupGap)
        local y = -((m - 1) * (sz + gap))
        uf:SetPoint("TOPLEFT", partyFrameContainer, "TOPLEFT", x, y)
      else
        local x = (m - 1) * (sz + gap)
        local y = -(gPos * (sz + groupGap))
        uf:SetPoint("TOPLEFT", partyFrameContainer, "TOPLEFT", x, y)
      end
    end
    --- Pet strip: separated by |petGap| from members so it reads as its own row/column. Pets lay
    --- out in the same direction as members but in the lane right after the longest member lane.
    --- Vertical layout: pets stack to the RIGHT of the member column.
    --- Horizontal layout: pets stack BELOW the member row.
    for p, uf in ipairs(pets) do
      uf:SetSize(sz, sz)
      uf:ClearAllPoints()
      if vertical then
        local x = gPos * (sz + groupGap) + sz + petGap
        local y = -((p - 1) * (sz + gap))
        uf:SetPoint("TOPLEFT", partyFrameContainer, "TOPLEFT", x, y)
      else
        local x = (p - 1) * (sz + gap)
        local y = -(gPos * (sz + groupGap)) - sz - petGap
        uf:SetPoint("TOPLEFT", partyFrameContainer, "TOPLEFT", x, y)
      end
    end
    maxGroupNum = math.max(maxGroupNum, g)
  end

  if maxGroupNum == 0 then maxGroupNum = 1 end
  if maxPerGroup == 0 then maxPerGroup = 1 end
  --- Container size accounts for the optional pet strip width (vertical) or height (horizontal).
  local memberExtent = maxPerGroup * sz + (maxPerGroup - 1) * gap
  local petExtent    = maxPetsPerGroup > 0 and (maxPetsPerGroup * sz + (maxPetsPerGroup - 1) * gap) or 0
  local groupExtent  = maxGroupNum * (sz + groupGap) - groupGap
  if vertical then
    --- Vertical: each "group" is a column; pets sit beside members (extra column width per group).
    local groupColW = sz + (maxPetsPerGroup > 0 and (sz + petGap) or 0)
    local totalW    = maxGroupNum * (groupColW + groupGap) - groupGap
    partyFrameContainer:SetSize(totalW, math.max(memberExtent, petExtent))
  else
    --- Horizontal: each "group" is a row; pets sit below the row.
    local groupRowH = sz + (maxPetsPerGroup > 0 and (sz + petGap) or 0)
    local totalH    = maxGroupNum * (groupRowH + groupGap) - groupGap
    partyFrameContainer:SetSize(math.max(memberExtent, petExtent), totalH)
  end
  if syncPartyFrameUnitChrome then
    syncPartyFrameUnitChrome()
  end
end

--- Party debuff strip: curse (purple), disease (yellow), magic (blue), poison (green), healing reduction (red).
--- Healing slot: known spell IDs that reduce healing (Mortal Strike, etc.) when the aura is not curse/disease/magic/poison.
--- Each cell shows shortest remaining duration in whole seconds, only for 1–9 (otherwise blank).
local PARTY_DEBUFF_SLOT_COUNT = 5
local PARTY_DEBUFF_TYPES = { "Curse", "Disease", "Magic", "Poison", "Healing" }
local PARTY_DEBUFF_COLORS = {
  Curse = { 0.55, 0.28, 0.88 },
  Disease = { 0.92, 0.82, 0.18 },
  Magic = { 0.22, 0.55, 1.0 },
  Poison = { 0.25, 0.88, 0.35 },
  Healing = { 0.92, 0.22, 0.22 },
}

--- Spell IDs that reduce healing received; red slot only if debuff is not classified as curse/disease/magic/poison.
--- Derived from LibHealComm-style data + common ranks (extend as needed for your client).
local PARTY_HEALING_REDUCTION_SPELL_IDS = {
  [28776] = true,
  [36693] = true,
  [46296] = true,
  [19716] = true,
  [13737] = true,
  [15708] = true,
  [16856] = true,
  [17547] = true,
  [19643] = true,
  [24573] = true,
  [27580] = true,
  [29572] = true,
  [31911] = true,
  [32736] = true,
  [35054] = true,
  [37335] = true,
  [39171] = true,
  [40220] = true,
  [44268] = true,
  [12294] = true,
  [21551] = true,
  [21552] = true,
  [21553] = true,
  [25248] = true,
  [30330] = true,
  [43441] = true,
  [23894] = true,
  [25286] = true,
  [47486] = true,
  [30843] = true,
  [19434] = true,
  [20900] = true,
  [20901] = true,
  [20902] = true,
  [20903] = true,
  [20904] = true,
  [27065] = true,
  [34625] = true,
  [35189] = true,
  [32315] = true,
  [32378] = true,
  [36917] = true,
  [44534] = true,
  [34366] = true,
  [36023] = true,
  [36054] = true,
  [45885] = true,
  [41292] = true,
  [40599] = true,
  [9035] = true,
  [19281] = true,
  [19282] = true,
  [19283] = true,
  [19284] = true,
  [25470] = true,
  [34073] = true,
  [31306] = true,
  [44475] = true,
  [23169] = true,
  [22859] = true,
  [38572] = true,
  [39595] = true,
  [45996] = true,
  [7068] = true,
  [17820] = true,
  [22687] = true,
  [23224] = true,
  [24674] = true,
  [28440] = true,
  [13583] = true,
  [23230] = true,
  [25646] = true,
  [28467] = true,
  [30641] = true,
  [31464] = true,
  [36814] = true,
  [38770] = true,
  [45347] = true,
  [30423] = true,
}

local function partyDebuffSlotForDispelType(dtype)
  if not dtype or type(dtype) ~= "string" or dtype == "" then
    return nil
  end
  local d = dtype:lower()
  for idx = 1, 4 do
    local key = PARTY_DEBUFF_TYPES[idx]
    if d == key:lower() then
      return idx
    end
  end
  return nil
end

local function partyCollectDispelState(unit)
  local now = GetTime()
  local has = { false, false, false, false, false }
  local minLeft = { math.huge, math.huge, math.huge, math.huge, math.huge }
  local function noteSlot(idx, duration, expirationTime)
    if not idx or idx < 1 or idx > PARTY_DEBUFF_SLOT_COUNT then
      return
    end
    has[idx] = true
    if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" and expirationTime > 0 then
      local left = expirationTime - now
      if left > 0 and left < minLeft[idx] then
        minLeft[idx] = left
      end
    end
  end
  local function processAura(debuffType, duration, expirationTime, spellId)
    if debuffType == "" then
      debuffType = nil
    end
    local dispelIdx = partyDebuffSlotForDispelType(debuffType)
    if dispelIdx then
      noteSlot(dispelIdx, duration, expirationTime)
    end
    if type(spellId) == "number" and spellId > 0 and PARTY_HEALING_REDUCTION_SPELL_IDS[spellId] then
      if not dispelIdx then
        noteSlot(5, duration, expirationTime)
      end
    end
  end
  if unit and UnitExists(unit) then
    --- |matches| counts how many auras the AuraUtil path actually classified into a slot. Some
    --- clients (Classic Era / Anniversary) expose AuraUtil.ForEachAura but hand out UnitAuraInfo
    --- tables that lack |dispelName| — pcall succeeds, we iterate auras, but nothing matches and
    --- we'd never fall back to UnitDebuff. Track hits so we can fall back when the modern path
    --- ran without producing useful data.
    local usedAuraUtil, matches = false, 0
    local function countingProcess(debuffType, duration, expirationTime, spellId)
      local before = 0
      for i = 1, PARTY_DEBUFF_SLOT_COUNT do if has[i] then before = before + 1 end end
      processAura(debuffType, duration, expirationTime, spellId)
      local after = 0
      for i = 1, PARTY_DEBUFF_SLOT_COUNT do if has[i] then after = after + 1 end end
      if after > before then matches = matches + 1 end
    end
    if AuraUtil and AuraUtil.ForEachAura then
      local ok = pcall(function()
        AuraUtil.ForEachAura(unit, "HARMFUL", nil, function(aura)
          --- Read under all known field names so Classic/Anniversary (|debuffType|/|dispelType|)
          --- and Retail (|dispelName|) both work.
          local typ = aura.dispelName or aura.debuffType or aura.dispelType
          countingProcess(typ, aura.duration, aura.expirationTime, aura.spellId)
        end)
      end)
      usedAuraUtil = ok
    end
    if not usedAuraUtil or matches == 0 then
      local a = 1
      while a <= 45 do
        local name, icon, count, debuffType, duration, expirationTime, c7, c8, c9, spellId
        local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12 = pcall(function()
          return UnitDebuff(unit, a)
        end)
        if ok then
          name, icon, count, debuffType, duration, expirationTime = r1, r2, r3, r4, r5, r6
          spellId = (type(r10) == "number" and r10 > 100) and r10 or nil
          if not spellId and type(r11) == "number" and r11 > 100 then
            spellId = r11
          end
          if not spellId and type(r12) == "number" and r12 > 100 then
            spellId = r12
          end
        end
        if not name then
          break
        end
        processAura(debuffType, duration, expirationTime, spellId)
        a = a + 1
      end
    end
  end
  return has, minLeft
end

local function layoutPartyDispelRow(uf)
  if not uf._elDispelRow or not uf._elDispelSq then
    return
  end
  local w = uf:GetWidth() or 40
  local rowH = math.max(6, math.min(12, math.floor(w * 0.23 + 0.5)))
  local pad = 2
  local gap = 1
  local inner = math.max(8, w - pad * 2)
  local n = PARTY_DEBUFF_SLOT_COUNT
  local sqW = math.max(3, math.floor((inner - gap * (n - 1)) / n + 0.5))
  uf._elDispelRow:ClearAllPoints()
  uf._elDispelRow:SetPoint("TOPLEFT", uf, "TOPLEFT", pad, -pad)
  uf._elDispelRow:SetSize(inner, rowH)
  local x = 0
  for i = 1, n do
    local cell = uf._elDispelSq[i]
    if cell and cell.frame then
      cell.frame:ClearAllPoints()
      cell.frame:SetSize(sqW, rowH)
      cell.frame:SetPoint("TOPLEFT", uf._elDispelRow, "TOPLEFT", x, 0)
      x = x + sqW + gap
    end
  end
  --- Countdown digits: ~half the old fixed size, scales slightly with row height.
  local countSz = math.max(4, math.min(6, math.floor(rowH * 0.42 / 2 + 0.5)))
  for di = 1, PARTY_DEBUFF_SLOT_COUNT do
    local cell = uf._elDispelSq[di]
    if cell and cell.fs then
      pcall(function()
        local f0, _ = cell.fs:GetFont()
        if f0 then
          cell.fs:SetFont(f0, countSz, "OUTLINE")
        end
      end)
    end
  end
end

hidePartyDispelIndicators = function(uf)
  if not uf._elDispelSq then
    return
  end
  for i = 1, PARTY_DEBUFF_SLOT_COUNT do
    local cell = uf._elDispelSq[i]
    if cell and cell.frame then
      cell.frame:Hide()
      if cell.fs then
        cell.fs:SetText("")
      end
    end
  end
end

--- Position the player-buff strip on one of the four edges of the unit frame, with optional pixel
--- offsets. "top" / "bottom" run icons left-to-right (horizontal); "left" / "right" stack them
--- top-to-bottom (vertical). Icons shrink automatically when the frame is too small to fit them all.
local function layoutPartyPlayerBuffRow(uf)
  if not uf._elPlayerBuffRow or not uf._elPlayerBuffSlots then return end
  local n = _EL.partyPlayerBuffSlotCount()
  local iconSz = _EL.partyPlayerBuffIconSize()
  local anchor = _EL.partyPlayerBuffAnchor()
  local ox = _EL.partyPlayerBuffOffsetX()
  local oy = _EL.partyPlayerBuffOffsetY()
  local pad = 2
  local gap = 1
  local fw = uf:GetWidth() or 40
  local fh = uf:GetHeight() or 40
  local horizontal = (anchor == "top" or anchor == "bottom")
  local mainExtent = horizontal and math.max(8, fw - pad * 2) or math.max(8, fh - pad * 2)
  local maxFit = math.max(1, math.floor((mainExtent + gap) / (iconSz + gap)))
  if n > maxFit then iconSz = math.max(8, math.floor((mainExtent - gap * (n - 1)) / n)) end
  uf._elPlayerBuffRow:ClearAllPoints()
  if anchor == "top" then
    uf._elPlayerBuffRow:SetPoint("TOPLEFT", uf, "TOPLEFT", pad + ox, -pad + oy)
    uf._elPlayerBuffRow:SetSize(mainExtent, iconSz)
  elseif anchor == "bottom" then
    uf._elPlayerBuffRow:SetPoint("BOTTOMLEFT", uf, "BOTTOMLEFT", pad + ox, pad + oy)
    uf._elPlayerBuffRow:SetSize(mainExtent, iconSz)
  elseif anchor == "left" then
    uf._elPlayerBuffRow:SetPoint("TOPLEFT", uf, "TOPLEFT", pad + ox, -pad + oy)
    uf._elPlayerBuffRow:SetSize(iconSz, mainExtent)
  else  -- right
    uf._elPlayerBuffRow:SetPoint("TOPRIGHT", uf, "TOPRIGHT", -pad + ox, -pad + oy)
    uf._elPlayerBuffRow:SetSize(iconSz, mainExtent)
  end
  --- Highest level on the unit so icons paint above HP / mana fills (StatusBar children sit at +1).
  uf._elPlayerBuffRow:SetFrameLevel((uf:GetFrameLevel() or 0) + 8)
  for i = 1, 8 do
    local cell = uf._elPlayerBuffSlots[i]
    if cell and cell.frame then
      cell.frame:ClearAllPoints()
      if i <= n then
        cell.frame:SetSize(iconSz, iconSz)
        local off = (i - 1) * (iconSz + gap)
        if anchor == "top" then
          cell.frame:SetPoint("TOPLEFT", uf._elPlayerBuffRow, "TOPLEFT", off, 0)
        elseif anchor == "bottom" then
          cell.frame:SetPoint("BOTTOMLEFT", uf._elPlayerBuffRow, "BOTTOMLEFT", off, 0)
        elseif anchor == "left" then
          cell.frame:SetPoint("TOPLEFT", uf._elPlayerBuffRow, "TOPLEFT", 0, -off)
        else  -- right
          cell.frame:SetPoint("TOPRIGHT", uf._elPlayerBuffRow, "TOPRIGHT", 0, -off)
        end
      else
        cell.frame:Hide()
      end
    end
  end
  --- Scale the small text to icon size (countdown digits + stack count).
  local textSz = math.max(6, math.floor(iconSz * 0.45))
  for i = 1, 8 do
    local cell = uf._elPlayerBuffSlots[i]
    if cell then
      pcall(function()
        local f0 = cell.cd:GetFont()
        if f0 then cell.cd:SetFont(f0, textSz, "OUTLINE") end
      end)
      pcall(function()
        local f0 = cell.count:GetFont()
        if f0 then cell.count:SetFont(f0, textSz, "OUTLINE") end
      end)
    end
  end
end

--- Iterate buffs on |unit| and populate up to |slotCount| icons for those cast by the player.
--- Called from |_EL.updatePartyUnitFrame|. Hides the strip entirely when the option is off, so the
--- rest of the frame layout doesn't have to know about it.
local function updatePartyPlayerBuffs(uf)
  if not uf or not uf._elPlayerBuffSlots then return end
  if not _EL.partyShowPlayerBuffs() then
    for i = 1, 8 do
      local cell = uf._elPlayerBuffSlots[i]
      if cell and cell.frame then cell.frame:Hide() end
    end
    if uf._elPlayerBuffRow then uf._elPlayerBuffRow:Hide() end
    return
  end
  uf._elPlayerBuffRow:Show()
  layoutPartyPlayerBuffRow(uf)
  local unit = uf._elUnit
  if not unit or not UnitExists(unit) then
    for i = 1, 8 do
      local cell = uf._elPlayerBuffSlots[i]
      if cell and cell.frame then cell.frame:Hide() end
    end
    return
  end
  local n = _EL.partyPlayerBuffSlotCount()
  local maxDur = _EL.partyPlayerBuffMaxDuration()  --- 0 means "show all"
  local now = GetTime()
  local found = 0
  --- Walk auras until UnitBuff returns nil (Vanilla style). Filter to caster == "player". When
  --- |maxDur| is set, also drop anything with a base duration longer than that, plus permanent
  --- (duration == 0) buffs — those are auras / blessings / Mark of the Wild that don't need to
  --- be tracked for refreshing.
  local idx = 1
  while idx <= 40 and found < n do
    local name, icon, count, _, duration, expirationTime, source
    local ok, r1, r2, r3, r4, r5, r6, r7 = pcall(UnitBuff, unit, idx)
    if ok then
      name, icon, count, _, duration, expirationTime, source = r1, r2, r3, r4, r5, r6, r7
    end
    if not name then break end
    local durationOk = true
    if maxDur > 0 then
      if type(duration) ~= "number" or duration <= 0 or duration > maxDur then
        durationOk = false
      end
    end
    if source == "player" and durationOk then
      found = found + 1
      local cell = uf._elPlayerBuffSlots[found]
      if cell and cell.frame then
        cell.frame:Show()
        if icon then cell.icon:SetTexture(icon) end
        if type(count) == "number" and count > 1 then
          cell.count:SetText(tostring(count))
        else
          cell.count:SetText("")
        end
        if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" then
          local left = expirationTime - now
          if left > 0 then
            if left >= 60 then
              cell.cd:SetText(math.floor(left / 60 + 0.5) .. "m")
            elseif left >= 10 then
              cell.cd:SetText(math.floor(left + 0.5))
            else
              cell.cd:SetText(string.format("%.1f", left))
            end
          else
            cell.cd:SetText("")
          end
        else
          cell.cd:SetText("")
        end
      end
    end
    idx = idx + 1
  end
  for i = found + 1, 8 do
    local cell = uf._elPlayerBuffSlots[i]
    if cell and cell.frame then cell.frame:Hide() end
  end
end
_EL.updatePartyPlayerBuffs = updatePartyPlayerBuffs

applyPartyFrameAggroAttackedChrome = function()
  if not partyFrameContainer or not partyFrameContainer:IsShown() then
    return
  end
  local showSelf       = _EL.showSelfAggroCount()
  local showBorder     = _EL.partyShowAggroBorder()
  local useCustomColor = _EL.partyUseCustomAggroBorderColor()
  local customR, customG, customB
  if useCustomColor then customR, customG, customB = _EL.partyAggroBorderRGB() end
  local thickness      = _EL.partyAggroBorderThickness()
  for _, uf in ipairs(partyUnitFrames) do
    local idx = uf._elColorIdx
    local count = idx and partyMemberAttacked[idx] or 0
    --- |isSelfFrame| is the frame that currently represents the player (uf._elUnit == "player"
    --- in party mode, or the raidN token the player occupies in raid mode). The bg/border still
    --- light up to show you're being attacked; only the digit is suppressed when |showSelf| is off.
    local isSelfFrame = uf._elUnit and UnitExists(uf._elUnit) and UnitIsUnit(uf._elUnit, "player")
    if count > 0 then
      local c = PARTY_COLORS[idx]
      if c and uf._elBg then
        uf._elBg:SetColorTexture(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.9)
      end
      if uf._elBorders then
        --- Border horizontal strips use |SetHeight| for thickness; vertical strips use |SetWidth|.
        --- The four edge textures were created in a fixed order (top, bottom, left, right). Indexes
        --- 1/2 are horizontal bars, 3/4 are vertical bars.
        for i, edge in ipairs(uf._elBorders) do
          if showBorder then
            local er, eg, eb
            if useCustomColor then
              er, eg, eb = customR, customG, customB
            elseif c then
              er, eg, eb = c[1], c[2], c[3]
            end
            if er then edge:SetColorTexture(er, eg, eb, 1) end
          else
            --- Keep the idle border tint even when attacked, so the user opted out of the
            --- flashing-color reveal.
            edge:SetColorTexture(0.3, 0.3, 0.3, 0.4)
          end
          if i <= 2 then
            edge:SetHeight(thickness)
          else
            edge:SetWidth(thickness)
          end
        end
      end
      if uf._elCountFs then
        if isSelfFrame and not showSelf then
          uf._elCountFs:Hide()
        else
          uf._elCountFs:SetText(tostring(count))
          uf._elCountFs:Show()
        end
      end
    else
      if uf._elBg then
        uf._elBg:SetColorTexture(0.08, 0.08, 0.1, 0.85)
      end
      if uf._elBorders then
        for i, edge in ipairs(uf._elBorders) do
          edge:SetColorTexture(0.3, 0.3, 0.3, 0.4)
          if i <= 2 then
            edge:SetHeight(thickness)
          else
            edge:SetWidth(thickness)
          end
        end
      end
      if uf._elCountFs then
        uf._elCountFs:Hide()
      end
    end
  end
end

syncPartyFrameUnitChrome = function()
  for _, uf in ipairs(partyUnitFrames) do
    --- Bar orientation + dimensions. Replaces the old raw |SetHeight(hpBar)| because orientation
    --- affects which axis the bar-thickness applies to.
    _EL.applyPartyBarLayout(uf)
    local showDef = partyFrameHpDeficitEnabled()
    if uf._elHpDeficitFs then
      applyPartyHpDeficitFontSize(uf)
      uf._elHpDeficitFs:SetShown(showDef)
      if not showDef then
        setPartyHpDeficitTextAllLayers(uf, "")
      else
        applyPartyHpDeficitColors(uf)
      end
    end
    local showDeb = partyFrameDebuffsEnabled()
    if uf._elDispelRow then
      if showDeb then
        uf._elDispelRow:Show()
      else
        uf._elDispelRow:Hide()
        hidePartyDispelIndicators(uf)
      end
    end
    if uf._elCountFs then
      applyPartyAggroCountFontSize(uf)
      applyPartyAggroCountColors(uf)
      --- Re-anchor with configured pixel offset (base = center of the count overlay).
      local cx, cy = _EL.partyAggroCountOffsetX(), _EL.partyAggroCountOffsetY()
      local parentRef = uf._elCountOverlay or uf
      uf._elCountFs:ClearAllPoints()
      uf._elCountFs:SetPoint("CENTER", parentRef, "CENTER", cx, cy)
    end
    --- Name overlay visibility + font scale + anchor position (top clashes with the debuff strip;
    --- healers usually want bottom, pvpers often prefer middle when debuffs are off).
    if uf._elNameFs then
      local show = _EL.partyFrameShowName()
      uf._elNameFs:SetShown(show)
      local parentRef = uf._elTopOverlay or uf
      uf._elNameFs:ClearAllPoints()
      local pos = _EL.partyFrameNamePosition()
      local ox, oy = _EL.partyFrameNameOffsetX(), _EL.partyFrameNameOffsetY()
      if pos == "bottom" then
        uf._elNameFs:SetPoint("BOTTOM", parentRef, "BOTTOM", ox, 2 + oy)
        uf._elNameFs:SetJustifyV("BOTTOM")
      elseif pos == "middle" then
        uf._elNameFs:SetPoint("CENTER", parentRef, "CENTER", ox, oy)
        uf._elNameFs:SetJustifyV("MIDDLE")
      else
        uf._elNameFs:SetPoint("TOP", parentRef, "TOP", ox, -2 + oy)
        uf._elNameFs:SetJustifyV("TOP")
      end
      if show then
        pcall(function()
          local f0, _ = uf._elNameFs:GetFont()
          if f0 then
            local base = 10
            local px = math.max(6, math.min(24, math.floor(base * _EL.partyFrameNameFontScale() + 0.5)))
            uf._elNameFs:SetFont(f0, px, "OUTLINE")
          end
        end)
      end
    end
  end
end

local function applyPartyDispelState(uf, has, minLeft)
  if not uf._elDispelSq then
    return
  end
  for i = 1, PARTY_DEBUFF_SLOT_COUNT do
    local cell = uf._elDispelSq[i]
    local typ = PARTY_DEBUFF_TYPES[i]
    if cell and cell.frame and cell.tex and cell.fs and typ then
      if not has[i] then
        cell.frame:Hide()
        cell.fs:SetText("")
      else
        cell.frame:Show()
        local cr, cg, cb = _EL.debuffColorRGB(typ)
        cell.tex:SetVertexColor(cr, cg, cb, 0.92)
        local m = minLeft[i]
        local txt = ""
        if m ~= math.huge and m > 0 then
          local sec = math.ceil(m)
          if sec >= 1 and sec <= 9 then
            txt = tostring(sec)
          end
        end
        cell.fs:SetText(txt)
      end
    end
  end
end

local function updatePartyDispelIndicators(uf)
  if not uf._elDispelRow or not uf._elDispelSq then
    return
  end
  if not partyFrameDebuffsEnabled() then
    uf._elDispelRow:Hide()
    hidePartyDispelIndicators(uf)
    return
  end
  uf._elDispelRow:Show()
  layoutPartyDispelRow(uf)
  local unit = uf._elUnit
  if not unit or not UnitExists(unit) then
    hidePartyDispelIndicators(uf)
    return
  end
  local has, minLeft = partyCollectDispelState(unit)
  applyPartyDispelState(uf, has, minLeft)
end

--- Test-mode debuff strip: cycles PARTY_DEBUFF_TEST_SCENARIO_COUNT patterns across party frames (enable test mode + party frames).
local PARTY_DEBUFF_TEST_SCENARIO_COUNT = 16

local function updatePartyDispelIndicatorsTest(uf, partyIndex)
  if not uf._elDispelRow or not uf._elDispelSq then
    return
  end
  if not partyFrameDebuffsEnabled() then
    uf._elDispelRow:Hide()
    hidePartyDispelIndicators(uf)
    return
  end
  uf._elDispelRow:Show()
  layoutPartyDispelRow(uf)
  local has = { false, false, false, false, false }
  local minLeft = { math.huge, math.huge, math.huge, math.huge, math.huge }
  local s = (math.max(1, partyIndex) - 1) % PARTY_DEBUFF_TEST_SCENARIO_COUNT
  --- 0: none (hidden strip).
  --- 1–5: one slot each — curse, disease, magic, poison, healing — with a 1–9 countdown digit.
  --- 6–8: digit rules — >9s no text; timeless square only; sub-second rounds up to 1.
  --- 9–11: full row — all five with digits; all five lit 12s no digits; two-slot combo.
  --- 12–15: pairs / edge — healing+poison; healing 10s no digit; all five "5".
  if s == 0 then
    --- all false
  elseif s == 1 then
    has[1], minLeft[1] = true, 3
  elseif s == 2 then
    has[2], minLeft[2] = true, 9
  elseif s == 3 then
    has[3], minLeft[3] = true, 1
  elseif s == 4 then
    has[4], minLeft[4] = true, 5
  elseif s == 5 then
    has[5], minLeft[5] = true, 7
  elseif s == 6 then
    has[1], minLeft[1] = true, 11.2
  elseif s == 7 then
    has[2], minLeft[2] = true, math.huge
  elseif s == 8 then
    has[3], minLeft[3] = true, 0.7
  elseif s == 9 then
    for k = 1, 5 do
      has[k] = true
      minLeft[k] = k
    end
  elseif s == 10 then
    for k = 1, 5 do
      has[k] = true
      minLeft[k] = 12
    end
  elseif s == 11 then
    has[1], minLeft[1] = true, 2
    has[5], minLeft[5] = true, 8
  elseif s == 12 then
    has[4], minLeft[4] = true, 6
    has[5], minLeft[5] = true, 4
  elseif s == 13 then
    has[5], minLeft[5] = true, 10.4
  elseif s == 14 then
    for k = 1, 5 do
      has[k] = true
      minLeft[k] = 5
    end
  elseif s == 15 then
    has[1], minLeft[1] = true, 4
    has[2], minLeft[2] = true, 15
    has[3], minLeft[3] = true, 2
    has[4], minLeft[4] = true, math.huge
    has[5], minLeft[5] = true, 9
  end
  applyPartyDispelState(uf, has, minLeft)
end

--- |UnitInRange| is false when the unit is out of helpful-spell range (e.g. heals); |nil|/|true|/|1| = unknown or in range.
local PARTY_HP_OOR_R, PARTY_HP_OOR_G, PARTY_HP_OOR_B = 0.24, 0.24, 0.26

local function partyUnitOutOfHealRange(unit)
  if not unit or unit == "player" then
    return false
  end
  if type(UnitInRange) ~= "function" or not UnitExists(unit) then
    return false
  end
  local r = UnitInRange(unit)
  return r == false
end

function _EL.updatePartyUnitFrame(uf)
  if not uf._elUnit or not UnitExists(uf._elUnit) then
    if uf._elHpBar then uf._elHpBar:SetValue(0) end
    setPartyHpDeficitTextAllLayers(uf, "")
    return
  end
  local unit = uf._elUnit
  local name = UnitName(unit) or ""
  --- Update name label if enabled.
  local hp = UnitHealth(unit) or 0
  local hpMax = UnitHealthMax(unit) or 1
  if hpMax == 0 then hpMax = 1 end
  if uf._elHpBar then uf._elHpBar:SetValue(hp / hpMax) end
  --- Incoming-heal prediction overlay. Sized and placed inside the hpBar. Orientation mirrors
  --- whatever the hpBar is using (horizontal / vertical), so a mixed layout "just works".
  if uf._elIncHealFill and uf._elSelfHealFill and uf._elHpBar then
    local totalInc, selfInc = 0, 0
    if _EL.partyShowIncomingHeals() then
      totalInc, selfInc = _EL.partyIncomingHealAmounts(unit)
    end
    if totalInc > 0 and hpMax > 0 then
      local bw, bh = uf._elHpBar:GetWidth(), uf._elHpBar:GetHeight()
      local hpFill     = math.min(1, hp / hpMax)
      local totalFill  = math.min(1, (hp + totalInc) / hpMax)
      local selfFillTo = math.min(1, (hp + selfInc) / hpMax)
      local orient     = (uf._elHpBar.GetOrientation and uf._elHpBar:GetOrientation()) or "HORIZONTAL"
      local function placeFill(tex, startFrac, endFrac, r, g, b, a)
        if endFrac <= startFrac or bw <= 0 or bh <= 0 then tex:Hide() return end
        tex:ClearAllPoints()
        if orient == "VERTICAL" then
          local yStart = bh * startFrac
          local yEnd   = bh * endFrac
          tex:SetPoint("BOTTOMLEFT", uf._elHpBar, "BOTTOMLEFT", 0, yStart)
          tex:SetWidth(bw)
          tex:SetHeight(math.max(1, yEnd - yStart))
        else
          local xStart = bw * startFrac
          local xEnd   = bw * endFrac
          tex:SetPoint("TOPLEFT", uf._elHpBar, "TOPLEFT", xStart, 0)
          tex:SetWidth(math.max(1, xEnd - xStart))
          tex:SetHeight(bh)
        end
        tex:SetVertexColor(r, g, b, a)
        tex:Show()
      end
      local rT, gT, bT = _EL.partyIncomingHealRGB()
      local rS, gS, bS = _EL.partySelfHealRGB()
      placeFill(uf._elIncHealFill,  hpFill,     totalFill,  rT, gT, bT, 0.55)
      --- Self-cast heals tinted on top of the total bar — highlighted so the caster can see
      --- their own contribution. Hidden when not healing yourself or when self == 0.
      if selfInc > 0 then
        placeFill(uf._elSelfHealFill, hpFill, selfFillTo, rS, gS, bS, 0.85)
      else
        uf._elSelfHealFill:Hide()
      end
    else
      uf._elIncHealFill:Hide()
      uf._elSelfHealFill:Hide()
    end
  end
  --- Color the health bar by class, or dark grey when out of heal/helpful range.
  if uf._elHpBar and partyUnitOutOfHealRange(unit) then
    local rr, gg, bb = _EL.partyHpOOR_RGB()
    uf._elHpBar:SetStatusBarColor(rr, gg, bb)
  else
    local applied = false
    if _EL.useClassColorsParty() then
      local _, cls = UnitClass(unit)
      if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
        local c = RAID_CLASS_COLORS[cls]
        if uf._elHpBar then uf._elHpBar:SetStatusBarColor(c.r, c.g, c.b) end
        applied = true
      end
    end
    if not applied and uf._elHpBar then
      local rr, gg, bb = _EL.partyHpFallbackRGB()
      uf._elHpBar:SetStatusBarColor(rr, gg, bb)
    end
  end
  if uf._elHpDeficitFs then
    if not partyFrameHpDeficitEnabled() then
      setPartyHpDeficitTextAllLayers(uf, "")
    else
      local def = hpMax - hp
      if def > 0 then
        setPartyHpDeficitTextAllLayers(uf, string.format(L.HP_DEFICIT, math.floor(def + 0.5)))
        applyPartyHpDeficitColors(uf)
      else
        setPartyHpDeficitTextAllLayers(uf, "")
      end
    end
  end
  --- Mana / primary power bar update.
  local pNorm = 0  --- fraction 0..1 of current primary power, used by the low-mana flash below.
  local hasPower = false
  local unitPowerTypeIdx  --- 0=mana, 1=rage, 3=energy, …; used to suppress the low-mana flash for rage/energy/focus/runic.
  if uf._elManaBar then
    if _EL.showPartyManaBars() then
      local pMax = (UnitPowerMax and UnitPowerMax(unit)) or 0
      if pMax and pMax > 0 then
        local p = (UnitPower and UnitPower(unit)) or 0
        pNorm = p / pMax
        hasPower = true
        if UnitPowerType then unitPowerTypeIdx = UnitPowerType(unit) end
        uf._elManaBar:SetValue(pNorm)
        --- Power-type coloring (mana blue / rage red / energy yellow …) or a single user color.
        local applied = false
        if _EL.usePowerTypeColorsParty() and UnitPowerType and PowerBarColor then
          local pt = UnitPowerType(unit)
          local cc = PowerBarColor[pt]
          if cc and type(cc.r) == "number" then
            uf._elManaBar:SetStatusBarColor(cc.r, cc.g, cc.b)
            applied = true
          end
        end
        if not applied then
          local rr, gg, bb = _EL.partyManaBarRGB()
          uf._elManaBar:SetStatusBarColor(rr, gg, bb)
        end
        uf._elManaBar:Show()
      else
        uf._elManaBar:Hide()
      end
    else
      uf._elManaBar:Hide()
    end
  end
  --- Role icon (tank/healer/damager badge in top-left corner).
  if uf._elRoleIcon then
    if _EL.partyShowRoleIcon() then
      local role
      local isTestMode = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
      if isTestMode then
        --- Fake role cycle so the option is visibly testable on Classic (which has no LFG roles).
        --- Pattern: first slot = tank, second = healer, rest damager, with periodic variation.
        local idx = uf._elColorIdx or 1
        local cycle = ((idx - 1) % 5) + 1
        if     cycle == 1 then role = "TANK"
        elseif cycle == 2 then role = "HEALER"
        else                   role = "DAMAGER"
        end
      else
        role = _EL.resolveUnitRole(unit)
      end
      if role then
        local sz = _EL.partyRoleIconSize()
        uf._elRoleIcon:SetSize(sz, sz)
        --- Blizzard LFG role atlas texcoords (UI-LFG-ICON-ROLES).
        if     role == "TANK"    then uf._elRoleIcon:SetTexCoord(0.00, 0.30, 0.30, 0.63)
        elseif role == "HEALER"  then uf._elRoleIcon:SetTexCoord(0.31, 0.61, 0.00, 0.32)
        else                          uf._elRoleIcon:SetTexCoord(0.31, 0.61, 0.30, 0.63)  -- DAMAGER
        end
        uf._elRoleIcon:Show()
      else
        uf._elRoleIcon:Hide()
      end
    else
      uf._elRoleIcon:Hide()
    end
  end
  --- Name overlay text.
  if uf._elNameFs then
    if _EL.partyFrameShowName() then
      uf._elNameFs:SetText(_EL.truncateName(name))
      --- Shade by class when available, otherwise white.
      local _, cls = UnitClass(unit)
      if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
        local c = RAID_CLASS_COLORS[cls]
        uf._elNameFs:SetTextColor(c.r, c.g, c.b)
      else
        uf._elNameFs:SetTextColor(1, 1, 1)
      end
      uf._elNameFs:Show()
    else
      uf._elNameFs:Hide()
    end
  end
  --- Low-HP / low-mana flash state. HP wins when both are low so healers notice the bigger emergency.
  --- The mana flash only triggers for real mana (power type 0); rage/energy/focus/runic are by
  --- design frequently near zero, so flashing them would be constant noise. If the power type can't
  --- be resolved (e.g. test mode), fall back to allowing the flash so the preview still works.
  if uf._elFlashBorders then
    local lowHp = _EL.partyLowHpFlashEnabled() and (hp / hpMax) * 100 <= _EL.partyLowHpThreshold()
    local powerTypeIsMana = (unitPowerTypeIdx == nil) or (unitPowerTypeIdx == 0)
    local lowMana = _EL.partyLowManaFlashEnabled() and hasPower and powerTypeIsMana and (pNorm * 100) <= _EL.partyLowManaThreshold()
    local state = nil
    if lowHp then
      state = "hp"
    elseif lowMana then
      state = "mana"
    end
    uf._elFlashState = state
    if state then
      local rr, gg, bb
      if state == "hp" then rr, gg, bb = _EL.partyLowHpFlashRGB() else rr, gg, bb = _EL.partyLowManaFlashRGB() end
      for _, edge in ipairs(uf._elFlashBorders) do
        edge:SetColorTexture(rr, gg, bb, 1)
        edge:Show()
      end
    else
      for _, edge in ipairs(uf._elFlashBorders) do
        edge:Hide()
      end
    end
  end
  --- Player buff icon strip refresh. Cheap (caps at 8 icons + 40 aura iterations) so we run it
  --- alongside the per-frame data update; UNIT_AURA also funnels through |updatePartyUnitFrame|.
  if uf._elPlayerBuffSlots then
    updatePartyPlayerBuffs(uf)
  end
end

local function createPartyFrames()
  if partyFrameContainer then return end
  local bdTmpl = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  local hasClique = type(_G.Clique) == "table" or IsAddOnLoaded and IsAddOnLoaded("Clique")
  local cliqueTemplate = hasClique and "ClickCastUnitTemplate,SecureUnitButtonTemplate" or "SecureUnitButtonTemplate"

  partyFrameContainer = CreateFrame("Frame", "EnemyListPartyContainer", UIParent)
  partyFrameContainer:SetClampedToScreen(true)
  partyFrameContainer:SetMovable(true)
  partyFrameContainer:EnableMouse(true)
  partyFrameContainer:RegisterForDrag("LeftButton")
  --- Container holds SecureUnitButtonTemplate children, so StartMoving / StopMovingOrSizing /
  --- SetPoint / SetSize on the container are all protected operations during combat. Block all
  --- drag attempts when in combat lockdown — user can reposition once they're OOC.
  partyFrameContainer:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving()
  end)
  partyFrameContainer:SetScript("OnDragStop", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StopMovingOrSizing()
    savePartyFramePosition()
  end)
  --- Visible drag handle above the container.
  local dragHandle = CreateFrame("Frame", nil, partyFrameContainer)
  dragHandle:SetHeight(12)
  dragHandle:SetPoint("BOTTOMLEFT", partyFrameContainer, "TOPLEFT", 0, 0)
  dragHandle:SetPoint("BOTTOMRIGHT", partyFrameContainer, "TOPRIGHT", 0, 0)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then return end
    partyFrameContainer:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    if InCombatLockdown and InCombatLockdown() then return end
    partyFrameContainer:StopMovingOrSizing()
    savePartyFramePosition()
  end)
  local dragBg = dragHandle:CreateTexture(nil, "BACKGROUND")
  dragBg:SetAllPoints()
  dragBg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
  local dragLabel = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  dragLabel:SetPoint("CENTER")
  dragLabel:SetText("drag")
  dragLabel:SetTextColor(0.4, 0.42, 0.45)
  --- Hide drag handle when locked.
  local function updateDragVisibility()
    if EnemyListDB and EnemyListDB.locked then
      dragHandle:Hide()
    else
      dragHandle:Show()
    end
  end
  updateDragVisibility()
  partyFrameContainer._elUpdateDrag = updateDragVisibility

  --- First load: center on screen. After drag: use saved TOPLEFT position.
  local px = EnemyListDB.partyFrameX
  local py = EnemyListDB.partyFrameY
  if px and py then
    partyFrameContainer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", px, py)
  else
    partyFrameContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  --- 5 party/solo tokens + raid1..N (in raid, player/party* are parked; see |updatePartyFrameSize|).
  --- Pet tokens (|pet|, |partypetN|, |raidpetN|) are always created so toggling the option doesn't
  --- need a /reload — they're hidden by default via the layout pass when |partyShowPets| is off.
  local units = { "player", "party1", "party2", "party3", "party4", "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
  for ri = 1, PARTY_FRAME_RAID_UNIT_MAX do
    units[#units + 1] = "raid" .. ri
  end
  for ri = 1, PARTY_FRAME_RAID_UNIT_MAX do
    units[#units + 1] = "raidpet" .. ri
  end
  for i, unit in ipairs(units) do
    local frameName = "EnemyListPartyUF" .. i
    local uf = CreateFrame("Button", frameName, partyFrameContainer, cliqueTemplate)
    uf:SetAttribute("type1", "target")
    uf:SetAttribute("unit", unit)
    uf._elUnit = unit
    partyUfByUnit[unit] = uf
    uf:SetFrameLevel((partyFrameContainer:GetFrameLevel() or 0) + 2)

    --- Register with ClickCastFrames / Clique if available.
    if type(_G.ClickCastFrames) == "table" then
      _G.ClickCastFrames[uf] = true
    end
    if _G.Clique and type(_G.Clique.RegisterUnitFrame) == "function" then
      pcall(function() _G.Clique:RegisterUnitFrame(uf) end)
    end

    --- RegisterUnitWatch for auto show/hide based on unit existence (except player which always exists).
    RegisterUnitWatch(uf)

    --- Background (changes to assigned color when being attacked).
    local bg = uf:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.85)
    uf._elBg = bg
    --- Use PARTY_UNIT_COLOR so the index matches the one |partyMemberAttacked| is keyed by
    --- (which comes from |layoutPartyColorByGuid|). Previously |i| — the raw |units| iteration
    --- index — was used, and raid slots 6..45 never matched the 1..15 range partyMemberAttacked
    --- actually stores, so aggro counts never displayed on raidN frames.
    uf._elColorIdx = PARTY_UNIT_COLOR[unit] or i

    --- Health bar using a StatusBar
    local hpBar = CreateFrame("StatusBar", nil, uf)
    hpBar:SetPoint("BOTTOMLEFT", uf, "BOTTOMLEFT", 2, 2)
    hpBar:SetPoint("BOTTOMRIGHT", uf, "BOTTOMRIGHT", -2, 2)
    hpBar:SetHeight(partyFrameHpBarHeightPx())
    hpBar:SetMinMaxValues(0, 1)
    hpBar:SetValue(1)
    hpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    do local rr, gg, bb = _EL.partyHpFallbackRGB(); hpBar:SetStatusBarColor(rr, gg, bb) end
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0, 0, 0, 0.5)
    uf._elHpBar = hpBar

    --- Incoming-heal prediction fill — drawn inside the HP bar, starts at the current HP
    --- fraction and extends toward max. A second texture on top of that shows the portion
    --- that the player themselves is casting, in a distinct color.
    local incHealFill = hpBar:CreateTexture(nil, "ARTWORK", nil, 2)
    incHealFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    incHealFill:Hide()
    uf._elIncHealFill = incHealFill
    local selfHealFill = hpBar:CreateTexture(nil, "ARTWORK", nil, 3)
    selfHealFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    selfHealFill:Hide()
    uf._elSelfHealFill = selfHealFill

    --- Mana / primary power bar — anchored above the HP bar; hidden unless |_EL.showPartyManaBars()|.
    --- Uses the same texture + color handling as hpBar; height is configurable.
    local manaBar = CreateFrame("StatusBar", nil, uf)
    manaBar:SetPoint("BOTTOMLEFT", hpBar, "TOPLEFT", 0, 1)
    manaBar:SetPoint("BOTTOMRIGHT", hpBar, "TOPRIGHT", 0, 1)
    manaBar:SetHeight(math.max(2, math.min(40, tonumber(EnemyListDB and EnemyListDB.partyManaBarHeight) or defaults.partyManaBarHeight)))
    manaBar:SetMinMaxValues(0, 1)
    manaBar:SetValue(1)
    manaBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    do local rr, gg, bb = _EL.partyManaBarRGB(); manaBar:SetStatusBarColor(rr, gg, bb) end
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints()
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    manaBar:Hide()
    uf._elManaBar = manaBar

    --- Lost HP: one string; “border” color is the font shadow (avoids multi-layer ghosting).
    local hpDeficitFs = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpDeficitFs:SetPoint("CENTER", hpBar, "CENTER", 0, 0)
    hpDeficitFs:SetJustifyH("CENTER")
    hpDeficitFs:SetJustifyV("MIDDLE")
    pcall(function()
      local f, _ = hpDeficitFs:GetFont()
      if f then
        hpDeficitFs:SetFont(f, partyFrameHpDeficitFontPixelSize(), "")
      end
    end)
    uf._elHpDeficitFs = hpDeficitFs
    applyPartyHpDeficitColors(uf)

    --- Top strip: curse, disease, magic, poison, healing reduction (see PARTY_HEALING_REDUCTION_SPELL_IDS).
    local dispelRow = CreateFrame("Frame", nil, uf)
    uf._elDispelRow = dispelRow
    uf._elDispelSq = {}
    for slot = 1, PARTY_DEBUFF_SLOT_COUNT do
      local wrap = CreateFrame("Frame", nil, dispelRow)
      wrap:Hide()
      local tex = wrap:CreateTexture(nil, "BACKGROUND")
      tex:SetTexture("Interface\\Buttons\\WHITE8X8")
      tex:SetAllPoints()
      tex:SetVertexColor(1, 1, 1, 1)
      local fs = wrap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      --- Explicit parent: full TOPLEFT/BOTTOMRIGHT on FontStrings often hides text on some clients.
      fs:SetPoint("CENTER", wrap, "CENTER", 1, 0)
      fs:SetJustifyH("CENTER")
      fs:SetJustifyV("MIDDLE")
      fs:SetTextColor(1, 1, 1, 1)
      --- No shadow: outline already defines the edge; shadow skews perceived center to the left.
      fs:SetShadowOffset(0, 0)
      fs:SetShadowColor(0, 0, 0, 1)
      pcall(function()
        local f0, _ = fs:GetFont()
        if f0 then
          fs:SetFont(f0, 4, "OUTLINE")
        end
      end)
      uf._elDispelSq[slot] = { frame = wrap, tex = tex, fs = fs }
    end

    --- Player-buff strip: icons of buffs cast BY THE PLAYER on this unit (Renew, PW:Shield, PoM…).
    --- Anchored to the BOTTOM of the frame (positioned by |layoutPartyPlayerBuffRow|), so it does
    --- not collide with the dispel strip on top. Each slot has an icon texture, an outline border,
    --- a stack-count FontString (top-right), and a remaining-time FontString (bottom-center).
    local buffRow = CreateFrame("Frame", nil, uf)
    uf._elPlayerBuffRow = buffRow
    uf._elPlayerBuffSlots = {}
    --- Always allocate the max possible slot count (8). Layout shows only the user-configured count.
    for slot = 1, 8 do
      local btn = CreateFrame("Frame", nil, buffRow)
      btn:Hide()
      local icon = btn:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints()
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim default Blizzard icon border
      local border = btn:CreateTexture(nil, "OVERLAY")
      border:SetAllPoints()
      border:SetColorTexture(0, 0, 0, 0)  -- placeholder; we'll just rely on the icon's own border
      local cd = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      cd:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
      cd:SetJustifyH("CENTER")
      cd:SetTextColor(1, 1, 0.6, 1)
      cd:SetShadowOffset(1, -1)
      cd:SetShadowColor(0, 0, 0, 1)
      local count = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      count:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 1, 1)
      count:SetJustifyH("RIGHT")
      count:SetTextColor(1, 1, 1, 1)
      count:SetShadowOffset(1, -1)
      count:SetShadowColor(0, 0, 0, 1)
      uf._elPlayerBuffSlots[slot] = { frame = btn, icon = icon, border = border, cd = cd, count = count }
    end

    --- Border (4 edges, color changes dynamically when attacked). Sublevel 6 so the flash border
    --- below can sit on top at sublevel 7 (Blizzard caps sublevels at -8..7).
    uf._elBorders = {}
    local bw = 2
    for _, info in ipairs({
      { "TOPLEFT", "TOPRIGHT", nil, bw },
      { "BOTTOMLEFT", "BOTTOMRIGHT", nil, bw },
      { "TOPLEFT", "BOTTOMLEFT", bw, nil },
      { "TOPRIGHT", "BOTTOMRIGHT", bw, nil },
    }) do
      local edge = uf:CreateTexture(nil, "OVERLAY", nil, 6)
      edge:SetPoint(info[1], uf, info[1], 0, 0)
      edge:SetPoint(info[2], uf, info[2], 0, 0)
      if info[3] then edge:SetWidth(info[3]) end
      if info[4] then edge:SetHeight(info[4]) end
      edge:SetColorTexture(0.3, 0.3, 0.3, 0.6)
      uf._elBorders[#uf._elBorders + 1] = edge
    end

    --- Flash border (separate 4 edges above the normal borders). Hidden by default; shown + pulsed
    --- when the unit drops below its low-HP / low-mana threshold. The tint is the configured
    --- low-HP or low-mana color; HP takes priority when both are low.
    uf._elFlashBorders = {}
    local fbw = 3
    for _, info in ipairs({
      { "TOPLEFT", "TOPRIGHT", nil, fbw },
      { "BOTTOMLEFT", "BOTTOMRIGHT", nil, fbw },
      { "TOPLEFT", "BOTTOMLEFT", fbw, nil },
      { "TOPRIGHT", "BOTTOMRIGHT", fbw, nil },
    }) do
      local edge = uf:CreateTexture(nil, "OVERLAY", nil, 7)
      edge:SetPoint(info[1], uf, info[1], 0, 0)
      edge:SetPoint(info[2], uf, info[2], 0, 0)
      if info[3] then edge:SetWidth(info[3]) end
      if info[4] then edge:SetHeight(info[4]) end
      edge:SetColorTexture(1, 0, 0, 1)
      edge:Hide()
      uf._elFlashBorders[#uf._elFlashBorders + 1] = edge
    end
    uf._elFlashState = nil
    --- Top-level overlay frame for the name label. Higher frame level than bars so the text
    --- paints above them (sublevels don't cross frame boundaries on child StatusBars).
    local topOverlay = CreateFrame("Frame", nil, uf)
    topOverlay:SetAllPoints()
    topOverlay:SetFrameLevel((uf:GetFrameLevel() or 0) + 10)
    topOverlay:EnableMouse(false)
    uf._elTopOverlay = topOverlay

    --- Separate overlay exclusively for the aggro-count digit. Placed in a higher frame strata so
    --- it unconditionally renders above the HP / mana StatusBars regardless of whatever level
    --- those children pick (SecureUnitButtonTemplate sometimes bumps child-frame levels in ways
    --- that defeat a simple "+20" offset). |SetToplevel| keeps the digit above sibling frames at
    --- the same strata too.
    local countOverlay = CreateFrame("Frame", nil, uf)
    countOverlay:SetAllPoints()
    countOverlay:SetFrameStrata("HIGH")
    countOverlay:SetFrameLevel(100)
    if countOverlay.SetToplevel then pcall(countOverlay.SetToplevel, countOverlay, true) end
    countOverlay:EnableMouse(false)
    uf._elCountOverlay = countOverlay

    --- Unit name label — optional overlay text, centered at the top of the frame.
    local nameFs = topOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetDrawLayer("OVERLAY", 7)
    nameFs:SetPoint("TOP", topOverlay, "TOP", 0, -2)
    nameFs:SetJustifyH("CENTER")
    nameFs:SetJustifyV("TOP")
    nameFs:SetShadowOffset(1, -1)
    nameFs:SetShadowColor(0, 0, 0, 1)
    nameFs:SetWordWrap(false)
    nameFs:Hide()
    uf._elNameFs = nameFs

    local countFs = countOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countFs:SetDrawLayer("OVERLAY", 7)
    countFs:SetPoint("CENTER", countOverlay, "CENTER", 0, 0)
    countFs:SetJustifyH("CENTER")
    countFs:SetJustifyV("MIDDLE")
    countFs:SetShadowOffset(1, -1)
    countFs:SetShadowColor(0, 0, 0, 1)
    uf._elCountFs = countFs
    applyPartyAggroCountFontSize(uf)
    applyPartyAggroCountColors(uf)
    countFs:Hide()

    --- Role icon (tank/healer/damager). Positioned top-left with a small inset; vertex-tinted by
    --- role and texcoord-sliced from the Blizzard LFG role atlas. Shown only when the toggle is on
    --- and a role can be resolved (UnitGroupRolesAssigned or GetPartyAssignment).
    local roleIcon = topOverlay:CreateTexture(nil, "OVERLAY")
    roleIcon:SetDrawLayer("OVERLAY", 7)
    roleIcon:SetSize(12, 12)
    roleIcon:SetPoint("TOPLEFT", topOverlay, "TOPLEFT", 2, -2)
    roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
    roleIcon:Hide()
    uf._elRoleIcon = roleIcon

    partyUnitFrames[i] = uf
  end

  updatePartyFrameSize()

  --- Grid2-style: roster/aura events update bars; enemy list layout updates aggro chrome (see |applyPartyFrameAggroAttackedChrome|).
  if not partyUnitWatchFrame then
    partyUnitWatchFrame = CreateFrame("Frame", "EnemyListPartyUnitWatch", UIParent)
    partyUnitWatchFrame:SetScript("OnEvent", function(_, event, unit)
      if event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        --- A pet was summoned / dismissed — re-layout so |raidpetN| etc. join or leave the grid.
        if partyFrameContainer and type(EnemyListDB) == "table" and EnemyListDB.showPartyFrames then
          if not InCombatLockdown() then
            updatePartyFrameSize()
          end
        end
        return
      end
      if not unit or not partyUfByUnit[unit] then
        return
      end
      if not partyFrameContainer or not partyFrameContainer:IsShown() then
        return
      end
      if type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn() then
        return
      end
      local uf = partyUfByUnit[unit]
      if event == "UNIT_AURA" then
        if partyFrameDebuffsEnabled() then
          updatePartyDispelIndicators(uf)
        end
        return
      end
      _EL.updatePartyUnitFrame(uf)
      if event == "UNIT_NAME_UPDATE" and partyFrameDebuffsEnabled() then
        updatePartyDispelIndicators(uf)
      end
    end)
    partyUnitWatchFrame:RegisterEvent("UNIT_HEALTH")
    partyUnitWatchFrame:RegisterEvent("UNIT_MAXHEALTH")
    partyUnitWatchFrame:RegisterEvent("UNIT_NAME_UPDATE")
    partyUnitWatchFrame:RegisterEvent("UNIT_AURA")
    partyUnitWatchFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_PET") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_POWER_UPDATE") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_POWER_FREQUENT") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_MAXPOWER") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_MANA") end) -- Classic/Anniversary fallback
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_ENERGY") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_RAGE") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_FOCUS") end)
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_DISPLAYPOWER") end)
    --- Retail + modern Classic fire this when UnitGetIncomingHeals() changes; missing on Vanilla.
    pcall(function() partyUnitWatchFrame:RegisterEvent("UNIT_HEAL_PREDICTION") end)
  end

  for _, uf in ipairs(partyUnitFrames) do
    _EL.updatePartyUnitFrame(uf)
    if partyFrameDebuffsEnabled() then
      updatePartyDispelIndicators(uf)
    end
  end

  --- Test mode: fake data on a short tick. Live: drag + layout on slow tick; health via events.
  --- Debuff strip: global |UNIT_AURA| is unreliable on some Classic/Anniversary builds (needs per-unit |RegisterUnitEvent|). Poll lightly so squares stay in sync.
  local partySlowAcc = 0
  local partyDispelAcc = 0
  local partyFlashPhase = 0
  local partyAggroAcc = 0
  partyFrameContainer:SetScript("OnUpdate", function(_, dt)
    --- Aggro-counter fast path. Target switches on live mobs aren't announced by any event we can
    --- cheaply observe, so the digits would lag behind the throttled list-redraw cadence (up to
    --- |coalesceUIRefresh| * coalesce window). Poll at 0.1s so the numbers track within ~100ms
    --- rather than 5s.
    partyAggroAcc = partyAggroAcc + dt
    if partyAggroAcc >= 0.1 and _EL.refreshAggroCounters then
      partyAggroAcc = 0
      _EL.refreshAggroCounters()
    end
    local isTestMode = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
    if not isTestMode and partyFrameDebuffsEnabled() and partyFrameContainer:IsShown() then
      partyDispelAcc = partyDispelAcc + dt
      if partyDispelAcc >= 0.18 then
        partyDispelAcc = 0
        for _, uf in ipairs(partyUnitFrames) do
          if uf._elUnit and UnitExists(uf._elUnit) then
            updatePartyDispelIndicators(uf)
          end
        end
      end
    else
      partyDispelAcc = 0
    end
    --- Low-HP / low-mana flash pulse. Uses a sinusoidal alpha (1.2Hz) so the overlay strobes
    --- smoothly without extra timers. Only iterates frames with an active flash state.
    partyFlashPhase = partyFlashPhase + dt
    if partyFlashPhase > 1000 then partyFlashPhase = 0 end
    if partyFrameContainer:IsShown() then
      local alpha = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(partyFlashPhase * 6.28 * 1.2))
      for _, uf in ipairs(partyUnitFrames) do
        if uf._elFlashBorders and uf._elFlashState then
          for _, edge in ipairs(uf._elFlashBorders) do
            edge:SetAlpha(alpha)
          end
        end
      end
    end
    --- Shorter cadence in live mode so OOC regen (drinking / first-aid / natural recovery)
    --- visibly ticks up on the frames. Vanilla clients often don't fire UNIT_HEALTH for party
    --- members outside combat, so this is the primary driver of OOC HP / mana updates.
    local tick = isTestMode and 0.12 or 0.25
    partySlowAcc = partySlowAcc + dt
    if partySlowAcc < tick then
      return
    end
    partySlowAcc = 0
    updateDragVisibility()
    if not InCombatLockdown() then
      updatePartyFrameSize()
    end
    if not isTestMode then
      for _, uf in ipairs(partyUnitFrames) do
        if uf._elTestShown and not InCombatLockdown() then
          uf._elTestShown = nil
          RegisterUnitWatch(uf)
        end
        if uf._elUnit and UnitExists(uf._elUnit) and _EL.updatePartyUnitFrame then
          _EL.updatePartyUnitFrame(uf)
        end
      end
      return
    end
    local testPartyClasses = EL_TEST_PARTY_CLASSES
    --- Test mode uses |partyShowPets| to skip pet frame visuals when the toggle is off, and scopes
    --- the preview to the active profile (party = 5-man + pets; raid = 40-man + pets). Without the
    --- profile filter the user gets all 90 frames force-shown and the party config tab looks broken.
    local showPetsTest = _EL.partyShowPets()
    local activeProfTest = (type(EnemyListDB) == "table" and EnemyListDB.activeProfileName) or "party"
    local function isPetUnitTokenLocal(u)
      if type(u) ~= "string" then return false end
      return u == "pet" or u:match("^partypet%d+$") or u:match("^raidpet%d+$")
    end
    local function inActiveTestProfileLocal(u)
      if activeProfTest == "raid" then
        return type(u) == "string" and (u:match("^raid%d") and not u:match("^raidpet")) or (u and u:match("^raidpet%d"))
      end
      return u == "player" or (type(u) == "string" and (u:match("^party%d+$") or u == "pet" or u:match("^partypet%d+$")))
    end
    for i, uf in ipairs(partyUnitFrames) do
      local isPet = isPetUnitTokenLocal(uf._elUnit)
      local outOfProfile = not inActiveTestProfileLocal(uf._elUnit)
      if outOfProfile then
        --- Frames belonging to the inactive profile: hide entirely so the preview stays scoped.
        if uf._elTestShown and not InCombatLockdown() then
          uf._elTestShown = nil
          RegisterUnitWatch(uf)
        end
        uf:Hide()
      elseif isPet and not showPetsTest then
        if uf._elTestShown and not InCombatLockdown() then
          uf._elTestShown = nil
          RegisterUnitWatch(uf)
        end
        uf:Hide()
      else
        if not uf:IsShown() and not InCombatLockdown() then
          UnregisterUnitWatch(uf)
          uf:Show()
        end
        local fakeMax = 380 + ((i * 13 + (i % 7) * 19) % 26) * 62
        local pct = math.min(0.92, math.max(0.18, 0.12 + ((i * 17 + (i % 3)) % 72) / 100))
        --- Pets get a tighter HP range so they read as "smaller" health pools at a glance.
        if isPet then
          fakeMax = math.floor(fakeMax * 0.45)
          pct = math.min(0.95, math.max(0.25, 0.20 + ((i * 23 + (i % 5)) % 65) / 100))
        end
        if uf._elHpBar then
          uf._elHpBar:SetValue(pct)
        end
        if uf._elHpDeficitFs then
          if partyFrameHpDeficitEnabled() then
            local def = math.floor(fakeMax * (1 - pct) + 0.5)
            if def > 0 then
              setPartyHpDeficitTextAllLayers(uf, string.format(L.HP_DEFICIT, def))
              applyPartyHpDeficitColors(uf)
            else
              setPartyHpDeficitTextAllLayers(uf, "")
            end
          else
            setPartyHpDeficitTextAllLayers(uf, "")
          end
        end
        if isPet then
          --- Pets: warm tan tint reminiscent of beast/creature coloring (same hue used for the
          --- creature-type Beast color on enemy rows). Distinct from class colors so the strip
          --- visually reads as "pets" without needing class lookups.
          if uf._elHpBar then
            uf._elHpBar:SetStatusBarColor(0.7, 0.5, 0.3)
          end
        else
          local cls = testPartyClasses[i]
          if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
            local c = RAID_CLASS_COLORS[cls]
            if uf._elHpBar then
              uf._elHpBar:SetStatusBarColor(c.r, c.g, c.b)
            end
          end
        end
        updatePartyDispelIndicatorsTest(uf, i)
        --- Fake player-buff icons in test mode: cycle a few well-known healer HoT icons so the
        --- strip is visibly testable. Real units use |UnitBuff(unit, idx)| filtered to caster=="player".
        if uf._elPlayerBuffSlots and _EL.partyShowPlayerBuffs() then
          local n = _EL.partyPlayerBuffSlotCount()
          local layoutFn = layoutPartyPlayerBuffRow
          if layoutFn then layoutFn(uf) end
          uf._elPlayerBuffRow:Show()
          --- Spell IDs (FileDataIDs work too, but spellId → GetSpellTexture is portable across builds).
          local fakeBuffs = {
            { id = 139,    name = "Renew",            count = 0, dur = 15 },
            { id = 17,     name = "Power Word: Shield", count = 0, dur = 30 },
            { id = 33076,  name = "Prayer of Mending", count = 4, dur = 30 },
            { id = 774,    name = "Rejuvenation",     count = 0, dur = 12 },
            { id = 26980,  name = "Lifebloom",        count = 3, dur = 7 },
            { id = 53563,  name = "Beacon of Light",  count = 0, dur = 60 },
            { id = 41635,  name = "Prayer of Mending", count = 1, dur = 22 },
            { id = 8936,   name = "Regrowth",         count = 0, dur = 18 },
          }
          local shown = math.min(n, ((i - 1) % 5) + 1)  -- vary count per slot
          local now = GetTime()
          for s = 1, 8 do
            local cell = uf._elPlayerBuffSlots[s]
            if not cell then break end
            if s <= shown then
              local b = fakeBuffs[((i + s - 2) % #fakeBuffs) + 1]
              local gtex
              if type(GetSpellTexture) == "function" then
                local ok, result = pcall(GetSpellTexture, b.id)
                if ok then gtex = result end
              end
              cell.icon:SetTexture((type(gtex) == "string" or type(gtex) == "number") and gtex or "Interface\\Icons\\INV_Misc_QuestionMark")
              if b.count > 0 then cell.count:SetText(tostring(b.count)) else cell.count:SetText("") end
              local left = b.dur
              if left >= 60 then cell.cd:SetText(math.floor(left / 60 + 0.5) .. "m")
              elseif left >= 10 then cell.cd:SetText(math.floor(left + 0.5))
              else cell.cd:SetText(string.format("%.1f", left)) end
              cell.frame:Show()
            else
              cell.frame:Hide()
            end
          end
        elseif uf._elPlayerBuffRow then
          uf._elPlayerBuffRow:Hide()
          for s = 1, 8 do
            local cell = uf._elPlayerBuffSlots and uf._elPlayerBuffSlots[s]
            if cell and cell.frame then cell.frame:Hide() end
          end
        end
        uf._elTestShown = true
      end
    end
  end)
end

local function showPartyFrames()
  if not partyFrameContainer then
    createPartyFrames()
  end
  partyFrameContainer:Show()
  for _, uf in ipairs(partyUnitFrames) do
    _EL.updatePartyUnitFrame(uf)
    if partyFrameDebuffsEnabled() then
      updatePartyDispelIndicators(uf)
    end
  end
end

local function hidePartyFrames()
  if partyFrameContainer then
    partyFrameContainer:Hide()
  end
end

function togglePartyFramesVisibility()
  --- Raid-specific hide: when |hidePartyFramesInRaid| is on, treat the frames as disabled while
  --- IsInRaid() is true. This mirrors the auto-switch direction (raid → hide) without altering
  --- the persistent |showPartyFrames| toggle.
  local hideInRaid = EnemyListDB.hidePartyFramesInRaid and IsInRaid and IsInRaid()
  if EnemyListDB.showPartyFrames and not hideInRaid then
    showPartyFrames()
  else
    hidePartyFrames()
  end
end
EnemyList.TogglePartyFrames = togglePartyFramesVisibility

local function createMainFrame()
  --- |ShowSetupWizard|, slash commands, and |PLAYER_LOGIN| all call this; must not spawn a second list (orphan frame stays on screen).
  if main then
    return
  end
  local backdropMixin = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  --- Outer shell: scale 1 only — |StartMoving|/saved |TOPLEFT| stay aligned with the visible list.
  main = CreateFrame("Frame", "EnemyListMain", UIParent)
  main:SetScale(1)
  main:SetSize(EnemyListDB.width or defaults.width, 120)
  main:SetClampedToScreen(true)
  main:SetMovable(true)
  main:EnableMouse(true)
  --- First load: center. After drag: saved TOPLEFT position.
  if EnemyListDB.x and EnemyListDB.y then
    main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", EnemyListDB.x, EnemyListDB.y)
  else
    main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  --- Plain root carries scale; backdrop is a full-size child so it scales with content (backdrop on the scaled root often stays 1:1).
  mainScaleRoot = CreateFrame("Frame", "EnemyListMainScaled", main)
  mainScaleRoot:SetSize(main:GetWidth(), main:GetHeight())
  mainScaleRoot:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)

  mainScaleBackdrop = CreateFrame("Frame", nil, mainScaleRoot, backdropMixin)
  mainScaleBackdrop:SetAllPoints(mainScaleRoot)
  mainScaleBackdrop:SetFrameLevel(0)
  mainScaleBackdrop:EnableMouse(false)

  --- Before SetBackdrop: layoutRows needs rowContainer (backdrop can resize the frame).
  rowContainer = CreateFrame("Frame", nil, mainScaleRoot)
  rowContainer:SetFrameLevel(10)
  rowContainer:SetPoint("TOPLEFT", mainScaleRoot, "TOPLEFT", 10, -12)
  rowContainer:SetPoint("TOPRIGHT", mainScaleRoot, "TOPRIGHT", -10, -12)

  rowContainer.colAggro = CreateFrame("Frame", "EnemyListColAggro", rowContainer)
  rowContainer.colOther = CreateFrame("Frame", "EnemyListColOther", rowContainer)
  rowContainer.hdrAggro = rowContainer.colAggro:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rowContainer.hdrAggro:SetJustifyH("LEFT")
  rowContainer.hdrOther = rowContainer.colOther:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rowContainer.hdrOther:SetJustifyH("LEFT")
  rowContainer.hdrAggro:SetTextColor(0.74, 0.77, 0.82)
  rowContainer.hdrOther:SetTextColor(0.74, 0.77, 0.82)

  applyMaterialSurface(mainScaleBackdrop)
  applyMainBackground()

  local dragStrip = CreateFrame("Button", nil, mainScaleRoot)
  dragStrip:SetHeight(10)
  dragStrip:SetPoint("TOPLEFT", mainScaleRoot, "TOPLEFT", 2, -2)
  dragStrip:SetPoint("TOPRIGHT", mainScaleRoot, "TOPRIGHT", -2, -2)
  dragStrip:SetFrameLevel(85)
  dragStrip:RegisterForDrag("LeftButton")
  dragStrip:SetScript("OnDragStart", function()
    if EnemyListDB.locked or elInCombatLockdown() then
      return
    end
    main:StartMoving()
  end)
  dragStrip:SetScript("OnDragStop", function()
    main:StopMovingOrSizing()
    savePosition()
  end)
  --- Tooltips removed from drag strip.
  local dsTex = dragStrip:CreateTexture(nil, "BACKGROUND")
  dsTex:SetAllPoints()
  dsTex:SetColorTexture(1, 1, 1, 0.06)

  main:SetScript("OnHide", function()
    pcall(function()
      main:StopMovingOrSizing()
    end)
    savePosition()
  end)

  --- Pre-create row frames while OOC so the first pull does not build SecureUnitButtonTemplate mid-combat.
  local function warmEnemyRowPool()
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    local w = EnemyListDB.width or defaults.width
    local innerW = w - 16
    local colW = math.max(80, (innerW - COL_GAP) / 2)
    local hSaved = EnemyListDB.barHeight or defaults.barHeight
    local font = fontForPreset(EnemyListDB.fontPreset)
    local metaFont = fontMetaForPreset(EnemyListDB.fontPreset)
    local rowH = effectiveRowHeight()
    local castStripW = 0
    local dummyEntry = {
      name = " ",
      distanceText = "?",
      aggro = "?",
      targetName = "—",
    }
    for i = 1, MAX_ENEMIES_CAP do
      if not rowsAggro[i] then
        rowsAggro[i] = createBarRow(rowContainer.colAggro, "EnemyListAggro" .. i)
      end
      applyBarRow(rowsAggro[i], dummyEntry, colW, rowH, castStripW, true, font, metaFont)
      hideBarRow(rowsAggro[i], true)
      if not rowsOther[i] then
        rowsOther[i] = createBarRow(rowContainer.colOther, "EnemyListOther" .. i)
      end
      applyBarRow(rowsOther[i], dummyEntry, colW, rowH, castStripW, true, font, metaFont)
      hideBarRow(rowsOther[i], true)
    end
  end
  warmEnemyRowPool()

  local warmRegen = CreateFrame("Frame")
  warmRegen:RegisterEvent("PLAYER_REGEN_ENABLED")
  warmRegen:SetScript("OnEvent", function()
    warmEnemyRowPool()
    if main and main:IsShown() then
      layoutRows()
    end
  end)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      warmEnemyRowPool()
      if main and main:IsShown() then
        layoutRows()
      end
    end)
  end

  applyUiScale()

  --- Feature 6: fade out of combat — OnUpdate only while enabled (no per-frame work when off).
  mainFadeTickerFrame = CreateFrame("Frame")
  local fadeAcc = 0
  --- Stabilize "combat" for fade: group/player combat can read inconsistently for a few ticks, which
  --- was flashing |main| between full and dim every 0.2s. Require two consecutive "OOC" samples before
  --- dimming; go bright on combat immediately.
  local fadeOocStreak = 0
  local FADE_OOC_STREAK_DIM = 2
  local function mainFadeTickerOnUpdate(_, elapsed)
    fadeAcc = fadeAcc + elapsed
    if fadeAcc < 0.2 then
      return
    end
    fadeAcc = 0
    if not main then
      return
    end
    local function applyMainAlphaIfNeeded(a)
      local c = (main.GetAlpha and main:GetAlpha()) or 1
      if math.abs(c - a) < 0.02 then
        return
      end
      pcall(function()
        main:SetAlpha(a)
      end)
    end
    local db = type(EnemyListDB) == "table" and EnemyListDB or {}
    if db.fadeOutOfCombat then
      local inCombatCtx
      if type(EnemyList.IsEnemyListCombatActive) == "function" then
        inCombatCtx = EnemyList.IsEnemyListCombatActive()
      else
        inCombatCtx = UnitAffectingCombat("player")
      end
      if inCombatCtx then
        fadeOocStreak = 0
        applyMainAlphaIfNeeded(1)
      else
        fadeOocStreak = fadeOocStreak + 1
        if fadeOocStreak >= FADE_OOC_STREAK_DIM then
          applyMainAlphaIfNeeded(0.3)
        end
      end
    else
      fadeOocStreak = 0
      if (main.GetAlpha and main:GetAlpha() or 1) < 0.9 then
        applyMainAlphaIfNeeded(1)
      end
    end
  end

  function EnemyList.UpdateFadeOutCombatTicker()
    local f = mainFadeTickerFrame
    if not f then
      return
    end
    fadeOocStreak = 0
    local db = type(EnemyListDB) == "table" and EnemyListDB or {}
    if db.fadeOutOfCombat then
      f:Show()
      f:SetScript("OnUpdate", mainFadeTickerOnUpdate)
    else
      f:Hide()
      f:SetScript("OnUpdate", nil)
      if main and main.GetAlpha and main:GetAlpha() < 0.9 then
        main:SetAlpha(1)
      end
    end
  end

  EnemyList.UpdateFadeOutCombatTicker()

  function EnemyList.ShouldRefreshUI()
    return main ~= nil and main:IsShown()
  end
end

--- Feature 8: minimap button — lives in EnemyListMinimap.lua (assigns EnemyList._createMinimapButton
--- and EnemyList._applyMinimapButtonVisibility). The helpers below are thin shims so the rest of
--- this file keeps the original call-site names.
local function createMinimapButton()
  if EnemyList._createMinimapButton then
    EnemyList._createMinimapButton()
  end
end
local function enemyListApplyMinimapButtonVisibility()
  if EnemyList._applyMinimapButtonVisibility then
    EnemyList._applyMinimapButtonVisibility()
  end
end

--- Base content width, capped by the **active** tab's scroll (when it reports a sane width) so it never exceeds the real child.
--- Hidden tabs often return 0; child-specific code must also do |min(base, parent:GetWidth())| per control row.
local function configFrameContentInnerForLayout(cf)
  cf = cf or configFrame
  if not cf then
    return 300
  end
  local base = cf._elInnerW
  if not base and cf._elScrollChild then
    base = cf._elScrollChild:GetWidth()
  end
  base = base or 300
  if cf._elActiveScrollChild and cf._elActiveScrollChild.GetWidth then
    local w = cf._elActiveScrollChild:GetWidth()
    if w and w > 32 then
      return math.min(base, w)
    end
  end
  return base
end

--- |min| of layout base and a specific scroll child (e.g. Appearance = |_elScrollChild|) so a row never exceeds its pane.
local function minInnerForScrollW(base, sc)
  if not sc or not sc.GetWidth then
    return base
  end
  local w = sc:GetWidth()
  if w and w > 32 and base then
    return math.min(base, w)
  end
  return base
end

--- Resize tab strip and sort-order buttons to match the **Appearance** scroll (sort row is on |_elScrollChild| only).
local function layoutConfigTabsAndSortRow(cf)
  cf = cf or configFrame
  if not cf then
    return
  end
  local inner = minInnerForScrollW(configFrameContentInnerForLayout(cf), cf._elScrollChild)
  local sbW = cf._elResizeSbW or 20
  local sbGap = cf._elResizeSbGap or 4
  local tabTotalW = math.max(200, math.floor(inner + sbW + sbGap + 0.5))

  if cf._elTabBar and cf._elTabs then
    cf._elTabBar:SetWidth(tabTotalW)
    local tabH = 22
    local nTabs = #cf._elTabs
    if nTabs > 0 then
      local tabGap = 2
      local tabW = math.max(52, math.floor((tabTotalW - (nTabs - 1) * tabGap) / nTabs))
      for i, tab in ipairs(cf._elTabs) do
        if tab and tab.SetSize and tab.SetPoint then
          tab:SetSize(tabW, tabH)
          tab:ClearAllPoints()
          tab:SetPoint("TOPLEFT", cf._elTabBar, "TOPLEFT", (i - 1) * (tabW + tabGap), 0)
        end
      end
    end
  end

  if cf._elSortRow and cf._elSortBtns then
    cf._elSortRow:SetWidth(inner)
    local n = #cf._elSortBtns
    if n > 0 then
      local btnGap = 2
      local leftPad = 4
      local gaps = (n - 1) * btnGap
      local usable = inner - leftPad * 2 - gaps
      local btnW = math.max(1, math.floor(usable / n))
      if 2 * leftPad + n * btnW + gaps > inner then
        btnW = math.max(1, math.floor((inner - 2 * leftPad - gaps) / n))
      end
      for j, btn in ipairs(cf._elSortBtns) do
        if btn and btn.SetSize and btn.SetPoint then
          btn:SetSize(btnW, 20)
          btn:ClearAllPoints()
          btn:SetPoint("TOPLEFT", cf._elSortRow, "TOPLEFT", leftPad + (j - 1) * (btnW + btnGap), -14)
          local fs = btn.GetFontString and btn:GetFontString()
          if fs and fs.SetWidth and fs.SetJustifyH then
            fs:SetWidth(math.max(4, btnW - 6))
            fs:SetJustifyH("CENTER")
          end
        end
      end
      if cf._elSortRow.SetClipsChildren then
        pcall(function()
          cf._elSortRow:SetClipsChildren(true)
        end)
      end
    end
  end
end

--- Re-layout HP / mana / name "tab" pickers in Party + Raid panels (4- or 3-wide buttons) when |inner| changes.
--- Each |row| is parented to a tab scroll child; a **hidden** tab can report 0 from |GetWidth| — use |_elInnerW| then.
local function layoutConfigPositionButtonRows(cf)
  cf = cf or configFrame
  if not cf or not cf._elConfigPositionRows then
    return
  end
  local W = EnemyList.ConfigWidgets
  local baseW = configFrameContentInnerForLayout(cf)
  for _, row in ipairs(cf._elConfigPositionRows) do
    if row and type(row._btns) == "table" and row.SetWidth then
      local n = #row._btns
      local parent = row.GetParent and row:GetParent()
      local pw
      if parent and parent.GetWidth then
        pw = parent:GetWidth()
      end
      local wuse = baseW
      if pw and pw > 32 then
        wuse = math.min(baseW, pw)
      end
      local rowW = math.max(60, wuse)
      if n > 0 and rowW > 60 then
        W.LayoutStyleButtonRow(row, rowW, n)
      end
    end
  end
end

--- Colors tab: every label+swatch row is |innerW-16| (8px side pad) at build; widen on resize.
local function layoutConfigColorSwatchRows(cf)
  cf = cf or configFrame
  if not cf or not cf._elConfigColorSwatchRows then
    return
  end
  local sc4 = cf._elTabScrollChildren and cf._elTabScrollChildren[4]
  local inner = minInnerForScrollW(configFrameContentInnerForLayout(cf), sc4)
  if cf._elColorsTopMark and cf._elColorsTopMark.SetWidth then
    cf._elColorsTopMark:SetWidth(inner)
  end
  local rw = math.max(120, inner - 16)
  for _, row in ipairs(cf._elConfigColorSwatchRows) do
    if row and row.SetWidth then
      row:SetWidth(rw)
    end
  end
end

--- Raid tab: top marker + load button stretch with |inner|.
local function layoutConfigRaidTabChrome(cf)
  cf = cf or configFrame
  local sc6 = cf._elTabScrollChildren and cf._elTabScrollChildren[6]
  local inner = minInnerForScrollW(configFrameContentInnerForLayout(cf), sc6)
  local p = cf._elRaidTopMark and cf._elRaidTopMark.GetParent and cf._elRaidTopMark:GetParent()
  if p and p.GetWidth then
    local w = p:GetWidth()
    if w and w > 32 then
      inner = math.min(inner, w)
    end
  end
  if cf._elRaidTopMark and cf._elRaidTopMark.SetWidth then
    cf._elRaidTopMark:SetWidth(inner)
  end
  if cf._elRaidLoadBtn and cf._elRaidLoadBtn.SetWidth and cf._elRaidLoadBtn.SetHeight then
    cf._elRaidLoadBtn:SetSize(math.min(340, math.max(150, inner - 24)), 26)
  end
end

local function syncConfigInnerLayout(cf)
  cf = cf or configFrame
  if not cf or not cf._elScrollChild then
    return
  end
  local pad = cf._elResizePad or 6
  local sbW = cf._elResizeSbW or 20
  local sbGap = cf._elResizeSbGap or 4
  local w = cf:GetWidth()
  local newInner = math.floor(w - pad * 2 - sbW - sbGap + 0.5)
  newInner = math.max(260, newInner)
  cf._elInnerW = newInner
  --- All tab panes (Appearance + every secondary scroll child) need the new inner width or controls stay narrow.
  for _, sc in ipairs(cf._elTabScrollChildren or { cf._elScrollChild }) do
    if sc and sc.SetWidth then
      sc:SetWidth(newInner)
    end
  end
  if cf._elScrollTopMark then
    cf._elScrollTopMark:SetWidth(newInner)
  end
  for _, tex in ipairs(cf._elSectionLines or {}) do
    if tex and tex.SetWidth then
      tex:SetWidth(newInner - CONFIG_SECTION_LINE_TRIM)
    end
  end
  for _, fr in ipairs(cf._elWideRows or {}) do
    if fr and fr.SetWidth then
      fr:SetWidth(newInner)
    end
  end
  --- Re-run slider layout so value column (px / %) has room after width change (Party/Raid use |_elDisplaySliders|).
  if layoutConfigOptionSliderColumns then
    layoutConfigOptionSliderColumns(cf)
  end
  if cf._elTestHint then
    cf._elTestHint:SetWidth(newInner - 28)
  end
  --- Word-wrapped help text: width was fixed at build time from |innerW|; widen when the window is resized.
  for _, p in ipairs({
    { "_elColorsDesc", 12 },
    { "_elProfDesc", 12 },
    { "_elSavedHint", 12 },
    { "_elRaidDesc", 12 },
    { "_elRaidNote", 12 },
    { "_elPartyPanelDesc", 12 },
    { "_elRaidPanelDesc", 12 },
  }) do
    local fs = cf[p[1]]
    if fs and fs.SetWidth then
      fs:SetWidth(math.max(120, newInner - p[2]))
    end
  end
  if cf._elCliqueTopMark and cf._elCliqueTopMark.SetWidth then
    cf._elCliqueTopMark:SetWidth(newInner)
  end
  if cf._elKeybindsBodyFs and cf._elKeybindsBodyFs.SetWidth then
    cf._elKeybindsBodyFs:SetWidth(math.max(120, newInner - 16))
  end
  layoutConfigTabsAndSortRow(cf)
  layoutConfigPositionButtonRows(cf)
  layoutConfigColorSwatchRows(cf)
  if cf._elLayoutProfilesTab then
    cf._elLayoutProfilesTab()
  end
  layoutConfigRaidTabChrome(cf)
  if cf._elSyncScroll then
    cf._elSyncScroll()
  end
  if cf._elResizeAppearanceScroll and (not cf.IsShown or cf:IsShown()) and C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if cf and cf._elResizeAppearanceScroll and (not cf.IsShown or cf:IsShown()) then
        cf._elResizeAppearanceScroll()
      end
    end)
  end
end

--- Blizzard StartSizing often does nothing on this shell (EnableMouse off / client quirks). Resize by cursor delta instead.
local function configManualResizeTick()
  local cf = configFrame
  if not cf or not cf._elManualResize then
    return
  end
  local scale = 1
  if UIParent and UIParent.GetEffectiveScale then
    scale = UIParent:GetEffectiveScale() or 1
  end
  if scale < 0.01 then
    scale = 1
  end
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  local nw = cf._elResizeStartW + (cx - cf._elResizeStartCX)
  --- Screen Y increases upward; dragging down should grow height (bottom edge moves down).
  local nh = cf._elResizeStartH - (cy - cf._elResizeStartCY)
  nw = math.max(CONFIG_RESIZE_MIN_W, math.min(CONFIG_RESIZE_MAX_W, math.floor(nw + 0.5)))
  nh = math.max(CONFIG_RESIZE_MIN_H, math.min(CONFIG_RESIZE_MAX_H, math.floor(nh + 0.5)))
  cf._elConfigSkipSize = true
  cf:SetSize(nw, nh)
  cf._elConfigSkipSize = false
  syncConfigInnerLayout(cf)
end

local function finishConfigResize()
  local cf = configFrame
  if not cf or not cf._elConfigSizing then
    return
  end
  if cf._elManualResize then
    cf:SetScript("OnUpdate", nil)
    cf._elManualResize = false
  end
  pcall(function()
    cf:StopMovingOrSizing()
  end)
  cf._elConfigSizing = false
  local w = math.floor(cf:GetWidth() + 0.5)
  local h = math.floor(cf:GetHeight() + 0.5)
  w = math.max(CONFIG_RESIZE_MIN_W, math.min(CONFIG_RESIZE_MAX_W, w))
  h = math.max(CONFIG_RESIZE_MIN_H, math.min(CONFIG_RESIZE_MAX_H, h))
  EnemyListDB.configWindowWidth = w
  EnemyListDB.configWindowHeight = h
  cf._elConfigSkipSize = true
  cf:SetSize(w, h)
  cf._elConfigSkipSize = false
  syncConfigInnerLayout(cf)
end

function refreshConfigFieldsFromDB(cf)
  if not cf then
    return
  end
  if cf._elCompactCheck then
    cf._elCompactCheck:SetChecked(EnemyListDB.compactRow and true or false)
  end
  if cf._elTruncateNamesCheck then
    cf._elTruncateNamesCheck:SetChecked(EnemyListDB.truncateLongNames ~= false)
  end
  if cf._elMaxNameLenSlider and cf._elMaxNameLenSlider.setValueSilent then
    cf._elMaxNameLenSlider:setValueSilent(tonumber(EnemyListDB.maxNameLength) or defaults.maxNameLength)
  end
  if cf._elBgCheck then
    cf._elBgCheck:SetChecked(EnemyListDB.showBackground ~= false)
  end
  if cf._elSingleColCheck then
    cf._elSingleColCheck:SetChecked(EnemyListDB.singleColumn and true or false)
  end
  if cf._elGridCheck then
    cf._elGridCheck:SetChecked(EnemyListDB.gridMode and true or false)
  end
  if cf._elGridSizeSlider and cf._elGridSizeSlider.setValueSilent then
    cf._elGridSizeSlider:setValueSilent(tonumber(EnemyListDB.gridCellSize) or defaults.gridCellSize)
  end
  if cf._elGridColSlider and cf._elGridColSlider.setValueSilent then
    cf._elGridColSlider:setValueSilent(tonumber(EnemyListDB.gridColumns) or defaults.gridColumns)
  end
  if cf._elNameplateRangeCheck then
    cf._elNameplateRangeCheck:SetChecked(EnemyListDB.extendNameplateRange ~= false)
  end
  if cf._elNameplateThreatCheck then
    cf._elNameplateThreatCheck:SetChecked(EnemyListDB.nameplateThreatOverlay and true or false)
  end
  if cf._elNameplateMirrorCheck then
    cf._elNameplateMirrorCheck:SetChecked(EnemyListDB.nameplateListMirror and true or false)
  end
  if cf._elNameplateThreatSecondCheck then
    cf._elNameplateThreatSecondCheck:SetChecked(EnemyListDB.nameplateThreatSecondStyle and true or false)
  end
  if cf._elSecondThreatAggroCheck then
    cf._elSecondThreatAggroCheck:SetChecked(EnemyListDB.listShowSecondInAggroSection and true or false)
  end
  if cf._elFontSlider and cf._elFontSlider.setValueSilent then
    cf._elFontSlider:setValueSilent(EnemyListDB.fontPreset or defaults.fontPreset)
  end
  if cf._elMaxAggroSlider and cf._elMaxAggroSlider.setValueSilent then
    cf._elMaxAggroSlider:setValueSilent(EnemyListDB.maxEnemiesAggro or defaults.maxEnemiesAggro)
  end
  if cf._elMaxOtherSlider and cf._elMaxOtherSlider.setValueSilent then
    cf._elMaxOtherSlider:setValueSilent(EnemyListDB.maxEnemiesOther or defaults.maxEnemiesOther)
  end
  if cf._elInactivitySlider and cf._elInactivitySlider.setValueSilent then
    cf._elInactivitySlider:setValueSilent(tonumber(EnemyListDB.enemyInactivityFilterSec) or defaults.enemyInactivityFilterSec)
  end
  if cf._elScaleSlider and cf._elScaleSlider.setValueSilent then
    cf._elScaleSlider:setValueSilent(tonumber(EnemyListDB.uiScale) or defaults.uiScale)
  end
  if cf._elOpacitySlider and cf._elOpacitySlider.setValueSilent then
    cf._elOpacitySlider:setValueSilent(tonumber(EnemyListDB.barOpacity) or defaults.barOpacity)
  end
  if cf._elWidthSlider and cf._elWidthSlider.setValueSilent then
    cf._elWidthSlider:setValueSilent(tonumber(EnemyListDB.width) or defaults.width)
  end
  if cf._elHpBarHSlider and cf._elHpBarHSlider.setValueSilent then
    cf._elHpBarHSlider:setValueSilent(tonumber(EnemyListDB.healthBarHeight) or defaults.healthBarHeight)
  end
  if cf._elThreatBarCheck then
    cf._elThreatBarCheck:SetChecked(EnemyListDB.showThreatBar ~= false)
  end
  if cf._elThreatBarHSlider and cf._elThreatBarHSlider.setValueSilent then
    cf._elThreatBarHSlider:setValueSilent(tonumber(EnemyListDB.threatBarHeight) or defaults.threatBarHeight)
  end
  if cf._elSecondOnThreatBarCheck then
    cf._elSecondOnThreatBarCheck:SetChecked(EnemyListDB.showSecondOnThreatBar ~= false)
  end
  if cf._elRunnerUpCheck then
    cf._elRunnerUpCheck:SetChecked(EnemyListDB.showRunnerUpBars == true)
  end
  if cf._elRunnerUpCountSlider and cf._elRunnerUpCountSlider.setValueSilent then
    cf._elRunnerUpCountSlider:setValueSilent(tonumber(EnemyListDB.runnerUpBarCount) or defaults.runnerUpBarCount)
  end
  if cf._elRunnerUpHeightSlider and cf._elRunnerUpHeightSlider.setValueSilent then
    cf._elRunnerUpHeightSlider:setValueSilent(tonumber(EnemyListDB.runnerUpBarHeight) or defaults.runnerUpBarHeight)
  end
  if cf._elCastBarCheck then
    cf._elCastBarCheck:SetChecked(EnemyListDB.showCastBar ~= false)
  end
  if cf._elCastBarHSlider and cf._elCastBarHSlider.setValueSilent then
    cf._elCastBarHSlider:setValueSilent(tonumber(EnemyListDB.castBarHeight) or defaults.castBarHeight)
  end
  if cf._elRaidMarkerCheck then
    cf._elRaidMarkerCheck:SetChecked(EnemyListDB.showRaidMarkers ~= false)
  end
  if cf._elSelfToTCheck then
    cf._elSelfToTCheck:SetChecked(EnemyListDB.showSelfToT and true or false)
  end
  if cf._elPartyCombatCheck then
    cf._elPartyCombatCheck:SetChecked(EnemyListDB.showPartyCombatEnemies and true or false)
  end
  cf._elLockCheck:SetChecked(EnemyListDB.locked and true or false)
  if cf._elTestCheck then
    cf._elTestCheck:SetChecked(type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn() or false)
  end
  if cf._elCoalesceRefreshCheck then
    cf._elCoalesceRefreshCheck:SetChecked(EnemyListDB.coalesceUIRefresh ~= false)
  end
  if cf._elFadeCheck then
    cf._elFadeCheck:SetChecked(EnemyListDB.fadeOutOfCombat and true or false)
  end
  if cf._elHealerCheck then
    cf._elHealerCheck:SetChecked(EnemyListDB.healerMode and true or false)
  end
  if cf._elMinimapShowCheck then
    cf._elMinimapShowCheck:SetChecked(EnemyListDB.minimapButtonHidden ~= true)
  end
  --- Party and Raid tabs each own a full party-frame control panel. Iterate both so the widgets
  --- show the values from their respective profile — not the top-level (active) state.
  local function syncPartyPanel(panel)
    if not panel then return end
    local pn = panel.profileName
    local function rBool(key, defaultFalse)
      local v = _EL.profileRead(pn, key)
      if defaultFalse then return v and true or false end
      return v ~= false
    end
    local function rNum(key)
      return tonumber(_EL.profileRead(pn, key)) or defaults[key]
    end
    if panel.partyCheck                then panel.partyCheck:SetChecked(rBool("showPartyFrames", true)) end
    if panel.partySizeSlider and panel.partySizeSlider.setValueSilent then
      panel.partySizeSlider:setValueSilent(rNum("partyFrameSize"))
    end
    if panel.partyVerticalCheck        then panel.partyVerticalCheck:SetChecked(rBool("partyFrameVertical", true)) end
    if panel.partyUnitGapSlider and panel.partyUnitGapSlider.setValueSilent then
      panel.partyUnitGapSlider:setValueSilent(rNum("partyFrameUnitGap"))
    end
    if panel.partyGroupGapSlider and panel.partyGroupGapSlider.setValueSilent then
      panel.partyGroupGapSlider:setValueSilent(rNum("partyFrameGroupGap"))
    end
    if panel.partyHpDeficitCheck       then panel.partyHpDeficitCheck:SetChecked(rBool("partyFrameShowHpDeficit", false)) end
    if panel.partyDebuffCheck          then panel.partyDebuffCheck:SetChecked(rBool("partyFrameShowDebuffs", false)) end
    if panel.partyHealthBarHeight and panel.partyHealthBarHeight.setValueSilent then
      panel.partyHealthBarHeight:setValueSilent(rNum("partyFrameHealthBarHeight"))
    end
    if panel.partyHpDeficitFontScale and panel.partyHpDeficitFontScale.setValueSilent then
      panel.partyHpDeficitFontScale:setValueSilent(tonumber(_EL.profileRead(pn, "partyFrameHpDeficitFontScale")) or defaults.partyFrameHpDeficitFontScale)
    end
    if panel.partyAggroCountFontScale and panel.partyAggroCountFontScale.setValueSilent then
      panel.partyAggroCountFontScale:setValueSilent(tonumber(_EL.profileRead(pn, "partyFrameAggroCountFontScale")) or defaults.partyFrameAggroCountFontScale)
    end
    if panel.partySelfCountCheck       then panel.partySelfCountCheck:SetChecked(rBool("showSelfAggroCount", false)) end
    if panel.incHealCheck              then panel.incHealCheck:SetChecked(rBool("partyShowIncomingHeals", true)) end
    if panel.petCheck                  then panel.petCheck:SetChecked(rBool("partyShowPets", false)) end
    if panel.playerBuffsCheck          then panel.playerBuffsCheck:SetChecked(rBool("partyShowPlayerBuffs", false)) end
    if panel.playerBuffSlotsSlider and panel.playerBuffSlotsSlider.setValueSilent then
      panel.playerBuffSlotsSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyPlayerBuffSlotCount")) or defaults.partyPlayerBuffSlotCount)
    end
    if panel.playerBuffSizeSlider and panel.playerBuffSizeSlider.setValueSilent then
      panel.playerBuffSizeSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyPlayerBuffIconSize")) or defaults.partyPlayerBuffIconSize)
    end
    if panel.playerBuffMaxDurSlider and panel.playerBuffMaxDurSlider.setValueSilent then
      panel.playerBuffMaxDurSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyPlayerBuffMaxDuration")) or defaults.partyPlayerBuffMaxDuration)
    end
    if panel.playerBuffPosRefresh then panel.playerBuffPosRefresh() end
    if panel.playerBuffOffsetXSlider and panel.playerBuffOffsetXSlider.setValueSilent then
      panel.playerBuffOffsetXSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyPlayerBuffOffsetX")) or 0)
    end
    if panel.playerBuffOffsetYSlider and panel.playerBuffOffsetYSlider.setValueSilent then
      panel.playerBuffOffsetYSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyPlayerBuffOffsetY")) or 0)
    end
    if panel.partyManaCheck            then panel.partyManaCheck:SetChecked(rBool("showPartyManaBars", true)) end
    if panel.partyManaHeightSlider and panel.partyManaHeightSlider.setValueSilent then
      panel.partyManaHeightSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyManaBarHeight")) or defaults.partyManaBarHeight)
    end
    if panel.hpPosRefresh then panel.hpPosRefresh() end
    if panel.manaPosRefresh then panel.manaPosRefresh() end
    if panel.namePosRefresh then panel.namePosRefresh() end
    if panel.nameOffsetXSlider and panel.nameOffsetXSlider.setValueSilent then
      panel.nameOffsetXSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyFrameNameOffsetX")) or 0)
    end
    if panel.nameOffsetYSlider and panel.nameOffsetYSlider.setValueSilent then
      panel.nameOffsetYSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyFrameNameOffsetY")) or 0)
    end
    if panel.aggroCountOffsetXSlider and panel.aggroCountOffsetXSlider.setValueSilent then
      panel.aggroCountOffsetXSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyAggroCountOffsetX")) or 0)
    end
    if panel.aggroCountOffsetYSlider and panel.aggroCountOffsetYSlider.setValueSilent then
      panel.aggroCountOffsetYSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyAggroCountOffsetY")) or 0)
    end
    if panel.aggroBorderCheck            then panel.aggroBorderCheck:SetChecked(rBool("partyShowAggroBorder", false)) end
    if panel.aggroBorderCustomColorCheck then panel.aggroBorderCustomColorCheck:SetChecked(rBool("partyUseCustomAggroBorderColor", true)) end
    if panel.aggroBorderThicknessSlider and panel.aggroBorderThicknessSlider.setValueSilent then
      panel.aggroBorderThicknessSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyAggroBorderThickness")) or defaults.partyAggroBorderThickness)
    end
    if panel.nameCheck                 then panel.nameCheck:SetChecked(rBool("partyFrameShowName", true)) end
    if panel.nameFontScaleSlider and panel.nameFontScaleSlider.setValueSilent then
      panel.nameFontScaleSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyFrameNameFontScale")) or defaults.partyFrameNameFontScale)
    end
    if panel.lowHpCheck                then panel.lowHpCheck:SetChecked(rBool("partyLowHpFlashEnabled", true)) end
    if panel.lowHpThresholdSlider and panel.lowHpThresholdSlider.setValueSilent then
      panel.lowHpThresholdSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyLowHpThreshold")) or defaults.partyLowHpThreshold)
    end
    if panel.lowManaCheck              then panel.lowManaCheck:SetChecked(rBool("partyLowManaFlashEnabled", true)) end
    if panel.lowManaThresholdSlider and panel.lowManaThresholdSlider.setValueSilent then
      panel.lowManaThresholdSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyLowManaThreshold")) or defaults.partyLowManaThreshold)
    end
    if panel.roleIconCheck             then panel.roleIconCheck:SetChecked(rBool("partyShowRoleIcon", false)) end
    if panel.roleIconSizeSlider and panel.roleIconSizeSlider.setValueSilent then
      panel.roleIconSizeSlider:setValueSilent(tonumber(_EL.profileRead(pn, "partyRoleIconSize")) or defaults.partyRoleIconSize)
    end
  end
  syncPartyPanel(cf._elPartyPanel)
  syncPartyPanel(cf._elRaidPanel)
  refreshPartyHpDeficitColorSwatches()
  refreshPartyAggroCountSwatch()
  if cf._elAutoSwitchProfileCheck then
    cf._elAutoSwitchProfileCheck:SetChecked(EnemyListDB.autoSwitchProfile ~= false)
  end
  if cf._elProfilesRefresh then
    cf._elProfilesRefresh()
  end
  if cf._elUseClassColorsPartyCheck then
    cf._elUseClassColorsPartyCheck:SetChecked(_EL.useClassColorsParty())
  end
  --- "Show mana bar" + "Mana bar height" moved to the Party / Raid tabs; only the power-type
  --- coloring toggle still lives on the Colors tab.
  if cf._elUsePowerTypeColorsCheck then
    cf._elUsePowerTypeColorsCheck:SetChecked(_EL.usePowerTypeColorsParty())
  end
  if cf._elHideInRaidCheck then
    cf._elHideInRaidCheck:SetChecked(EnemyListDB.hidePartyFramesInRaid == true)
  end
  if cf._elRaidRefresh then
    cf._elRaidRefresh()
  end
  if cf._elRefreshColorSwatches then
    cf._elRefreshColorSwatches()
  end
end

local function saveConfigFields(cf)
  if not cf then
    return
  end
  if cf._elCompactCheck then
    EnemyListDB.compactRow = cf._elCompactCheck:GetChecked() and true or false
  end
  if cf._elTruncateNamesCheck then
    EnemyListDB.truncateLongNames = cf._elTruncateNamesCheck:GetChecked() and true or false
  end
  if cf._elMaxNameLenSlider then
    EnemyListDB.maxNameLength = math.max(4, math.min(40, math.floor(cf._elMaxNameLenSlider:GetValue() + 0.5)))
  end
  if cf._elBgCheck then
    EnemyListDB.showBackground = cf._elBgCheck:GetChecked() and true or false
    applyMainBackground()
  end
  if cf._elSingleColCheck then
    EnemyListDB.singleColumn = cf._elSingleColCheck:GetChecked() and true or false
  end
  if cf._elGridCheck then
    EnemyListDB.gridMode = cf._elGridCheck:GetChecked() and true or false
  end
  if cf._elGridSizeSlider then
    EnemyListDB.gridCellSize = math.max(30, math.min(100, math.floor(cf._elGridSizeSlider:GetValue() + 0.5)))
  end
  if cf._elGridColSlider then
    EnemyListDB.gridColumns = math.max(1, math.min(5, math.floor(cf._elGridColSlider:GetValue() + 0.5)))
  end
  if cf._elNameplateRangeCheck then
    EnemyListDB.extendNameplateRange = cf._elNameplateRangeCheck:GetChecked() and true or false
  end
  if cf._elNameplateThreatCheck then
    EnemyListDB.nameplateThreatOverlay = cf._elNameplateThreatCheck:GetChecked() and true or false
    if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
      EnemyList.RefreshNameplateThreatOverlays(true)
    end
  end
  if cf._elNameplateMirrorCheck then
    EnemyListDB.nameplateListMirror = cf._elNameplateMirrorCheck:GetChecked() and true or false
    if type(EnemyList.RefreshNameplateListMirrors) == "function" then
      EnemyList.RefreshNameplateListMirrors(true)
    end
  end
  if cf._elNameplateThreatSecondCheck then
    EnemyListDB.nameplateThreatSecondStyle = cf._elNameplateThreatSecondCheck:GetChecked() and true or false
    if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
      EnemyList.RefreshNameplateThreatOverlays(true)
    end
  end
  if cf._elSecondThreatAggroCheck then
    EnemyListDB.listShowSecondInAggroSection = cf._elSecondThreatAggroCheck:GetChecked() and true or false
  end
  if cf._elFontSlider then
    EnemyListDB.fontPreset = math.min(FONT_PRESET_MAX, math.max(2, math.floor(cf._elFontSlider:GetValue() + 0.5)))
  end
  if cf._elMaxAggroSlider then
    EnemyListDB.maxEnemiesAggro = math.min(MAX_ENEMIES_CAP, math.max(1, math.floor(cf._elMaxAggroSlider:GetValue() + 0.5)))
  end
  if cf._elMaxOtherSlider then
    EnemyListDB.maxEnemiesOther = math.min(MAX_ENEMIES_CAP, math.max(1, math.floor(cf._elMaxOtherSlider:GetValue() + 0.5)))
  end
  if cf._elInactivitySlider then
    EnemyListDB.enemyInactivityFilterSec = math.min(ENEMY_INACTIVITY_FILTER_SEC_MAX, math.max(ENEMY_INACTIVITY_FILTER_SEC_MIN, math.floor(cf._elInactivitySlider:GetValue() + 0.5)))
  end
  if cf._elOpacitySlider then
    EnemyListDB.barOpacity = math.max(0.1, math.min(1.0, cf._elOpacitySlider:GetValue()))
  end
  if cf._elWidthSlider then
    EnemyListDB.width = math.max(80, math.min(500, math.floor(cf._elWidthSlider:GetValue() + 0.5)))
  end
  if cf._elHpBarHSlider then
    EnemyListDB.healthBarHeight = math.max(6, math.min(40, math.floor(cf._elHpBarHSlider:GetValue() + 0.5)))
  end
  if cf._elThreatBarCheck then
    EnemyListDB.showThreatBar = cf._elThreatBarCheck:GetChecked() and true or false
  end
  if cf._elThreatBarHSlider then
    EnemyListDB.threatBarHeight = math.max(3, math.min(20, math.floor(cf._elThreatBarHSlider:GetValue() + 0.5)))
  end
  if cf._elSecondOnThreatBarCheck then
    EnemyListDB.showSecondOnThreatBar = cf._elSecondOnThreatBarCheck:GetChecked() and true or false
  end
  if cf._elCastBarCheck then
    EnemyListDB.showCastBar = cf._elCastBarCheck:GetChecked() and true or false
  end
  if cf._elCastBarHSlider then
    EnemyListDB.castBarHeight = math.max(3, math.min(20, math.floor(cf._elCastBarHSlider:GetValue() + 0.5)))
  end
  if cf._elRaidMarkerCheck then
    EnemyListDB.showRaidMarkers = cf._elRaidMarkerCheck:GetChecked() and true or false
  end
  if cf._elSelfToTCheck then
    EnemyListDB.showSelfToT = cf._elSelfToTCheck:GetChecked() and true or false
  end
  if cf._elPartyCombatCheck then
    EnemyListDB.showPartyCombatEnemies = cf._elPartyCombatCheck:GetChecked() and true or false
  end
  if cf._elScaleSlider then
    local sc = cf._elScaleSlider:GetValue()
    EnemyListDB.uiScale = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, sc))
  end
  EnemyListDB.locked = cf._elLockCheck:GetChecked() and true or false
  EnemyListDB.testMode = cf._elTestCheck and (cf._elTestCheck:GetChecked() and true or false) or false
  if cf._elCoalesceRefreshCheck then
    EnemyListDB.coalesceUIRefresh = cf._elCoalesceRefreshCheck:GetChecked() and true or false
  end
  if cf._elFadeCheck then
    EnemyListDB.fadeOutOfCombat = cf._elFadeCheck:GetChecked() and true or false
    if type(EnemyList.UpdateFadeOutCombatTicker) == "function" then
      EnemyList.UpdateFadeOutCombatTicker()
    end
  end
  if cf._elHealerCheck then
    EnemyListDB.healerMode = cf._elHealerCheck:GetChecked() and true or false
  end
  if cf._elMinimapShowCheck then
    EnemyListDB.minimapButtonHidden = not cf._elMinimapShowCheck:GetChecked()
    elSafe("createMinimapButton", createMinimapButton)
    enemyListApplyMinimapButtonVisibility()
  end
  --- Party and Raid panel controls now persist on their own onChange handlers (via _EL.profileWrite),
  --- so Save simply triggers one more refresh. Nothing to read here — all state is already in DB.
  if cf._elPartyPanel or cf._elRaidPanel then
    updatePartyFrameSize()
  end
  if type(EnemyList.ApplyNameplateRangePreference) == "function" then
    EnemyList.ApplyNameplateRangePreference()
  end
  --- |layoutRows| → |applyMainLayoutSize| refreshes |mainScaleRoot| size and calls |applyUiScale|.
  layoutRows()
end

--- Works for named or unnamed UICheckButtonTemplate buttons (shares |SetBooleanLabel| in config widgets).
local function setCheckButtonLabel(btn, text)
  return EnemyList.ConfigWidgets and EnemyList.ConfigWidgets.SetBooleanLabel(btn, text)
end

local function styleConfigEditBox(eb, w, h)
  eb:SetSize(w, h)
  eb:SetFontObject("ChatFontNormal")
  eb:SetAutoFocus(false)
  eb:SetTextInsets(8, 8, 6, 6)
  if eb.SetBackdrop then
    pcall(function()
      eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      eb:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
      eb:SetBackdropBorderColor(1, 1, 1, 0.14)
    end)
  end
end

layoutConfigSpellRows = nil

--- Sliders: |EnemyListConfigWidgets.CreateOptionSlider| + |LayoutOptionSliderRow|.
local function createConfigOptionSlider(row, opts)
  return EnemyList.ConfigWidgets.CreateOptionSlider(row, opts)
end

layoutConfigOptionSliderColumns = function(cf)
  cf = cf or configFrame
  if not cf or not cf._elDisplaySliders then
    return
  end
  local W = EnemyList.ConfigWidgets
  local baseW = configFrameContentInnerForLayout(cf)
  for _, slider in ipairs(cf._elDisplaySliders) do
    if slider and slider._elRow and slider._elLabelFs then
      local row = slider._elRow
      local inner = baseW
      local p = row and row.GetParent and row:GetParent()
      if p and p.GetWidth then
        local pw = p:GetWidth()
        if pw and pw > 32 then
          inner = math.min(baseW, pw)
        end
      end
      W.LayoutOptionSliderRow(slider, inner)
    end
  end
end

local function addConfigSectionHeader(parent, anchor, offsetY, title, helpTooltip, lineW)
  lineW = lineW or 400
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
  fs:SetText(title)
  fs:SetTextColor(0.84, 0.87, 0.92)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetSize(lineW, 1)
  local okLine = pcall(function()
    line:SetColorTexture(1, 1, 1, 0.12)
  end)
  if not okLine then
    pcall(function()
      line:SetTexture("Interface\\Buttons\\WHITE8X8")
      line:SetVertexColor(1, 1, 1, 0.12)
    end)
  end
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
  if helpTooltip and helpTooltip ~= "" then
    local hb = CreateFrame("Button", nil, parent)
    hb:SetSize(22, 22)
    hb:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    hb:SetNormalFontObject("GameFontNormalSmall")
    hb:SetText("?")
    hb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(helpTooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    hb:SetScript("OnLeave", GameTooltip_Hide)
  end
  return fs, line
end

local function createConfigFrame()
  --- Compact window; scrollable body. Backdrop lives on a low z-order child so it stays behind controls.
  local cfgW = EnemyListDB.configWindowWidth or defaults.configWindowWidth
  local cfgH = EnemyListDB.configWindowHeight or defaults.configWindowHeight
  local pad = 6
  local footerReserve = 56
  local sbW = 20
  local sbGap = 4
  local innerW = cfgW - pad * 2 - sbW - sbGap
  local lineTrim = 8
  --- Floor only; |_elResizeAppearanceScroll| sets the true height after layout (avoids huge empty scroll).
  local contentH = 1500
  local editBackdropTmpl = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  --- Sibling frame levels: background lowest (drawn behind UI); controls above.
  local zBg = 1
  local zScroll = 15
  local zScrollBar = 35
  local zChrome = 45
  local zFooter = 50

  configFrame = CreateFrame("Frame", nil, UIParent)
  configFrame:SetSize(cfgW, cfgH)
  configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  configFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  configFrame:SetFrameLevel(250)
  if configFrame.SetToplevel then
    configFrame:SetToplevel(true)
  end
  --- Sliders fire OnValueChanged while the frame is built; block DB writes until refreshConfigFieldsFromDB runs.
  configFrame._elSlidersReady = false
  local function configSliderDbGate()
    return configFrame and configFrame._elSlidersReady
  end
  configFrame:SetClampedToScreen(true)
  configFrame:SetMovable(true)
  --- Shell must not eat clicks — only child widgets (drag bar, scroll content, footer) handle mouse.
  configFrame:EnableMouse(false)
  if configFrame.SetMouseMotionEnabled then
    configFrame:SetMouseMotionEnabled(false)
  end
  if configFrame.SetMouseClickEnabled then
    configFrame:SetMouseClickEnabled(false)
  end
  configFrame:SetResizable(true)
  if configFrame.SetResizeBounds then
    pcall(function()
      configFrame:SetResizeBounds(CONFIG_RESIZE_MIN_W, CONFIG_RESIZE_MIN_H, CONFIG_RESIZE_MAX_W, CONFIG_RESIZE_MAX_H)
    end)
  end
  configFrame._elConfigSkipSize = false
  configFrame._elConfigSizing = false
  configFrame._elManualResize = false
  configFrame._elResizePad = pad
  configFrame._elResizeSbW = sbW
  configFrame._elResizeSbGap = sbGap
  configFrame:SetScript("OnShow", function(self)
    if self._elSyncScroll then
      self._elSyncScroll()
    end
    if self._elResizeAppearanceScroll then
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          if self._elResizeAppearanceScroll then
            self._elResizeAppearanceScroll()
          end
        end)
      else
        self._elResizeAppearanceScroll()
      end
    end
    if self.Raise then
      self:Raise()
    end
  end)
  configFrame:SetScript("OnHide", function()
    finishConfigResize()
  end)

  --- Paint on a child at zBg so the shell backdrop never sorts above buttons/text (parent backdrop can on some clients).
  local configBg = CreateFrame("Frame", nil, configFrame)
  configBg:SetAllPoints()
  configBg:SetFrameLevel(zBg)
  configBg:EnableMouse(false)
  if configBg.SetMouseMotionEnabled then
    configBg:SetMouseMotionEnabled(false)
  end
  if configBg.SetMouseClickEnabled then
    configBg:SetMouseClickEnabled(false)
  end
  if not applyMaterialSurface(configBg, { bgA = 0.96, borderA = 0.18 }) then
    local bgTex = configBg:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTex:SetAllPoints()
    pcall(function()
      bgTex:SetColorTexture(0.14, 0.145, 0.155, 0.98)
    end)
  end
  if configFrame.SetClipsChildren then
    pcall(function()
      configFrame:SetClipsChildren(false)
    end)
  end

  local headerChromeH = 112
  local headerChrome = CreateFrame("Frame", nil, configFrame)
  headerChrome:SetPoint("TOPLEFT", configFrame, "TOPLEFT", pad, -pad)
  headerChrome:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -pad - sbW - sbGap, -pad)
  headerChrome:SetHeight(headerChromeH)
  headerChrome:SetFrameLevel(zChrome)
  headerChrome:EnableMouse(true)

  local dragHeader = CreateFrame("Frame", nil, headerChrome)
  dragHeader:SetPoint("TOPLEFT", headerChrome, "TOPLEFT", 0, 0)
  dragHeader:SetPoint("TOPRIGHT", headerChrome, "TOPRIGHT", 0, 0)
  dragHeader:SetHeight(48)
  dragHeader:EnableMouse(true)
  dragHeader:RegisterForDrag("LeftButton")
  dragHeader:SetScript("OnDragStart", function()
    configFrame:StartMoving()
  end)
  dragHeader:SetScript("OnDragStop", function()
    configFrame:StopMovingOrSizing()
  end)

  local title = dragHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", dragHeader, "TOP", 0, -8)
  title:SetText(L.CONFIG_TITLE)
  title:SetTextColor(0.96, 0.97, 0.99)

  local dragHint = dragHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dragHint:SetPoint("TOP", title, "BOTTOM", 0, -2)
  dragHint:SetTextColor(0.55, 0.58, 0.62)
  dragHint:SetText(L.CONFIG_DRAG)

  --- Intro text removed (was outdated).

  local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame)
  scrollFrame:SetPoint("TOPLEFT", headerChrome, "BOTTOMLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -pad - sbW - sbGap, footerReserve)
  scrollFrame:SetFrameLevel(zScroll)
  scrollFrame:EnableMouse(true)
  if scrollFrame.SetPropagateMouseInput then
    pcall(function()
      scrollFrame:SetPropagateMouseInput("Motion", true)
      scrollFrame:SetPropagateMouseInput("Click", true)
    end)
  end
  if scrollFrame.SetClipsChildren then
    pcall(function()
      scrollFrame:SetClipsChildren(true)
    end)
  end

  local scrollBar
  pcall(function()
    --- Parent must be a ScrollFrame: UIPanelScrollBarTemplate / SecureScrollTemplates wire
    --- internal scripts (up/down buttons, mouse wheel) that call |self:GetParent():SetVerticalScroll(...)|.
    --- |syncScrollBounds| re-parents this bar to |_elActiveScrollFrame| so it stays visible when
    --- non-Appearance tabs hide the first |ScrollFrame|; do not set parent to |configFrame| only.
    scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", sbGap, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", sbW + sbGap, 2)
    scrollBar:SetFrameLevel(zScrollBar)
    scrollBar:EnableMouse(true)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
  end)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(innerW)
  scrollChild:SetHeight(contentH)
  scrollChild:EnableMouse(true)
  scrollFrame:SetScrollChild(scrollChild)

  --- The external scrollbar always drives the currently-visible tab's scroll frame. |_elActiveScrollFrame|/|_elActiveScrollChild|
  --- are updated by |selectTab| below and default to the Appearance tab's frames until then.
  configFrame._elActiveScrollFrame = scrollFrame
  configFrame._elActiveScrollChild = scrollChild
  local scrollBarUpdating = false
  local function syncScrollBounds()
    local sf = configFrame._elActiveScrollFrame or scrollFrame
    local sc = configFrame._elActiveScrollChild or scrollChild
    if not sf or not sc then
      return
    end
    --- The bar was created on the first tab's |ScrollFrame|; other tabs |Hide()| that frame, which hid the
    --- bar for every page. Re-parent the template slider to the **active** |ScrollFrame| (still a valid
    --- |SetVerticalScroll| target for |UIPanelScrollBarTemplate|).
    if scrollBar and sf and scrollBar.SetParent and (not scrollBar.GetParent or scrollBar:GetParent() ~= sf) then
      local gap = configFrame._elResizeSbGap or 4
      local sbb = configFrame._elResizeSbW or 20
      scrollBar:SetParent(sf)
      scrollBar:ClearAllPoints()
      scrollBar:SetPoint("TOPLEFT", sf, "TOPRIGHT", gap, -16)
      scrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", sbb + gap, 2)
      scrollBar:SetFrameLevel((sf:GetFrameLevel() or 0) + 20)
    end
    local viewH = sf:GetHeight()
    if not viewH or viewH < 1 then
      viewH = 1
    end
    local range = math.max(0, (sc:GetHeight() or 0) - viewH)
    local z = math.min(sf:GetVerticalScroll() or 0, range)
    sf:SetVerticalScroll(z)
    if scrollBar then
      scrollBarUpdating = true
      scrollBar:SetMinMaxValues(0, range)
      if range < 0.5 then
        scrollBar:Hide()
      else
        scrollBar:Show()
        scrollBar:SetValue(z)
      end
      scrollBarUpdating = false
    end
  end
  configFrame._elSyncActiveScrollBounds = syncScrollBounds

  if scrollBar then
    scrollBar:SetScript("OnValueChanged", function(_, v)
      if scrollBarUpdating then return end
      local sf = configFrame._elActiveScrollFrame or scrollFrame
      if sf then sf:SetVerticalScroll(v) end
    end)
  end

  --- Shared mousewheel handler so each tab's scroll frame updates its view AND the external scrollbar.
  local function onTabMouseWheel(self, delta)
    local sc = self:GetScrollChild()
    local viewH = self:GetHeight() or 1
    local ch = sc and sc:GetHeight() or 0
    local mx = math.max(0, ch - viewH)
    local step = 28
    local dir = delta > 0 and 1 or -1
    local z = math.max(0, math.min(mx, (self:GetVerticalScroll() or 0) - dir * step))
    self:SetVerticalScroll(z)
    if scrollBar and scrollBar:IsShown() and configFrame._elActiveScrollFrame == self then
      scrollBarUpdating = true
      scrollBar:SetValue(z)
      scrollBarUpdating = false
    end
  end
  local function onTabVerticalScroll(self, offset)
    if scrollBar and configFrame._elActiveScrollFrame == self then
      scrollBarUpdating = true
      scrollBar:SetValue(offset)
      scrollBarUpdating = false
    end
  end
  configFrame._elOnTabMouseWheel = onTabMouseWheel
  configFrame._elOnTabVerticalScroll = onTabVerticalScroll

  scrollFrame:EnableMouseWheel(true)
  scrollFrame:SetScript("OnMouseWheel", onTabMouseWheel)
  scrollFrame:SetScript("OnVerticalScroll", onTabVerticalScroll)

  configFrame._elConfigScroll = scrollFrame
  configFrame._elScrollChild = scrollChild
  configFrame._elConfigScrollBar = scrollBar
  configFrame._elSyncScroll = syncScrollBounds

  local scrollTopMark = CreateFrame("Frame", nil, scrollChild)
  scrollTopMark:SetSize(innerW, 1)
  scrollTopMark:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
  configFrame._elScrollTopMark = scrollTopMark
  local secDisp, secDispLine = addConfigSectionHeader(scrollChild, scrollTopMark, -6, L.CONFIG_SECTION_DISPLAY, nil, innerW - lineTrim)
  configFrame._elSectionLines = { secDispLine }
  local Wb = EnemyList.ConfigWidgets

  local compactCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = secDisp,
    offsetY = -12,
    text = L.OPT_COMPACT_ROW,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.compactRow = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_COMPACT_ROW,
  })

  local truncateNamesCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = compactCheck,
    text = L.OPT_TRUNCATE_NAMES,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.truncateLongNames = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_TRUNCATE_NAMES,
  })
  configFrame._elTruncateNamesCheck = truncateNamesCheck

  local maxNameLenRow = CreateFrame("Frame", nil, scrollChild)
  maxNameLenRow:SetSize(innerW, 42)
  maxNameLenRow:SetPoint("TOPLEFT", truncateNamesCheck, "BOTTOMLEFT", 0, -4)
  local maxNameLenSlider = createConfigOptionSlider(maxNameLenRow, {
    rowInnerWidth = innerW,
    label = L.OPT_MAX_NAME_LENGTH,
    tooltip = L.TOOLTIP_OPT_MAX_NAME_LENGTH,
    min = 4,
    max = 40,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.max(4, math.min(40, math.floor(v + 0.5)))
      EnemyListDB.maxNameLength = v
      layoutRows()
    end,
  })
  configFrame._elMaxNameLenSlider = maxNameLenSlider

  local bgCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = maxNameLenRow,
    text = L.OPT_SHOW_BG,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showBackground = self:GetChecked() and true or false
      applyMainBackground()
    end,
    tooltip = L.TOOLTIP_OPT_SHOW_BG,
  })

  local singleColCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = bgCheck,
    text = L.OPT_SINGLE_COL,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.singleColumn = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_SINGLE_COL,
  })

  local gridCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = singleColCheck,
    text = L.OPT_GRID_MODE,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.gridMode = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_GRID_MODE,
  })

  local gridSizeRow = CreateFrame("Frame", nil, scrollChild)
  gridSizeRow:SetSize(innerW, 42)
  gridSizeRow:SetPoint("TOPLEFT", gridCheck, "BOTTOMLEFT", 0, -4)
  local gridSizeSlider = createConfigOptionSlider(gridSizeRow, {
    rowInnerWidth = innerW,
    label = L.OPT_GRID_CELL_SIZE,
    tooltip = L.TOOLTIP_OPT_GRID_CELL_SIZE,
    min = 30,
    max = 100,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5)) .. "px"
    end,
    onChange = function(v)
      v = math.max(30, math.min(100, math.floor(v + 0.5)))
      EnemyListDB.gridCellSize = v
      layoutRows()
    end,
  })
  configFrame._elGridSizeSlider = gridSizeSlider

  local gridColRow = CreateFrame("Frame", nil, scrollChild)
  gridColRow:SetSize(innerW, 42)
  gridColRow:SetPoint("TOPLEFT", gridSizeRow, "BOTTOMLEFT", 0, -4)
  local gridColSlider = createConfigOptionSlider(gridColRow, {
    rowInnerWidth = innerW,
    label = L.OPT_GRID_COLUMNS,
    tooltip = L.TOOLTIP_OPT_GRID_COLUMNS,
    min = 1,
    max = 5,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.max(1, math.min(5, math.floor(v + 0.5)))
      EnemyListDB.gridColumns = v
      layoutRows()
    end,
  })
  configFrame._elGridColSlider = gridColSlider

  --- Sort mode selector: row of toggle buttons (single-column and grid mode).
  local sortLabels = { L.SORT_AGGRO_HI, L.SORT_AGGRO_LO, L.SORT_HP_HI, L.SORT_HP_LO }
  local sortRow = CreateFrame("Frame", nil, scrollChild)
  sortRow:SetSize(innerW, 38)
  sortRow:SetPoint("TOPLEFT", gridColRow, "BOTTOMLEFT", 0, -8)
  local sortTitle = sortRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sortTitle:SetPoint("TOPLEFT", sortRow, "TOPLEFT", 4, 0)
  sortTitle:SetTextColor(0.74, 0.77, 0.82)
  sortTitle:SetText(L.SETUP_SORT_HEADER .. ":")
  local sortBtns = {}
  local btnW = math.floor((innerW - 12) / 4)
  local function updateSortSelection()
    local mode = tonumber(EnemyListDB.sortMode) or 1
    for j, btn in ipairs(sortBtns) do
      if j == mode then
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:GetFontString():SetTextColor(1, 0.82, 0)
        if btn.SetBackdropBorderColor then
          btn:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        end
      else
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:GetFontString():SetTextColor(0.7, 0.72, 0.75)
        if btn.SetBackdropBorderColor then
          btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end
      end
    end
  end
  local bdMixin = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
  for j, label in ipairs(sortLabels) do
    local btn = CreateFrame("Button", nil, sortRow, bdMixin)
    btn:SetSize(btnW, 20)
    btn:SetPoint("TOPLEFT", sortRow, "TOPLEFT", 4 + (j - 1) * (btnW + 2), -14)
    if btn.SetBackdrop then
      btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      btn:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
      btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    end
    btn:SetNormalFontObject("GameFontNormalSmall")
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject("GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    btn:SetFontString(fs)
    btn:SetScript("OnClick", function()
      EnemyListDB.sortMode = j
      updateSortSelection()
      layoutRows()
    end)
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(string.format(L.OPT_SORT_BY, label), nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    sortBtns[j] = btn
  end
  updateSortSelection()
  configFrame._elSortBtns = sortBtns
  configFrame._elSortRow = sortRow

  local fontRow = CreateFrame("Frame", nil, scrollChild)
  fontRow:SetSize(innerW, 42)
  fontRow:SetPoint("TOPLEFT", sortRow, "BOTTOMLEFT", 0, -6)
  local fontSlider = createConfigOptionSlider(fontRow, {
    rowInnerWidth = innerW,
    label = L.OPT_FONT,
    tooltip = L.TOOLTIP_OPT_FONT,
    min = 2,
    max = FONT_PRESET_MAX,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.min(FONT_PRESET_MAX, math.max(1, math.floor(v + 0.5)))
      EnemyListDB.fontPreset = v
      layoutRows()
    end,
  })

  local maxAggroRow = CreateFrame("Frame", nil, scrollChild)
  maxAggroRow:SetSize(innerW, 42)
  maxAggroRow:SetPoint("TOPLEFT", fontRow, "BOTTOMLEFT", 0, -6)
  local maxAggroSlider = createConfigOptionSlider(maxAggroRow, {
    rowInnerWidth = innerW,
    label = L.OPT_MAX_AGGRO_COL,
    tooltip = L.TOOLTIP_OPT_MAX_AGGRO_COL,
    min = 1,
    max = MAX_ENEMIES_CAP,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.min(MAX_ENEMIES_CAP, math.max(1, math.floor(v + 0.5)))
      EnemyListDB.maxEnemiesAggro = v
      layoutRows()
    end,
  })

  local maxOtherRow = CreateFrame("Frame", nil, scrollChild)
  maxOtherRow:SetSize(innerW, 42)
  maxOtherRow:SetPoint("TOPLEFT", maxAggroRow, "BOTTOMLEFT", 0, -6)
  local maxOtherSlider = createConfigOptionSlider(maxOtherRow, {
    rowInnerWidth = innerW,
    label = L.OPT_MAX_OTHER_COL,
    tooltip = L.TOOLTIP_OPT_MAX_OTHER_COL,
    min = 1,
    max = MAX_ENEMIES_CAP,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.min(MAX_ENEMIES_CAP, math.max(1, math.floor(v + 0.5)))
      EnemyListDB.maxEnemiesOther = v
      layoutRows()
    end,
  })

  local inactivityRow = CreateFrame("Frame", nil, scrollChild)
  inactivityRow:SetSize(innerW, 42)
  inactivityRow:SetPoint("TOPLEFT", maxOtherRow, "BOTTOMLEFT", 0, -6)
  local inactivitySlider = createConfigOptionSlider(inactivityRow, {
    rowInnerWidth = innerW,
    label = L.OPT_ENEMY_INACTIVITY_FILTER,
    tooltip = L.TOOLTIP_OPT_ENEMY_INACTIVITY_FILTER,
    min = ENEMY_INACTIVITY_FILTER_SEC_MIN,
    max = ENEMY_INACTIVITY_FILTER_SEC_MAX,
    step = 1,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return string.format(L.OPT_SECONDS_VALUE, math.floor(v + 0.5))
    end,
    onChange = function(v)
      v = math.min(ENEMY_INACTIVITY_FILTER_SEC_MAX, math.max(ENEMY_INACTIVITY_FILTER_SEC_MIN, math.floor(v + 0.5)))
      EnemyListDB.enemyInactivityFilterSec = v
      layoutRows()
    end,
  })

  local scaleRow = CreateFrame("Frame", nil, scrollChild)
  scaleRow:SetSize(innerW, 42)
  scaleRow:SetPoint("TOPLEFT", inactivityRow, "BOTTOMLEFT", 0, -6)
  local scaleSlider = createConfigOptionSlider(scaleRow, {
    rowInnerWidth = innerW,
    label = L.OPT_UI_SCALE,
    tooltip = L.TOOLTIP_OPT_UI_SCALE,
    min = UI_SCALE_MIN,
    max = UI_SCALE_MAX,
    step = 0.05,
    integer = false,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return string.format("%.2f", v)
    end,
    onChange = function(v)
      v = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, v))
      EnemyListDB.uiScale = v
      layoutRows()
    end,
  })

  local opacityRow = CreateFrame("Frame", nil, scrollChild)
  opacityRow:SetSize(innerW, 42)
  opacityRow:SetPoint("TOPLEFT", scaleRow, "BOTTOMLEFT", 0, -6)
  local opacitySlider = createConfigOptionSlider(opacityRow, {
    rowInnerWidth = innerW,
    label = L.OPT_BAR_OPACITY,
    tooltip = L.TOOLTIP_OPT_BAR_OPACITY,
    min = 0.1,
    max = 1.0,
    step = 0.05,
    integer = false,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return string.format("%.0f%%", v * 100)
    end,
    onChange = function(v)
      v = math.max(0.1, math.min(1.0, v))
      EnemyListDB.barOpacity = v
      layoutRows()
    end,
  })

  local widthRow = CreateFrame("Frame", nil, scrollChild)
  widthRow:SetSize(innerW, 42)
  widthRow:SetPoint("TOPLEFT", opacityRow, "BOTTOMLEFT", 0, -6)
  local widthSlider = createConfigOptionSlider(widthRow, {
    rowInnerWidth = innerW,
    label = L.OPT_LIST_WIDTH,
    tooltip = L.TOOLTIP_OPT_LIST_WIDTH,
    min = 80,
    max = 500,
    step = 10,
    integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v)
      return tostring(math.floor(v + 0.5)) .. "px"
    end,
    onChange = function(v)
      v = math.max(80, math.min(500, math.floor(v + 0.5)))
      EnemyListDB.width = v
      layoutRows()
    end,
  })

  --- Health bar height.
  local hpBarHRow = CreateFrame("Frame", nil, scrollChild)
  hpBarHRow:SetSize(innerW, 42)
  hpBarHRow:SetPoint("TOPLEFT", widthRow, "BOTTOMLEFT", 0, -6)
  local hpBarHSlider = createConfigOptionSlider(hpBarHRow, {
    rowInnerWidth = innerW,
    label = L.OPT_ENEMY_LIST_HEALTH_BAR_HEIGHT,
    tooltip = L.TOOLTIP_OPT_ENEMY_LIST_HEALTH_BAR_HEIGHT,
    min = 6, max = 40, step = 1, integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
    onChange = function(v)
      EnemyListDB.healthBarHeight = math.max(6, math.min(40, math.floor(v + 0.5)))
      layoutRows()
    end,
  })

  --- Threat bar toggle + height.
  local threatBarCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = hpBarHRow,
    offsetY = -6,
    text = L.OPT_DISPLAY_SHOW_THREAT_BAR,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showThreatBar = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_DISPLAY_SHOW_THREAT_BAR,
  })
  local threatBarHRow = CreateFrame("Frame", nil, scrollChild)
  threatBarHRow:SetSize(innerW, 42)
  threatBarHRow:SetPoint("TOPLEFT", threatBarCheck, "BOTTOMLEFT", 0, -2)
  local threatBarHSlider = createConfigOptionSlider(threatBarHRow, {
    rowInnerWidth = innerW,
    label = L.OPT_ENEMY_THREAT_BAR_HEIGHT,
    tooltip = L.TOOLTIP_OPT_ENEMY_THREAT_BAR_HEIGHT,
    min = 3, max = 20, step = 1, integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
    onChange = function(v)
      EnemyListDB.threatBarHeight = math.max(3, math.min(20, math.floor(v + 0.5)))
      layoutRows()
    end,
  })

  local secondOnThreatBarCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = threatBarHRow,
    offsetY = -6,
    text = L.OPT_SHOW_SECOND_ON_THREAT_BAR,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showSecondOnThreatBar = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_SHOW_SECOND_ON_THREAT_BAR,
  })

  --- Runner-up aggro bars — top N non-tanking threats on each enemy row.
  local runnerUpCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = secondOnThreatBarCheck,
    offsetY = -6,
    text = L.OPT_RUNNER_UP_BARS,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showRunnerUpBars = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_RUNNER_UP_BARS,
  })
  local runnerUpCountRow = CreateFrame("Frame", nil, scrollChild)
  runnerUpCountRow:SetSize(innerW, 42)
  runnerUpCountRow:SetPoint("TOPLEFT", runnerUpCheck, "BOTTOMLEFT", 0, -2)
  local runnerUpCountSlider = createConfigOptionSlider(runnerUpCountRow, {
    rowInnerWidth = innerW,
    label = L.OPT_RUNNER_UP_COUNT,
    tooltip = L.TOOLTIP_OPT_RUNNER_UP_COUNT,
    min = 1, max = 5, step = 1, integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v) return tostring(math.floor(v + 0.5)) end,
    onChange = function(v)
      EnemyListDB.runnerUpBarCount = math.max(1, math.min(5, math.floor(v + 0.5)))
      layoutRows()
    end,
  })
  local runnerUpHeightRow = CreateFrame("Frame", nil, scrollChild)
  runnerUpHeightRow:SetSize(innerW, 42)
  runnerUpHeightRow:SetPoint("TOPLEFT", runnerUpCountRow, "BOTTOMLEFT", 0, -2)
  local runnerUpHeightSlider = createConfigOptionSlider(runnerUpHeightRow, {
    rowInnerWidth = innerW,
    label = L.OPT_RUNNER_UP_HEIGHT,
    tooltip = L.TOOLTIP_OPT_RUNNER_UP_HEIGHT,
    min = 2, max = 16, step = 1, integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
    onChange = function(v)
      EnemyListDB.runnerUpBarHeight = math.max(2, math.min(16, math.floor(v + 0.5)))
      layoutRows()
    end,
  })

  local secondThreatAggroCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = runnerUpHeightRow,
    offsetY = -6,
    text = L.OPT_LIST_SECOND_IN_AGGRO,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.listShowSecondInAggroSection = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_LIST_SECOND_IN_AGGRO,
  })

  --- Cast bar toggle + height.
  local castBarCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = secondThreatAggroCheck,
    offsetY = -6,
    text = L.OPT_DISPLAY_SHOW_CAST_BAR,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showCastBar = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_DISPLAY_SHOW_CAST_BAR,
  })
  local castBarHRow = CreateFrame("Frame", nil, scrollChild)
  castBarHRow:SetSize(innerW, 42)
  castBarHRow:SetPoint("TOPLEFT", castBarCheck, "BOTTOMLEFT", 0, -2)
  local castBarHSlider = createConfigOptionSlider(castBarHRow, {
    rowInnerWidth = innerW,
    label = L.OPT_ENEMY_LIST_DISPLAY_CAST_BAR_HEIGHT,
    tooltip = L.TOOLTIP_OPT_ENEMY_LIST_DISPLAY_CAST_BAR_HEIGHT,
    min = 3, max = 20, step = 1, integer = true,
    dbWriteGate = configSliderDbGate,
    format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
    onChange = function(v)
      EnemyListDB.castBarHeight = math.max(3, math.min(20, math.floor(v + 0.5)))
      layoutRows()
    end,
  })

  configFrame._elDisplaySliders = { fontSlider, maxAggroSlider, maxOtherSlider, inactivitySlider, scaleSlider, opacitySlider, widthSlider, hpBarHSlider, threatBarHSlider, castBarHSlider, gridSizeSlider, gridColSlider, runnerUpCountSlider, runnerUpHeightSlider }

  configFrame._elWideRows = { sortRow, fontRow, maxAggroRow, maxOtherRow, inactivityRow, scaleRow, opacityRow, widthRow, hpBarHRow, threatBarHRow, castBarHRow, gridSizeRow, gridColRow, runnerUpCountRow, runnerUpHeightRow }
  configFrame._elHpBarHSlider = hpBarHSlider
  configFrame._elThreatBarCheck = threatBarCheck
  configFrame._elThreatBarHSlider = threatBarHSlider
  configFrame._elSecondOnThreatBarCheck = secondOnThreatBarCheck
  configFrame._elCastBarCheck = castBarCheck
  configFrame._elCastBarHSlider = castBarHSlider
  configFrame._elRunnerUpCheck = runnerUpCheck
  configFrame._elRunnerUpCountSlider = runnerUpCountSlider
  configFrame._elRunnerUpHeightSlider = runnerUpHeightSlider
  configFrame._elSecondThreatAggroCheck = secondThreatAggroCheck

  local raidMarkerCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = castBarHRow,
    offsetY = -6,
    text = L.OPT_DISPLAY_SHOW_RAID_MARKERS,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showRaidMarkers = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_DISPLAY_SHOW_RAID_MARKERS,
  })
  configFrame._elRaidMarkerCheck = raidMarkerCheck

  local selfToTCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = raidMarkerCheck,
    text = L.OPT_DISPLAY_SHOW_SELF_TOT,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showSelfToT = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_DISPLAY_SHOW_SELF_TOT,
  })
  configFrame._elSelfToTCheck = selfToTCheck

  local partyCombatCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = selfToTCheck,
    text = L.OPT_SHOW_PARTY_COMBAT_ENEMIES,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.showPartyCombatEnemies = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_SHOW_PARTY_COMBAT_ENEMIES,
  })
  configFrame._elPartyCombatCheck = partyCombatCheck

  configFrame._elCompactCheck = compactCheck
  configFrame._elBgCheck = bgCheck
  configFrame._elSingleColCheck = singleColCheck
  configFrame._elGridCheck = gridCheck
  --- |npRangeCheck|/|npThreatCheck|/|npMirrorCheck| are built on the Nameplates tab (see tab |do| block).

  local lockCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = partyCombatCheck,
    offsetY = -10,
    text = L.OPT_LOCK,
    textColor = { 0.85, 0.87, 0.90 },
    tooltip = L.TOOLTIP_OPT_LOCK,
  })

  local testCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = lockCheck,
    offsetY = -6,
    text = L.OPT_TEST_MODE,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.testMode = self:GetChecked() and true or false
      if EnemyList.OnDataChanged then
        EnemyList.OnDataChanged()
      end
      updatePartyFrameSize()
    end,
  })

  --- Footer: plain frame (no BackdropTemplate) so buttons are never clipped.
  local footer = CreateFrame("Frame", nil, configFrame)
  footer:SetHeight(52)
  footer:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", pad, pad)
  footer:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -pad, pad)
  footer:SetFrameLevel(zFooter)
  footer:EnableMouse(true)
  if footer.SetClipsChildren then
    pcall(function()
      footer:SetClipsChildren(false)
    end)
  end
  if footer.SetBackdrop then
    pcall(function()
      footer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
      })
      footer:SetBackdropColor(0.07, 0.075, 0.08, 0.98)
      footer:SetBackdropBorderColor(1, 1, 1, 0.18)
    end)
  end

  local testHint = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  testHint:SetPoint("TOPLEFT", testCheck, "BOTTOMLEFT", 24, -4)
  testHint:SetWidth(innerW - 28)
  testHint:SetJustifyH("LEFT")
  testHint:SetJustifyV("TOP")
  testHint:SetWordWrap(true)
  testHint:SetTextColor(0.58, 0.61, 0.65)
  testHint:SetText(L.OPT_TEST_MODE_HINT)
  configFrame._elTestHint = testHint

  local coalesceRefreshCheck = Wb.CreateBooleanOption(scrollChild, {
    point = "TOPLEFT",
    ref = testHint,
    relPoint = "BOTTOMLEFT",
    x = -24,
    y = -8,
    text = L.OPT_COALESCE_UI_REFRESH,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.coalesceUIRefresh = self:GetChecked() and true or false
      if main then
        layoutRows()
      end
    end,
    tooltip = L.TOOLTIP_OPT_COALESCE_UI_REFRESH,
  })
  configFrame._elCoalesceRefreshCheck = coalesceRefreshCheck

  --- Feature 6: fade out of combat checkbox
  local fadeCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = coalesceRefreshCheck,
    offsetY = -6,
    text = L.OPT_FADE_OOC,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.fadeOutOfCombat = self:GetChecked() and true or false
      if type(EnemyList.UpdateFadeOutCombatTicker) == "function" then
        EnemyList.UpdateFadeOutCombatTicker()
      end
    end,
    tooltip = L.TOOLTIP_OPT_FADE_OOC,
  })
  configFrame._elFadeCheck = fadeCheck

  --- Feature 10: healer mode checkbox
  local healerCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = fadeCheck,
    text = L.OPT_HEALER_MODE,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.healerMode = self:GetChecked() and true or false
      layoutRows()
    end,
    tooltip = L.TOOLTIP_OPT_HEALER_MODE,
  })
  configFrame._elHealerCheck = healerCheck

  local minimapShowCheck = Wb.CreateBooleanOption(scrollChild, {
    placeAfter = healerCheck,
    text = L.OPT_MINIMAP_SHOW_BUTTON,
    textColor = { 0.85, 0.87, 0.90 },
    onClick = function(self)
      EnemyListDB.minimapButtonHidden = not self:GetChecked()
      elSafe("createMinimapButton", createMinimapButton)
      enemyListApplyMinimapButtonVisibility()
    end,
    tooltip = L.TOOLTIP_OPT_MINIMAP_SHOW_BUTTON,
  })
  configFrame._elMinimapShowCheck = minimapShowCheck

  --- Fit Appearance scroll child to content (no extra blank area); re-run on show / sync (wrapped hint height).
  --- A single "last" widget (GetTop / GetTop-GetBottom) can equal the *viewport* on some clients, giving
  --- |range| ≈ 0 and hiding the scrollbar. Measure the full vertical span of all direct children in
  --- |sc|'s coordinate system (Y up, origin at parent bottom): max(GetTop) - min(GetBottom) + margin.
  configFrame._elResizeAppearanceScroll = function()
    local sc = configFrame._elScrollChild
    if not sc or not sc.SetHeight or not sc.GetNumChildren or not sc.GetChildren then
      return
    end
    local n = sc:GetNumChildren() or 0
    if n < 1 then
      return
    end
    local maxT, minB
    for i = 1, n do
      local ch = select(i, sc:GetChildren())
      if ch and ch.GetTop and ch.GetBottom and (not ch.IsShown or ch:IsShown()) then
        local t, b = ch:GetTop(), ch:GetBottom()
        if t and (not maxT or t > maxT) then
          maxT = t
        end
        if b and (not minB or b < minB) then
          minB = b
        end
      end
    end
    local span = 0
    if minB and maxT and maxT > minB then
      span = maxT - minB
    end
    if span < 1 then
      --- Fallback: single-widget hint if layout not ready yet
      local last = configFrame._elMinimapShowCheck
      if last and last.GetTop and (not last.GetParent or last:GetParent() == sc) then
        local lt = last:GetTop()
        if lt and lt > 0 then
          span = lt + 48
        end
      end
    end
    if span < 1 or span > 12000 then
      return
    end
    local need = span + 48
    sc:SetHeight(need)
    if configFrame._elSyncScroll then
      configFrame._elSyncScroll()
    end
  end

  --- Feature: party frames checkbox and size slider.
  --- Tab system: 7 tabs — Appearance, Party, Raid, Colors, Profiles, Nameplates, Keybinds.
  local tabAppearance, tabParty, tabRaid, tabColors, tabProfiles, tabNameplates, tabKeybinds
  local scrollFrame2, scrollChild2, scrollFrame3, scrollChild3, scrollFrame4, scrollChild4,
        scrollFrame5, scrollChild5, scrollFrame6, scrollChild6, scrollFrame7, scrollChild7
  do
    local tabH = 22
    local tabTotalW = innerW + sbW + sbGap
    local tabW = math.floor(tabTotalW / 7) - 2
    local bdMixinTab = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil

    --- Tab bar container.
    local tabBar = CreateFrame("Frame", nil, configFrame)
    tabBar:SetSize(tabTotalW, tabH)
    tabBar:SetPoint("TOPLEFT", headerChrome, "BOTTOMLEFT", pad, -2)
    tabBar:SetFrameLevel(zChrome + 2)

    --- Create styled tab.
    local function makeTab(label, x)
      local tab = CreateFrame("Button", nil, tabBar, bdMixinTab)
      tab:SetSize(tabW, tabH)
      tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
      tab:SetFrameLevel(zChrome + 3)
      if tab.SetBackdrop then
        tab:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          edgeSize = 1,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
      end
      local fs = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetPoint("CENTER")
      fs:SetText(label)
      tab:SetFontString(fs)
      return tab
    end

    tabAppearance = makeTab(L.OPT_TAB_APPEARANCE or "Appearance", 0)
    tabParty      = makeTab(L.OPT_TAB_PARTY or "Party", (tabW + 2) * 1)
    tabRaid       = makeTab(L.OPT_TAB_RAID or "Raid", (tabW + 2) * 2)
    tabColors     = makeTab(L.OPT_TAB_COLORS or "Colors", (tabW + 2) * 3)
    tabProfiles   = makeTab(L.OPT_TAB_PROFILES or "Profiles", (tabW + 2) * 4)
    tabNameplates = makeTab(L.OPT_TAB_NAMEPLATES, (tabW + 2) * 5)
    tabKeybinds   = makeTab(L.OPT_TAB_KEYBINDS, (tabW + 2) * 6)

    local contentTop = tabBar

    local function makeScrollPanel()
      local sf = CreateFrame("ScrollFrame", nil, configFrame)
      sf:SetPoint("TOPLEFT", contentTop, "BOTTOMLEFT", 0, -2)
      sf:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -(pad + sbW + sbGap), footerReserve)
      sf:SetFrameLevel(zScroll)
      sf:EnableMouse(true)
      local sc = CreateFrame("Frame", nil, sf)
      sc:SetWidth(innerW)
      sc:SetHeight(800)
      sf:SetScrollChild(sc)
      sf:EnableMouseWheel(true)
      --- Route wheel + scroll events through the shared handlers so the external scrollbar stays in sync
      --- with whichever tab is currently visible.
      sf:SetScript("OnMouseWheel", configFrame._elOnTabMouseWheel)
      sf:SetScript("OnVerticalScroll", configFrame._elOnTabVerticalScroll)
      sf:Hide()
      return sf, sc
    end

    scrollFrame2, scrollChild2 = makeScrollPanel()  -- Keybinds
    scrollFrame3, scrollChild3 = makeScrollPanel()  -- Party
    scrollFrame4, scrollChild4 = makeScrollPanel()  -- Colors
    scrollFrame5, scrollChild5 = makeScrollPanel()  -- Profiles
    scrollFrame6, scrollChild6 = makeScrollPanel()  -- Raid
    scrollFrame7, scrollChild7 = makeScrollPanel()  -- Nameplates

    do
      local nptTop = CreateFrame("Frame", nil, scrollChild7)
      nptTop:SetSize(innerW, 1)
      nptTop:SetPoint("TOPLEFT", scrollChild7, "TOPLEFT", 0, 0)
      local nptSec = select(1, addConfigSectionHeader(scrollChild7, nptTop, -6, L.CONFIG_SECTION_NAMEPLATES, nil, innerW - 8))
      --- Experimental warning banner. Nameplate features (threat overlay + mirror) interact with
      --- Blizzard/Plater plate frames in fragile ways and can have edge cases on Vanilla. Wrapped
      --- in a Frame so |Wb.CreateBooleanOption(placeAfter = …)| can anchor to it.
      local nptWarnFrame = CreateFrame("Frame", nil, scrollChild7)
      nptWarnFrame:SetPoint("TOPLEFT", nptSec, "BOTTOMLEFT", 0, -8)
      nptWarnFrame:SetPoint("RIGHT", scrollChild7, "RIGHT", -8, 0)
      nptWarnFrame:SetHeight(48)
      local nptWarn = nptWarnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      nptWarn:SetPoint("TOPLEFT", nptWarnFrame, "TOPLEFT", 6, 0)
      nptWarn:SetPoint("RIGHT", nptWarnFrame, "RIGHT", -2, 0)
      nptWarn:SetJustifyH("LEFT")
      nptWarn:SetJustifyV("TOP")
      nptWarn:SetWordWrap(true)
      nptWarn:SetText(L.NAMEPLATE_EXPERIMENTAL_WARNING or "|cffffcc00Note:|r Nameplate features are still experimental. They can interact unexpectedly with other nameplate addons (e.g. Plater) and may show visual glitches. Disable them if you run into issues.")
      nptWarn:SetTextColor(0.95, 0.85, 0.45)
      local npRangeCheck = Wb.CreateBooleanOption(scrollChild7, {
        placeAfter = nptWarnFrame,
        offsetY = -10,
        text = L.OPT_EXTEND_NAMEPLATE_RANGE,
        textColor = { 0.85, 0.87, 0.90 },
        onClick = function(self)
          EnemyListDB.extendNameplateRange = self:GetChecked() and true or false
          if EnemyListDB.extendNameplateRange and type(EnemyList.ApplyNameplateRangePreference) == "function" then
            EnemyList.ApplyNameplateRangePreference()
          end
        end,
        tooltip = L.TOOLTIP_OPT_EXTEND_NAMEPLATE_RANGE,
      })
      local npThreatCheck = Wb.CreateBooleanOption(scrollChild7, {
        placeAfter = npRangeCheck,
        text = L.OPT_NAMEPLATE_THREAT,
        textColor = { 0.85, 0.87, 0.90 },
        onClick = function(self)
          EnemyListDB.nameplateThreatOverlay = self:GetChecked() and true or false
          if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
            EnemyList.RefreshNameplateThreatOverlays(true)
          end
        end,
        tooltip = L.TOOLTIP_OPT_NAMEPLATE_THREAT,
      })
      local npMirrorCheck = Wb.CreateBooleanOption(scrollChild7, {
        placeAfter = npThreatCheck,
        text = L.OPT_NAMEPLATE_LIST_MIRROR,
        textColor = { 0.85, 0.87, 0.90 },
        onClick = function(self)
          EnemyListDB.nameplateListMirror = self:GetChecked() and true or false
          if type(EnemyList.RefreshNameplateListMirrors) == "function" then
            EnemyList.RefreshNameplateListMirrors(true)
          end
        end,
        tooltip = L.TOOLTIP_OPT_NAMEPLATE_LIST_MIRROR,
      })
      local npThreatSecondCheck = Wb.CreateBooleanOption(scrollChild7, {
        placeAfter = npMirrorCheck,
        text = L.OPT_NAMEPLATE_THREAT_SECOND,
        textColor = { 0.85, 0.87, 0.90 },
        onClick = function(self)
          EnemyListDB.nameplateThreatSecondStyle = self:GetChecked() and true or false
          if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
            EnemyList.RefreshNameplateThreatOverlays(true)
          end
        end,
        tooltip = L.TOOLTIP_OPT_NAMEPLATE_THREAT_SECOND,
      })
      configFrame._elNameplateRangeCheck = npRangeCheck
      configFrame._elNameplateThreatCheck = npThreatCheck
      configFrame._elNameplateMirrorCheck = npMirrorCheck
      configFrame._elNameplateThreatSecondCheck = npThreatSecondCheck
      scrollChild7:SetHeight(360)
    end

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentTop, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -(pad + sbW + sbGap), footerReserve)

    local function styleTab(tab, active)
      if active then
        tab:GetFontString():SetTextColor(1, 0.82, 0)
        if tab.SetBackdropColor then
          tab:SetBackdropColor(0.15, 0.15, 0.17, 0.95)
          tab:SetBackdropBorderColor(1, 0.82, 0, 0.6)
        end
      else
        tab:GetFontString():SetTextColor(0.55, 0.58, 0.62)
        if tab.SetBackdropColor then
          tab:SetBackdropColor(0.08, 0.08, 0.09, 0.7)
          tab:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.3)
        end
      end
    end

    local function selectTab(tab)
      scrollFrame:Hide(); scrollFrame2:Hide(); scrollFrame3:Hide(); scrollFrame4:Hide(); scrollFrame5:Hide()
      scrollFrame6:Hide(); scrollFrame7:Hide()
      styleTab(tabAppearance, false); styleTab(tabParty, false); styleTab(tabRaid, false); styleTab(tabColors, false)
      styleTab(tabProfiles, false); styleTab(tabNameplates, false); styleTab(tabKeybinds, false)
      local activeSf, activeSc
      if tab == 1 then
        scrollFrame:Show(); styleTab(tabAppearance, true)
        activeSf, activeSc = scrollFrame, scrollChild
      elseif tab == 2 then
        scrollFrame3:Show(); styleTab(tabParty, true)
        activeSf, activeSc = scrollFrame3, scrollChild3
      elseif tab == 3 then
        scrollFrame6:Show(); styleTab(tabRaid, true)
        if configFrame._elRaidRefresh then configFrame._elRaidRefresh() end
        activeSf, activeSc = scrollFrame6, scrollChild6
      elseif tab == 4 then
        scrollFrame4:Show(); styleTab(tabColors, true)
        activeSf, activeSc = scrollFrame4, scrollChild4
      elseif tab == 5 then
        scrollFrame5:Show(); styleTab(tabProfiles, true)
        if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
        activeSf, activeSc = scrollFrame5, scrollChild5
      elseif tab == 6 then
        scrollFrame7:Show(); styleTab(tabNameplates, true)
        activeSf, activeSc = scrollFrame7, scrollChild7
      else
        scrollFrame2:Show(); styleTab(tabKeybinds, true)
        activeSf, activeSc = scrollFrame2, scrollChild2
      end
      configFrame._elActiveScrollFrame = activeSf
      configFrame._elActiveScrollChild = activeSc
      if configFrame._elSyncActiveScrollBounds then
        configFrame._elSyncActiveScrollBounds()
      end
      if syncConfigInnerLayout and configFrame then
        syncConfigInnerLayout(configFrame)
      end
      --- One frame later: scroll child sizes are final; refresh range so the shared scrollbar shows when content overflows.
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          local cf = configFrame
          if not cf then return end
          --- Re-measure Appearance content height after layout (must run before scroll range).
          if tab == 1 and cf._elResizeAppearanceScroll then
            cf._elResizeAppearanceScroll()
          end
          if cf._elSyncActiveScrollBounds then
            cf._elSyncActiveScrollBounds()
          elseif cf._elSyncScroll then
            cf._elSyncScroll()
          end
        end)
      end
    end
    tabAppearance:SetScript("OnClick", function() selectTab(1) end)
    tabParty:SetScript("OnClick", function() selectTab(2) end)
    tabRaid:SetScript("OnClick", function() selectTab(3) end)
    tabColors:SetScript("OnClick", function() selectTab(4) end)
    tabProfiles:SetScript("OnClick", function() selectTab(5) end)
    tabNameplates:SetScript("OnClick", function() selectTab(6) end)
    tabKeybinds:SetScript("OnClick", function() selectTab(7) end)
    --- Must exist before |selectTab(1)| so |syncConfigInnerLayout| sizes every pane (not only Appearance).
    configFrame._elTabScrollChildren = { scrollChild, scrollChild2, scrollChild3, scrollChild4, scrollChild5, scrollChild6, scrollChild7 }
    selectTab(1)
    configFrame._elSelectTab = selectTab
    configFrame._elTabBar = tabBar
    configFrame._elTabs = { tabAppearance, tabParty, tabRaid, tabColors, tabProfiles, tabNameplates, tabKeybinds }
  end

  --- Shared builder for the Party- and Raid-tab control panels. Each call produces an identical
  --- set of widgets, but persistence is routed through |_EL.profileWrite(profileName, …)| so Party
  --- and Raid each edit their own profile. Live preview only reflects the active profile, since
  --- top-level DB keys always mirror the active profile (by design).
  ---
  --- Returns a table of widget handles that |refreshConfigFieldsFromDB| uses to re-sync the sliders
  --- and checkboxes after a profile switch.
  local function buildPartyFramePanel(parent, profileName, opts)
    local Wdg = EnemyList.ConfigWidgets
    opts = opts or {}
    local titleText = opts.title or "Party Frames"
    local descText  = opts.desc  or "Clickable party member frames with color-coded aggro indicators. Drag to reposition."
    local anchorTop = opts.anchorTop
    --- Optional nudge of |topMark| from the scroll pane's left (party/raid: usually 0).
    local anchorPanelOffsetX = tonumber(opts.anchorPanelOffsetX) or 0

    local topMark = CreateFrame("Frame", nil, parent)
    topMark:SetSize(innerW, 1)
    if anchorTop then
      --- Do not use |anchorTop| BOTTOMLEFT for X: that point inherits the raid header’s text inset (~6px),
      --- so the title would land at 12px while Party uses 6. Pin left to |parent| and only stack vertically.
      topMark:SetPoint("TOP", anchorTop, "BOTTOM", 0, -6)
      topMark:SetPoint("LEFT", parent, "LEFT", anchorPanelOffsetX, 0)
    else
      topMark:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    end

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", topMark, "TOPLEFT", 6, -6)
    title:SetTextColor(0.74, 0.77, 0.82)
    title:SetText(titleText)

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(innerW - 12)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetTextColor(0.62, 0.65, 0.69)
    desc:SetText(descText)
    if configFrame then
      if profileName == "party" then
        configFrame._elPartyPanelDesc = desc
      elseif profileName == "raid" then
        configFrame._elRaidPanelDesc = desc
      end
    end

    local partyCheck = Wdg.CreateBooleanOption(parent, {
      point = "TOPLEFT",
      ref = desc,
      relPoint = "BOTTOMLEFT",
      x = -6,
      y = -8,
      text = L.OPT_PARTY_ENABLE_FRAMES,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "showPartyFrames", self:GetChecked() and true or false)
        togglePartyFramesVisibility()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_ENABLE_FRAMES,
    })

    local partySizeRow = CreateFrame("Frame", nil, parent)
    partySizeRow:SetSize(innerW, 42)
    partySizeRow:SetPoint("TOPLEFT", partyCheck, "BOTTOMLEFT", 0, -4)
    local partySizeSlider = createConfigOptionSlider(partySizeRow, {
      label = "Frame size",
      tooltip = "Size of each party unit frame square (pixels).",
      min = 25, max = 80, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameSize", math.max(25, math.min(80, math.floor(v + 0.5))))
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partyVerticalCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = partySizeRow,
      text = L.OPT_PARTY_VERTICAL_LAYOUT,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyFrameVertical", self:GetChecked() and true or false)
        updatePartyFrameSize()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_VERTICAL_LAYOUT,
    })

    local unitGapRow = CreateFrame("Frame", nil, parent)
    unitGapRow:SetSize(innerW, 42)
    unitGapRow:SetPoint("TOPLEFT", partyVerticalCheck, "BOTTOMLEFT", 0, -4)
    local unitGapSlider = createConfigOptionSlider(unitGapRow, {
      label = "Unit gap",
      tooltip = "Gap between units within a group (0–10 pixels).",
      min = 0, max = 10, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameUnitGap", math.max(0, math.min(10, math.floor(v + 0.5))))
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local groupGapRow = CreateFrame("Frame", nil, parent)
    groupGapRow:SetSize(innerW, 42)
    groupGapRow:SetPoint("TOPLEFT", unitGapRow, "BOTTOMLEFT", 0, -4)
    local groupGapSlider = createConfigOptionSlider(groupGapRow, {
      label = "Group gap",
      tooltip = "Gap between groups of 5 (0–20 pixels).",
      min = 0, max = 20, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameGroupGap", math.max(0, math.min(20, math.floor(v + 0.5))))
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partyHpDeficitCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = groupGapRow,
      text = L.OPT_PARTY_SHOW_HP_DEFICIT,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyFrameShowHpDeficit", self:GetChecked() and true or false)
        updatePartyFrameSize()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_SHOW_HP_DEFICIT,
    })

    local partyHpDeficitFontScaleRow = CreateFrame("Frame", nil, parent)
    partyHpDeficitFontScaleRow:SetSize(innerW, 42)
    partyHpDeficitFontScaleRow:SetPoint("TOPLEFT", partyHpDeficitCheck, "BOTTOMLEFT", 0, -8)
    local partyHpDeficitFontScaleSlider = createConfigOptionSlider(partyHpDeficitFontScaleRow, {
      label = L.OPT_PARTY_HP_DEFICIT_FONT_SCALE,
      tooltip = L.TOOLTIP_OPT_PARTY_HP_DEFICIT_FONT_SCALE,
      min = 0.5, max = 2.0, step = 0.05, integer = false,
      rowInnerWidth = innerW,
      format = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameHpDeficitFontScale", math.max(0.5, math.min(2.0, v)))
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partyDebuffCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = partyHpDeficitFontScaleRow,
      text = L.OPT_PARTY_SHOW_DEBUFFS,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyFrameShowDebuffs", self:GetChecked() and true or false)
        updatePartyFrameSize()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_SHOW_DEBUFFS,
    })

    local partyHpBarRow = CreateFrame("Frame", nil, parent)
    partyHpBarRow:SetSize(innerW, 42)
    partyHpBarRow:SetPoint("TOPLEFT", partyDebuffCheck, "BOTTOMLEFT", 0, -4)
    local partyHpBarHeightSlider = createConfigOptionSlider(partyHpBarRow, {
      label = L.OPT_PARTY_HEALTH_BAR_HEIGHT,
      tooltip = L.TOOLTIP_OPT_PARTY_HEALTH_BAR_HEIGHT,
      min = 4, max = 60, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameHealthBarHeight", math.max(4, math.min(60, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partyAggroFontScaleRow = CreateFrame("Frame", nil, parent)
    partyAggroFontScaleRow:SetSize(innerW, 42)
    partyAggroFontScaleRow:SetPoint("TOPLEFT", partyHpBarRow, "BOTTOMLEFT", 0, -8)
    local partyAggroCountFontScaleSlider = createConfigOptionSlider(partyAggroFontScaleRow, {
      label = L.OPT_PARTY_AGGRO_COUNT_FONT_SCALE,
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_COUNT_FONT_SCALE,
      min = 0.5, max = 2.0, step = 0.05, integer = false,
      rowInnerWidth = innerW,
      format = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameAggroCountFontScale", math.max(0.5, math.min(2.0, v)))
        updatePartyFrameSize()
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Aggro count pixel offsets (±50). Same UX as the name-offset sliders.
    local aggroCountOffsetXRow = CreateFrame("Frame", nil, parent)
    aggroCountOffsetXRow:SetSize(innerW, 42)
    aggroCountOffsetXRow:SetPoint("TOPLEFT", partyAggroFontScaleRow, "BOTTOMLEFT", 0, -4)
    local aggroCountOffsetXSlider = createConfigOptionSlider(aggroCountOffsetXRow, {
      label = L.OPT_PARTY_AGGRO_OFFSET_X or "Aggro count X offset",
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_OFFSET_X or "Horizontal pixel offset of the aggro-count digit. Positive = right, negative = left (±50 px).",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) local n = math.floor(v + 0.5); return (n > 0 and "+" or "") .. n .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyAggroCountOffsetX", math.max(-50, math.min(50, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    local aggroCountOffsetYRow = CreateFrame("Frame", nil, parent)
    aggroCountOffsetYRow:SetSize(innerW, 42)
    aggroCountOffsetYRow:SetPoint("TOPLEFT", aggroCountOffsetXRow, "BOTTOMLEFT", 0, -2)
    local aggroCountOffsetYSlider = createConfigOptionSlider(aggroCountOffsetYRow, {
      label = L.OPT_PARTY_AGGRO_OFFSET_Y or "Aggro count Y offset",
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_OFFSET_Y or "Vertical pixel offset of the aggro-count digit. Positive = up, negative = down (±50 px).",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) local n = math.floor(v + 0.5); return (n > 0 and "+" or "") .. n .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyAggroCountOffsetY", math.max(-50, math.min(50, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Aggro border — the colored ring around a unit when enemies are attacking them.
    local aggroBorderCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = aggroCountOffsetYRow,
      text = L.OPT_PARTY_AGGRO_BORDER,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyShowAggroBorder", self:GetChecked() and true or false)
        if applyPartyFrameAggroAttackedChrome then applyPartyFrameAggroAttackedChrome() end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_BORDER,
    })

    local aggroBorderCustomColorCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = aggroBorderCheck,
      text = L.OPT_PARTY_AGGRO_BORDER_CUSTOM,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyUseCustomAggroBorderColor", self:GetChecked() and true or false)
        if applyPartyFrameAggroAttackedChrome then applyPartyFrameAggroAttackedChrome() end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_BORDER_CUSTOM,
    })

    local aggroBorderThicknessRow = CreateFrame("Frame", nil, parent)
    aggroBorderThicknessRow:SetSize(innerW, 42)
    --- Same left edge and |rowInnerWidth| as the aggro Y offset / other Party sliders. A +6 inset here
    --- plus |layoutConfigOptionSliderColumns| setting the row to full |baseW| shifted label + track + value.
    aggroBorderThicknessRow:SetPoint("TOPLEFT", aggroBorderCustomColorCheck, "BOTTOMLEFT", 0, -2)
    local aggroBorderThicknessSlider = createConfigOptionSlider(aggroBorderThicknessRow, {
      label = L.OPT_PARTY_AGGRO_BORDER_THICKNESS or "Aggro border thickness",
      tooltip = L.TOOLTIP_OPT_PARTY_AGGRO_BORDER_THICKNESS or "Thickness of the aggro border in pixels (1–6).",
      min = 1, max = 6, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyAggroBorderThickness", math.max(1, math.min(6, math.floor(v + 0.5))))
        if applyPartyFrameAggroAttackedChrome then applyPartyFrameAggroAttackedChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partySelfCountCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = aggroBorderThicknessRow,
      offsetY = -6,
      text = L.OPT_SHOW_SELF_AGGRO_COUNT,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "showSelfAggroCount", self:GetChecked() and true or false)
        --- |applyPartyFrameAggroAttackedChrome| is called from the enemy-list layout pass; trigger
        --- one now so the change shows immediately instead of waiting for the next refresh tick.
        if applyPartyFrameAggroAttackedChrome then applyPartyFrameAggroAttackedChrome() end
      end,
      tooltip = L.TOOLTIP_OPT_SHOW_SELF_AGGRO_COUNT,
    })

    --- Incoming heal prediction toggle. Uses UnitGetIncomingHeals() when the client supports it;
    --- on older Classic clients the overlay just stays empty (no error).
    local incHealCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = partySelfCountCheck,
      text = L.OPT_PARTY_INC_HEALS,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyShowIncomingHeals", self:GetChecked() and true or false)
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_INC_HEALS,
    })

    --- Show pet frames (|pet| / |partypetN| / |raidpetN|) inside their owner's subgroup. Triggers a
    --- |updatePartyFrameSize| pass so the layout immediately grows / shrinks.
    local petCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = incHealCheck,
      text = L.OPT_PARTY_SHOW_PETS or "Show pet frames",
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyShowPets", self:GetChecked() and true or false)
        if EnemyListDB.activeProfileName == profileName and not InCombatLockdown() then
          updatePartyFrameSize()
        end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_SHOW_PETS or "Show party / raid member pets in their own frames, grouped with their owner.\n\nIncludes hunter pets, warlock minions, mage water elementals, DK ghouls, and your own pet. Toggling this on / off in combat queues until you leave combat (frame visibility is protected).",
    })

    --- Player buff icon strip (Renew, PW:Shield, Prayer of Mending, Lifebloom, Beacon, etc.).
    local playerBuffsCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = petCheck,
      text = L.OPT_PARTY_PLAYER_BUFFS or "Show your own buffs (Renew, PW:Shield, ...)",
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyShowPlayerBuffs", self:GetChecked() and true or false)
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if _EL.updatePartyPlayerBuffs then _EL.updatePartyPlayerBuffs(uf2) end
          end
        end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFFS or "Show icons of buffs cast by YOU on each party / raid member: Renew, Power Word: Shield, Prayer of Mending, Lifebloom, Rejuvenation, Beacon of Light, etc.\n\nOther casters' HoTs are filtered out — the strip stays focused on what you can refresh / extend.",
    })

    --- Slot count slider (1–8).
    local playerBuffSlotsRow = CreateFrame("Frame", nil, parent)
    playerBuffSlotsRow:SetSize(innerW, 42)
    playerBuffSlotsRow:SetPoint("TOPLEFT", playerBuffsCheck, "BOTTOMLEFT", 0, -2)
    local playerBuffSlotsSlider = createConfigOptionSlider(playerBuffSlotsRow, {
      label = L.OPT_PARTY_PLAYER_BUFF_SLOTS or "Buff slots",
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_SLOTS or "Maximum number of buff icons shown per frame (1–8). Anything beyond this count is dropped.",
      min = 1, max = 8, step = 1, integer = true,
      rowInnerWidth = innerW - 12,
      format = function(v) return tostring(math.floor(v + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyPlayerBuffSlotCount", math.max(1, math.min(8, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if _EL.updatePartyPlayerBuffs then _EL.updatePartyPlayerBuffs(uf2) end
          end
        end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Icon size slider (8–32).
    local playerBuffSizeRow = CreateFrame("Frame", nil, parent)
    playerBuffSizeRow:SetSize(innerW, 42)
    playerBuffSizeRow:SetPoint("TOPLEFT", playerBuffSlotsRow, "BOTTOMLEFT", 0, -2)
    local playerBuffSizeSlider = createConfigOptionSlider(playerBuffSizeRow, {
      label = L.OPT_PARTY_PLAYER_BUFF_SIZE or "Buff icon size",
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_SIZE or "Pixel size of each buff icon (8–32). Icons shrink automatically if they don't fit the frame width.",
      min = 8, max = 32, step = 1, integer = true,
      rowInnerWidth = innerW - 12,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyPlayerBuffIconSize", math.max(8, math.min(32, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if _EL.updatePartyPlayerBuffs then _EL.updatePartyPlayerBuffs(uf2) end
          end
        end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Max duration filter (0 = no filter; >0 hides buffs longer than N seconds).
    local playerBuffMaxDurRow = CreateFrame("Frame", nil, parent)
    playerBuffMaxDurRow:SetSize(innerW, 42)
    playerBuffMaxDurRow:SetPoint("TOPLEFT", playerBuffSizeRow, "BOTTOMLEFT", 0, -2)
    local playerBuffMaxDurSlider = createConfigOptionSlider(playerBuffMaxDurRow, {
      label = L.OPT_PARTY_PLAYER_BUFF_MAXDUR or "Max buff duration",
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_MAXDUR or "Hide buffs whose base duration exceeds this many seconds. Use to filter out auras (Mark of the Wild, Power Word: Fortitude, blessings...) and only show short-duration buffs you actually refresh — HoTs, shields, etc.\n\nSet to |cffffcc000|r to disable the filter and show every buff you cast.",
      min = 0, max = 600, step = 5, integer = true,
      rowInnerWidth = innerW - 12,
      format = function(v)
        v = math.floor(v + 0.5)
        if v == 0 then return L.OPT_VAL_OFF or "Off" end
        if v >= 60 then return string.format("%dm", math.floor(v / 60)) end
        return v .. "s"
      end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyPlayerBuffMaxDuration", math.max(0, math.min(600, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if _EL.updatePartyPlayerBuffs then _EL.updatePartyPlayerBuffs(uf2) end
          end
        end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Bar edge position (each bar independent: Bottom/Top/Left/Right). Displayed as a row of
    --- 4 small buttons per bar; the active edge is highlighted. Reused by HP/mana bar pickers below.
    local POS_ORDER = { "bottom", "top", "left", "right" }
    local POS_LABEL = {
      bottom = L.OPT_BAR_POS_BOTTOM or "Bottom",
      top    = L.OPT_BAR_POS_TOP    or "Top",
      left   = L.OPT_BAR_POS_LEFT   or "Left",
      right  = L.OPT_BAR_POS_RIGHT  or "Right",
    }

    --- Position selector for the buff strip — top/bottom run horizontal, left/right run vertical.
    local function refreshPlayerBuffsAllFrames()
      if EnemyListDB.activeProfileName == profileName then
        for _, uf2 in ipairs(partyUnitFrames) do
          if _EL.updatePartyPlayerBuffs then _EL.updatePartyPlayerBuffs(uf2) end
        end
      end
    end
    local playerBuffPosRow, playerBuffPosRefresh = Wdg.CreateStyleButtonRow(parent, {
      placeAfter = playerBuffMaxDurRow,
      offsetX = 0,
      offsetY = -4,
      rowWidth = innerW,
      titleText = L.OPT_PARTY_PLAYER_BUFF_POS or "Buff position",
      ids = POS_ORDER,
      getLabel = function(id) return POS_LABEL[id] or id end,
      getCurrent = function() return _EL.partyPlayerBuffAnchor() end,
      onPick = function(id)
        _EL.profileWrite(profileName, "partyPlayerBuffAnchor", id)
        refreshPlayerBuffsAllFrames()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_POS or "Where the buff icon strip sits on each frame. Top / Bottom run horizontally; Left / Right stack vertically.",
    })
    if playerBuffPosRow and configFrame and configFrame._elConfigPositionRows then
      playerBuffPosRow._updateSelection = playerBuffPosRefresh
      table.insert(configFrame._elConfigPositionRows, playerBuffPosRow)
    end

    --- Pixel offset sliders (X / Y) so the user can nudge the strip away from the frame edge.
    local playerBuffOffsetXRow = CreateFrame("Frame", nil, parent)
    playerBuffOffsetXRow:SetSize(innerW, 42)
    playerBuffOffsetXRow:SetPoint("TOPLEFT", playerBuffPosRow, "BOTTOMLEFT", 0, -2)
    local playerBuffOffsetXSlider = createConfigOptionSlider(playerBuffOffsetXRow, {
      label = L.OPT_PARTY_PLAYER_BUFF_OFFSET_X or "Buff offset X",
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_OFFSET_X or "Horizontal nudge in pixels (-50..50). Useful when the buff strip overlaps the HP deficit text or aggro count.",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW - 12,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyPlayerBuffOffsetX", math.max(-50, math.min(50, math.floor(v + 0.5))))
        refreshPlayerBuffsAllFrames()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local playerBuffOffsetYRow = CreateFrame("Frame", nil, parent)
    playerBuffOffsetYRow:SetSize(innerW, 42)
    playerBuffOffsetYRow:SetPoint("TOPLEFT", playerBuffOffsetXRow, "BOTTOMLEFT", 0, -2)
    local playerBuffOffsetYSlider = createConfigOptionSlider(playerBuffOffsetYRow, {
      label = L.OPT_PARTY_PLAYER_BUFF_OFFSET_Y or "Buff offset Y",
      tooltip = L.TOOLTIP_OPT_PARTY_PLAYER_BUFF_OFFSET_Y or "Vertical nudge in pixels (-50..50).",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW - 12,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyPlayerBuffOffsetY", math.max(-50, math.min(50, math.floor(v + 0.5))))
        refreshPlayerBuffsAllFrames()
      end,
      dbWriteGate = configSliderDbGate,
    })

    local partyManaCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = playerBuffOffsetYRow,
      text = L.OPT_SHOW_PARTY_MANA,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "showPartyManaBars", self:GetChecked() and true or false)
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_SHOW_PARTY_MANA,
    })

    --- Mana bar height — lives here next to the "Show mana bar" toggle so related settings are
    --- adjacent (used to live on the Colors tab).
    local partyManaHeightRow = CreateFrame("Frame", nil, parent)
    partyManaHeightRow:SetSize(innerW, 42)
    partyManaHeightRow:SetPoint("TOPLEFT", partyManaCheck, "BOTTOMLEFT", 0, -2)
    local partyManaHeightSlider = createConfigOptionSlider(partyManaHeightRow, {
      label = L.OPT_PARTY_MANA_BAR_HEIGHT or "Mana bar height",
      tooltip = L.TOOLTIP_OPT_PARTY_MANA_BAR_HEIGHT or "Height of the mana/power bar in pixels (2–40).",
      min = 2, max = 40, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyManaBarHeight", math.max(2, math.min(40, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
        _EL.reapplyPartyBarColors()
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- POS_ORDER / POS_LABEL hoisted to before the player-buff position row above (declared earlier
    --- in this function so the buff position selector can reuse them).
    local function buildPositionRow(anchorAbove, title, tooltip, dbKey, profileDbKey, getCurrent)
      local row, updateSelection = Wdg.CreateStyleButtonRow(parent, {
        placeAfter = anchorAbove,
        offsetX = 0,
        offsetY = -4,
        rowWidth = innerW,
        titleText = title,
        ids = POS_ORDER,
        getLabel = function(id)
          return POS_LABEL[id] or id
        end,
        getCurrent = getCurrent,
        onPick = function(id)
          _EL.profileWrite(profileName, profileDbKey, id)
          if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then
            syncPartyFrameUnitChrome()
          end
          updatePartyFrameSize()
        end,
        tooltip = tooltip,
      })
      if row then
        row._updateSelection = updateSelection
        if configFrame and configFrame._elConfigPositionRows then
          table.insert(configFrame._elConfigPositionRows, row)
        end
      end
      return row, updateSelection
    end

    local hpPosRow, hpPosRefresh = buildPositionRow(
      partyManaHeightRow,
      L.OPT_HP_BAR_POS or "HP bar position",
      L.TOOLTIP_OPT_HP_BAR_POS or "Where the HP bar sits on each party frame. 'Bottom'/'Top' = horizontal strip; 'Left'/'Right' = vertical strip.",
      nil, "partyHpBarPosition",
      function() return _EL.partyHpBarPosition() end)

    local manaPosRow, manaPosRefresh = buildPositionRow(
      hpPosRow,
      L.OPT_MANA_BAR_POS or "Mana bar position",
      L.TOOLTIP_OPT_MANA_BAR_POS or "Where the mana / power bar sits. If both bars pick the same edge, the mana bar stacks next to HP.",
      nil, "partyManaBarPosition",
      function() return _EL.partyManaBarPosition() end)

    --- Unit name overlay.
    local nameCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = manaPosRow,
      text = L.OPT_PARTY_SHOW_NAME,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyFrameShowName", self:GetChecked() and true or false)
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_SHOW_NAME,
    })

    local nameFontRow = CreateFrame("Frame", nil, parent)
    nameFontRow:SetSize(innerW, 42)
    nameFontRow:SetPoint("TOPLEFT", nameCheck, "BOTTOMLEFT", 0, -2)
    local nameFontScaleSlider = createConfigOptionSlider(nameFontRow, {
      label = L.OPT_PARTY_NAME_FONT_SCALE or "Name text size",
      tooltip = L.TOOLTIP_OPT_PARTY_NAME_FONT_SCALE or "Scales the unit-name text on party frames (50%–200%).",
      min = 0.5, max = 2.0, step = 0.05, integer = false,
      rowInnerWidth = innerW,
      format = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameNameFontScale", math.max(0.5, math.min(2.0, v)))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Name position — 3-way radio (Top / Middle / Bottom). Top clashes with the debuff strip;
    --- Bottom sits under the HP text; Middle works when debuffs are off.
    local NAME_POS_ORDER = { "top", "middle", "bottom" }
    local NAME_POS_LABEL = {
      top    = L.OPT_NAME_POS_TOP    or "Top",
      middle = L.OPT_NAME_POS_MIDDLE or "Middle",
      bottom = L.OPT_NAME_POS_BOTTOM or "Bottom",
    }
    local namePosRow, namePosRefresh = Wdg.CreateStyleButtonRow(parent, {
      placeAfter = nameFontRow,
      offsetX = 0,
      offsetY = -4,
      rowWidth = innerW,
      titleText = L.OPT_PARTY_NAME_POS or "Name position",
      ids = NAME_POS_ORDER,
      getLabel = function(id)
        return NAME_POS_LABEL[id] or id
      end,
      getCurrent = function()
        return _EL.partyFrameNamePosition()
      end,
      onPick = function(id)
        _EL.profileWrite(profileName, "partyFrameNamePosition", id)
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then
          syncPartyFrameUnitChrome()
        end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_NAME_POS
        or "Where the unit name sits on each party frame. 'Top' overlaps the debuff strip — pick 'Bottom' or 'Middle' if you run with debuffs on.",
    })
    if namePosRow and namePosRefresh and configFrame and configFrame._elConfigPositionRows then
      namePosRow._updateSelection = namePosRefresh
      table.insert(configFrame._elConfigPositionRows, namePosRow)
    end

    --- Pixel offsets for the name label so users can fine-tune position beyond the 3-way radio.
    --- +X = right, +Y = up (WoW convention). Range kept tight (±50px) so a stray drag can't fling
    --- the label off-frame.
    local nameOffsetXRow = CreateFrame("Frame", nil, parent)
    nameOffsetXRow:SetSize(innerW, 42)
    nameOffsetXRow:SetPoint("TOPLEFT", namePosRow, "BOTTOMLEFT", 0, -4)
    local nameOffsetXSlider = createConfigOptionSlider(nameOffsetXRow, {
      label = L.OPT_PARTY_NAME_OFFSET_X or "Name X offset",
      tooltip = L.TOOLTIP_OPT_PARTY_NAME_OFFSET_X or "Horizontal pixel offset from the selected position. Positive = right, negative = left.",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) local n = math.floor(v + 0.5); return (n > 0 and "+" or "") .. n .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameNameOffsetX", math.max(-50, math.min(50, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    local nameOffsetYRow = CreateFrame("Frame", nil, parent)
    nameOffsetYRow:SetSize(innerW, 42)
    nameOffsetYRow:SetPoint("TOPLEFT", nameOffsetXRow, "BOTTOMLEFT", 0, -2)
    local nameOffsetYSlider = createConfigOptionSlider(nameOffsetYRow, {
      label = L.OPT_PARTY_NAME_OFFSET_Y or "Name Y offset",
      tooltip = L.TOOLTIP_OPT_PARTY_NAME_OFFSET_Y or "Vertical pixel offset from the selected position. Positive = up, negative = down.",
      min = -50, max = 50, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) local n = math.floor(v + 0.5); return (n > 0 and "+" or "") .. n .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyFrameNameOffsetY", math.max(-50, math.min(50, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName and syncPartyFrameUnitChrome then syncPartyFrameUnitChrome() end
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Low-HP flash section.
    local lowHpCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = nameOffsetYRow,
      text = L.OPT_PARTY_LOW_HP_FLASH,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyLowHpFlashEnabled", self:GetChecked() and true or false)
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_LOW_HP_FLASH,
    })

    local lowHpRow = CreateFrame("Frame", nil, parent)
    lowHpRow:SetSize(innerW, 42)
    lowHpRow:SetPoint("TOPLEFT", lowHpCheck, "BOTTOMLEFT", 0, -2)
    local lowHpThresholdSlider = createConfigOptionSlider(lowHpRow, {
      label = L.OPT_PARTY_LOW_HP_THRESHOLD or "Low HP threshold",
      tooltip = L.TOOLTIP_OPT_PARTY_LOW_HP_THRESHOLD or "HP percentage at or below which the flash kicks in.",
      min = 5, max = 95, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return string.format("%d%%", math.floor(v + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyLowHpThreshold", math.max(5, math.min(95, math.floor(v + 0.5))))
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Low-Mana flash section.
    local lowManaCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = lowHpRow,
      text = L.OPT_PARTY_LOW_MANA_FLASH,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyLowManaFlashEnabled", self:GetChecked() and true or false)
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_LOW_MANA_FLASH,
    })

    local lowManaRow = CreateFrame("Frame", nil, parent)
    lowManaRow:SetSize(innerW, 42)
    lowManaRow:SetPoint("TOPLEFT", lowManaCheck, "BOTTOMLEFT", 0, -2)
    local lowManaThresholdSlider = createConfigOptionSlider(lowManaRow, {
      label = L.OPT_PARTY_LOW_MANA_THRESHOLD or "Low mana threshold",
      tooltip = L.TOOLTIP_OPT_PARTY_LOW_MANA_THRESHOLD or "Mana percentage at or below which the flash kicks in.",
      min = 5, max = 95, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return string.format("%d%%", math.floor(v + 0.5)) end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyLowManaThreshold", math.max(5, math.min(95, math.floor(v + 0.5))))
      end,
      dbWriteGate = configSliderDbGate,
    })

    --- Role icon toggle + size slider. Classic/Anniversary can only resolve MAINTANK (GetPartyAssignment);
    --- Retail uses |UnitGroupRolesAssigned|. Test mode cycles fake roles so the feature previews on any client.
    local roleIconCheck = Wdg.CreateBooleanOption(parent, {
      placeAfter = lowManaRow,
      text = L.OPT_PARTY_SHOW_ROLE_ICON,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        _EL.profileWrite(profileName, "partyShowRoleIcon", self:GetChecked() and true or false)
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if uf2._elUnit and _EL.updatePartyUnitFrame then _EL.updatePartyUnitFrame(uf2) end
          end
        end
      end,
      tooltip = L.TOOLTIP_OPT_PARTY_SHOW_ROLE_ICON,
    })

    local roleIconSizeRow = CreateFrame("Frame", nil, parent)
    roleIconSizeRow:SetSize(innerW, 42)
    roleIconSizeRow:SetPoint("TOPLEFT", roleIconCheck, "BOTTOMLEFT", 0, -2)
    local roleIconSizeSlider = createConfigOptionSlider(roleIconSizeRow, {
      label = L.OPT_PARTY_ROLE_ICON_SIZE or "Role icon size",
      tooltip = L.TOOLTIP_OPT_PARTY_ROLE_ICON_SIZE or "Pixel size of the role icon (6–32).",
      min = 6, max = 32, step = 1, integer = true,
      rowInnerWidth = innerW,
      format = function(v) return tostring(math.floor(v + 0.5)) .. "px" end,
      onChange = function(v)
        _EL.profileWrite(profileName, "partyRoleIconSize", math.max(6, math.min(32, math.floor(v + 0.5))))
        if EnemyListDB.activeProfileName == profileName then
          for _, uf2 in ipairs(partyUnitFrames) do
            if uf2._elUnit and _EL.updatePartyUnitFrame then _EL.updatePartyUnitFrame(uf2) end
          end
        end
      end,
      dbWriteGate = configSliderDbGate,
    })

    if not configFrame._elDisplaySliders then configFrame._elDisplaySliders = {} end
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = partySizeSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = unitGapSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = groupGapSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = partyHpDeficitFontScaleSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = partyHpBarHeightSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = partyAggroCountFontScaleSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = nameFontScaleSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = lowHpThresholdSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = lowManaThresholdSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = partyManaHeightSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = nameOffsetXSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = nameOffsetYSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = aggroCountOffsetXSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = aggroCountOffsetYSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = aggroBorderThicknessSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = roleIconSizeSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = playerBuffSlotsSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = playerBuffSizeSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = playerBuffMaxDurSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = playerBuffOffsetXSlider
    configFrame._elDisplaySliders[#configFrame._elDisplaySliders + 1] = playerBuffOffsetYSlider

    --- Slider / segmented rows must track |_elInnerW| on resize (same as Appearance |_elWideRows|).
    if configFrame and configFrame._elWideRows then
      for _, wrow in ipairs({
        topMark,
        partySizeRow, unitGapRow, groupGapRow, partyHpDeficitFontScaleRow, partyHpBarRow, partyAggroFontScaleRow,
        aggroCountOffsetXRow, aggroCountOffsetYRow, aggroBorderThicknessRow, partyManaHeightRow,
        hpPosRow, manaPosRow, nameFontRow, namePosRow, nameOffsetXRow, nameOffsetYRow, lowHpRow, lowManaRow, roleIconSizeRow,
      }) do
        if wrow and wrow.SetWidth then
          table.insert(configFrame._elWideRows, wrow)
        end
      end
    end

    return {
      topMark                    = topMark,
      profileName               = profileName,
      partyCheck                = partyCheck,
      partySizeSlider           = partySizeSlider,
      partyVerticalCheck        = partyVerticalCheck,
      partyUnitGapSlider        = unitGapSlider,
      partyGroupGapSlider       = groupGapSlider,
      partyHpDeficitCheck       = partyHpDeficitCheck,
      partyHpDeficitFontScale   = partyHpDeficitFontScaleSlider,
      partyDebuffCheck          = partyDebuffCheck,
      partyHealthBarHeight      = partyHpBarHeightSlider,
      partyAggroCountFontScale  = partyAggroCountFontScaleSlider,
      partySelfCountCheck       = partySelfCountCheck,
      incHealCheck              = incHealCheck,
      petCheck                  = petCheck,
      playerBuffsCheck          = playerBuffsCheck,
      playerBuffSlotsSlider     = playerBuffSlotsSlider,
      playerBuffSizeSlider      = playerBuffSizeSlider,
      playerBuffMaxDurSlider    = playerBuffMaxDurSlider,
      playerBuffPosRefresh      = playerBuffPosRefresh,
      playerBuffOffsetXSlider   = playerBuffOffsetXSlider,
      playerBuffOffsetYSlider   = playerBuffOffsetYSlider,
      partyManaCheck            = partyManaCheck,
      partyManaHeightSlider     = partyManaHeightSlider,
      hpPosRefresh              = hpPosRefresh,
      manaPosRefresh            = manaPosRefresh,
      nameCheck                 = nameCheck,
      nameFontScaleSlider       = nameFontScaleSlider,
      namePosRefresh            = namePosRefresh,
      nameOffsetXSlider         = nameOffsetXSlider,
      nameOffsetYSlider         = nameOffsetYSlider,
      aggroCountOffsetXSlider   = aggroCountOffsetXSlider,
      aggroCountOffsetYSlider   = aggroCountOffsetYSlider,
      aggroBorderCheck          = aggroBorderCheck,
      aggroBorderCustomColorCheck = aggroBorderCustomColorCheck,
      aggroBorderThicknessSlider= aggroBorderThicknessSlider,
      lowHpCheck                = lowHpCheck,
      lowHpThresholdSlider      = lowHpThresholdSlider,
      lowManaCheck              = lowManaCheck,
      lowManaThresholdSlider    = lowManaThresholdSlider,
      roleIconCheck             = roleIconCheck,
      roleIconSizeSlider        = roleIconSizeSlider,
      lastAnchor                = roleIconSizeRow,
    }
  end

  --- Party tab content (scrollChild3): edits the party profile regardless of which is active.
  configFrame._elConfigPositionRows = {}
  configFrame._elPartyPanel = buildPartyFramePanel(scrollChild3, "party", {
    title = L.CONFIG_SECTION_PARTY or "Party Frames (Party profile)",
    desc  = L.CONFIG_PARTY_DESC or "Settings on this tab always save to the Party profile. Live preview only runs when the Party profile is active; in a raid, changes are queued until you leave.",
  })
  --- Enough vertical room for all the new controls (bars / name / flash sliders).
  --- Party panel content stack: title/desc ≈60 + 11 checkboxes (~280) + 7 sliders (~300) +
  --- two flash blocks (~130) + bottom padding ≈ ~880. Keep a little slack so the bottom
  --- slider's value label isn't clipped when the last row is fully scrolled into view.
  scrollChild3:SetHeight(1420)

  --- Colors tab content (scrollChild4). Holds the RGB swatches that used to live on the Party tab.
  do
    local Wb = EnemyList.ConfigWidgets
    configFrame._elConfigColorSwatchRows = {}
    local colorsTopMark = CreateFrame("Frame", nil, scrollChild4)
    colorsTopMark:SetSize(innerW, 1)
    colorsTopMark:SetPoint("TOPLEFT", scrollChild4, "TOPLEFT", 0, 0)
    configFrame._elColorsTopMark = colorsTopMark

    local colorsTitle = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    colorsTitle:SetPoint("TOPLEFT", colorsTopMark, "TOPLEFT", 6, -6)
    colorsTitle:SetTextColor(0.74, 0.77, 0.82)
    colorsTitle:SetText(L.CONFIG_SECTION_COLORS or "Colors")

    local colorsDesc = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorsDesc:SetPoint("TOPLEFT", colorsTitle, "BOTTOMLEFT", 0, -6)
    colorsDesc:SetWidth(innerW - 12)
    colorsDesc:SetJustifyH("LEFT")
    colorsDesc:SetWordWrap(true)
    colorsDesc:SetTextColor(0.62, 0.65, 0.69)
    colorsDesc:SetText(L.CONFIG_COLORS_DESC or "All color settings live here. Changes are saved to the active profile (see Profiles tab).")
    configFrame._elColorsDesc = colorsDesc

    --- HP deficit text color. Same horizontal inset as |makeColorRow| (8px from scroll edge).
    local rowHpDeficitTextCol = CreateFrame("Frame", nil, scrollChild4)
    rowHpDeficitTextCol:SetSize(innerW - 16, 22)
    rowHpDeficitTextCol:SetPoint("TOPLEFT", colorsDesc, "BOTTOMLEFT", 8, -12)
    local lblHpDeficitText = rowHpDeficitTextCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblHpDeficitText:SetPoint("LEFT", rowHpDeficitTextCol, "LEFT", 0, 0)
    lblHpDeficitText:SetTextColor(0.7, 0.72, 0.75)
    lblHpDeficitText:SetText(L.OPT_PARTY_HP_DEFICIT_TEXT_COLOR)
    local btnHpDeficitText = CreateFrame("Button", nil, rowHpDeficitTextCol)
    btnHpDeficitText:SetSize(22, 22)
    btnHpDeficitText:SetPoint("RIGHT", rowHpDeficitTextCol, "RIGHT", 0, 0)
    local texHpDeficitText = btnHpDeficitText:CreateTexture(nil, "ARTWORK")
    texHpDeficitText:SetAllPoints()
    texHpDeficitText:SetTexture("Interface\\Buttons\\WHITE8X8")
    do
      local r, g, b = partyFrameHpDeficitTextRGB()
      texHpDeficitText:SetVertexColor(r, g, b)
    end
    btnHpDeficitText:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_PARTY_HP_DEFICIT_TEXT_COLOR, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnHpDeficitText:SetScript("OnLeave", GameTooltip_Hide)
    btnHpDeficitText:SetScript("OnClick", function()
      local r0, g0, b0 = partyFrameHpDeficitTextRGB()
      enemyListOpenRgbColorPicker(r0, g0, b0, function(r, g, b)
        if type(EnemyListDB) == "table" then
          EnemyListDB.partyFrameHpDeficitTextR = r
          EnemyListDB.partyFrameHpDeficitTextG = g
          EnemyListDB.partyFrameHpDeficitTextB = b
        end
        syncPartyHpDeficitColorsOnAllFrames()
        refreshPartyHpDeficitColorSwatches()
      end)
    end)
    configFrame._elPartyHpDeficitTextSwatchTex = texHpDeficitText

    --- HP deficit shadow/border color.
    local rowHpDeficitBorderCol = CreateFrame("Frame", nil, scrollChild4)
    rowHpDeficitBorderCol:SetSize(innerW - 16, 22)
    rowHpDeficitBorderCol:SetPoint("TOPLEFT", rowHpDeficitTextCol, "BOTTOMLEFT", 0, -6)
    local lblHpDeficitBorder = rowHpDeficitBorderCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblHpDeficitBorder:SetPoint("LEFT", rowHpDeficitBorderCol, "LEFT", 0, 0)
    lblHpDeficitBorder:SetTextColor(0.7, 0.72, 0.75)
    lblHpDeficitBorder:SetText(L.OPT_PARTY_HP_DEFICIT_BORDER_COLOR)
    local btnHpDeficitBorder = CreateFrame("Button", nil, rowHpDeficitBorderCol)
    btnHpDeficitBorder:SetSize(22, 22)
    btnHpDeficitBorder:SetPoint("RIGHT", rowHpDeficitBorderCol, "RIGHT", 0, 0)
    local texHpDeficitBorder = btnHpDeficitBorder:CreateTexture(nil, "ARTWORK")
    texHpDeficitBorder:SetAllPoints()
    texHpDeficitBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    do
      local r, g, b = partyFrameHpDeficitBorderRGB()
      texHpDeficitBorder:SetVertexColor(r, g, b)
    end
    btnHpDeficitBorder:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_PARTY_HP_DEFICIT_BORDER_COLOR, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnHpDeficitBorder:SetScript("OnLeave", GameTooltip_Hide)
    btnHpDeficitBorder:SetScript("OnClick", function()
      local r0, g0, b0 = partyFrameHpDeficitBorderRGB()
      enemyListOpenRgbColorPicker(r0, g0, b0, function(r, g, b)
        if type(EnemyListDB) == "table" then
          EnemyListDB.partyFrameHpDeficitBorderR = r
          EnemyListDB.partyFrameHpDeficitBorderG = g
          EnemyListDB.partyFrameHpDeficitBorderB = b
        end
        syncPartyHpDeficitColorsOnAllFrames()
        refreshPartyHpDeficitColorSwatches()
      end)
    end)
    configFrame._elPartyHpDeficitBorderSwatchTex = texHpDeficitBorder

    --- Aggro count color (centre digit on party frame).
    local rowAggroCountCol = CreateFrame("Frame", nil, scrollChild4)
    rowAggroCountCol:SetSize(innerW - 16, 22)
    rowAggroCountCol:SetPoint("TOPLEFT", rowHpDeficitBorderCol, "BOTTOMLEFT", 0, -6)
    local lblAggroCount = rowAggroCountCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblAggroCount:SetPoint("LEFT", rowAggroCountCol, "LEFT", 0, 0)
    lblAggroCount:SetTextColor(0.7, 0.72, 0.75)
    lblAggroCount:SetText(L.OPT_PARTY_AGGRO_COUNT_COLOR)
    local btnAggroCount = CreateFrame("Button", nil, rowAggroCountCol)
    btnAggroCount:SetSize(22, 22)
    btnAggroCount:SetPoint("RIGHT", rowAggroCountCol, "RIGHT", 0, 0)
    local texAggroCount = btnAggroCount:CreateTexture(nil, "ARTWORK")
    texAggroCount:SetAllPoints()
    texAggroCount:SetTexture("Interface\\Buttons\\WHITE8X8")
    do
      local r, g, b = partyFrameAggroCountTextRGB()
      texAggroCount:SetVertexColor(r, g, b)
    end
    btnAggroCount:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_PARTY_AGGRO_COUNT_COLOR, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnAggroCount:SetScript("OnLeave", GameTooltip_Hide)
    btnAggroCount:SetScript("OnClick", function()
      local r0, g0, b0 = partyFrameAggroCountTextRGB()
      enemyListOpenRgbColorPicker(r0, g0, b0, function(r, g, b)
        if type(EnemyListDB) == "table" then
          EnemyListDB.partyFrameAggroCountTextR = r
          EnemyListDB.partyFrameAggroCountTextG = g
          EnemyListDB.partyFrameAggroCountTextB = b
        end
        syncPartyAggroCountStyleOnAllFrames()
        refreshPartyAggroCountSwatch()
      end)
    end)
    configFrame._elPartyAggroCountSwatchTex = texAggroCount
    table.insert(configFrame._elConfigColorSwatchRows, rowHpDeficitTextCol)
    table.insert(configFrame._elConfigColorSwatchRows, rowHpDeficitBorderCol)
    table.insert(configFrame._elConfigColorSwatchRows, rowAggroCountCol)

    --- Helper: builds a "label + swatch button" row anchored below |anchorFrame|.
    --- |readRGB| returns current r,g,b; |writeRGB(r,g,b)| persists + re-applies. Returns the new row + swatch texture.
    local function makeColorRow(anchorFrame, yGap, label, tooltip, readRGB, writeRGB)
      local row = CreateFrame("Frame", nil, scrollChild4)
      row:SetSize(innerW - 16, 22)
      row:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -(yGap or 6))
      local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
      lbl:SetTextColor(0.7, 0.72, 0.75)
      lbl:SetText(label)
      local btn = CreateFrame("Button", nil, row)
      btn:SetSize(22, 22)
      btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      local tex = btn:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints()
      tex:SetTexture("Interface\\Buttons\\WHITE8X8")
      do local r, g, b = readRGB(); tex:SetVertexColor(r, g, b) end
      btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
      end)
      btn:SetScript("OnLeave", GameTooltip_Hide)
      btn:SetScript("OnClick", function()
        local r0, g0, b0 = readRGB()
        enemyListOpenRgbColorPicker(r0, g0, b0, function(r, g, b)
          writeRGB(r, g, b)
          tex:SetVertexColor(r, g, b)
        end)
      end)
      if configFrame._elConfigColorSwatchRows then
        table.insert(configFrame._elConfigColorSwatchRows, row)
      end
      return row, tex
    end

    --- Section header: Enemy row colors.
    local enemySecLbl = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemySecLbl:SetPoint("TOPLEFT", rowAggroCountCol, "BOTTOMLEFT", 0, -14)
    enemySecLbl:SetTextColor(0.85, 0.87, 0.90)
    enemySecLbl:SetText(L.CONFIG_COLORS_ENEMY_ROWS or "Enemy row colors")

    local enemyHpRow, enemyHpTex = makeColorRow(
      enemySecLbl, 8,
      L.OPT_COLOR_ENEMY_HP_BAR or "Health bar",
      L.TOOLTIP_OPT_COLOR_ENEMY_HP_BAR or "Color of the health bar on enemy rows and grid cells.",
      _EL.enemyHpBarRGB,
      function(r, g, b)
        EnemyListDB.enemyHpBarR, EnemyListDB.enemyHpBarG, EnemyListDB.enemyHpBarB = r, g, b
        _EL.reapplyEnemyBarColors()
      end)

    local enemyAggroRow, enemyAggroTex = makeColorRow(
      enemyHpRow, 6,
      L.OPT_COLOR_ENEMY_AGGRO_BAR or "Aggro / threat bar",
      L.TOOLTIP_OPT_COLOR_ENEMY_AGGRO_BAR or "Color of the vertical aggro bar in grid mode (the red bar on the left of each cell).",
      _EL.enemyAggroBarRGB,
      function(r, g, b)
        EnemyListDB.enemyAggroBarR, EnemyListDB.enemyAggroBarG, EnemyListDB.enemyAggroBarB = r, g, b
        _EL.reapplyEnemyBarColors()
      end)

    local enemyCastRow, enemyCastTex = makeColorRow(
      enemyAggroRow, 6,
      L.OPT_COLOR_ENEMY_CAST_BAR or "Cast bar",
      L.TOOLTIP_OPT_COLOR_ENEMY_CAST_BAR or "Color of the enemy cast bar on rows and grid cells.",
      _EL.enemyCastBarRGB,
      function(r, g, b)
        EnemyListDB.enemyCastBarR, EnemyListDB.enemyCastBarG, EnemyListDB.enemyCastBarB = r, g, b
        _EL.reapplyEnemyBarColors()
      end)

    --- Section header: Party frame colors.
    local partySecLbl = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partySecLbl:SetPoint("TOPLEFT", enemyCastRow, "BOTTOMLEFT", 0, -14)
    partySecLbl:SetTextColor(0.85, 0.87, 0.90)
    partySecLbl:SetText(L.CONFIG_COLORS_PARTY or "Party frame colors")

    --- Use class colors on party HP.
    local classColorCheck = Wb.CreateBooleanOption(scrollChild4, {
      placeAfter = partySecLbl,
      offsetY = -4,
      text = L.OPT_USE_CLASS_COLORS_PARTY,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        EnemyListDB.useClassColorsParty = self:GetChecked() and true or false
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_USE_CLASS_COLORS_PARTY,
    })
    configFrame._elUseClassColorsPartyCheck = classColorCheck

    local partyHpFallbackRow, partyHpFallbackTex = makeColorRow(
      classColorCheck, 4,
      L.OPT_COLOR_PARTY_HP_FALLBACK or "Party HP fallback",
      L.TOOLTIP_OPT_COLOR_PARTY_HP_FALLBACK or "Used when class colors are off, or when the unit's class can't be determined (e.g. vehicles).",
      _EL.partyHpFallbackRGB,
      function(r, g, b)
        EnemyListDB.partyHpFallbackR, EnemyListDB.partyHpFallbackG, EnemyListDB.partyHpFallbackB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    local partyHpOORRow, partyHpOORTex = makeColorRow(
      partyHpFallbackRow, 6,
      L.OPT_COLOR_PARTY_HP_OOR or "Party HP out-of-range",
      L.TOOLTIP_OPT_COLOR_PARTY_HP_OOR or "Color used on the party HP bar when the unit is outside your heal/helpful spell range.",
      _EL.partyHpOOR_RGB,
      function(r, g, b)
        EnemyListDB.partyHpOutOfRangeR, EnemyListDB.partyHpOutOfRangeG, EnemyListDB.partyHpOutOfRangeB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    --- Power-type color toggle + mana bar color. The "Show mana bar" checkbox and "Mana bar
    --- height" slider used to live here; they now belong on the Party / Raid tabs (next to the
    --- other per-profile frame settings) since they control display, not color.
    local powerTypeCheck = Wb.CreateBooleanOption(scrollChild4, {
      placeAfter = partyHpOORRow,
      offsetY = -8,
      text = L.OPT_USE_POWERTYPE_COLORS,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        EnemyListDB.usePowerTypeColorsParty = self:GetChecked() and true or false
        _EL.reapplyPartyBarColors()
      end,
      tooltip = L.TOOLTIP_OPT_USE_POWERTYPE_COLORS,
    })
    configFrame._elUsePowerTypeColorsCheck = powerTypeCheck

    local manaColorRow, manaColorTex = makeColorRow(
      powerTypeCheck, 4,
      L.OPT_COLOR_PARTY_MANA or "Mana / power bar color",
      L.TOOLTIP_OPT_COLOR_PARTY_MANA or "Used when power-type colors are off, or as a fallback.",
      _EL.partyManaBarRGB,
      function(r, g, b)
        EnemyListDB.partyManaBarR, EnemyListDB.partyManaBarG, EnemyListDB.partyManaBarB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    --- Section header: Party debuff colors. Each dispel type has its own swatch.
    local debuffSecLbl = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debuffSecLbl:SetPoint("TOPLEFT", manaColorRow, "BOTTOMLEFT", 0, -14)
    debuffSecLbl:SetTextColor(0.85, 0.87, 0.90)
    debuffSecLbl:SetText(L.CONFIG_COLORS_DEBUFFS or "Party debuff colors")

    --- Helper closure captures dispel type so each row writes its own three DB keys.
    local function makeDebuffRow(anchor, typ, label, tooltip)
      return makeColorRow(anchor, 6, label, tooltip,
        function() return _EL.debuffColorRGB(typ) end,
        function(r, g, b)
          local kR, kG, kB = _EL.debuffKeys(typ)
          if kR then
            EnemyListDB[kR], EnemyListDB[kG], EnemyListDB[kB] = r, g, b
          end
          --- Debuff strip repaints on the next party frame update tick (UNIT_AURA / poll);
          --- force a nudge so the swatch change is reflected immediately while out of combat.
          _EL.reapplyPartyBarColors()
        end)
    end

    local debuffCurseRow,   debuffCurseTex   = makeDebuffRow(debuffSecLbl, "Curse",   L.OPT_COLOR_DEBUFF_CURSE   or "Curse",            L.TOOLTIP_OPT_COLOR_DEBUFF_CURSE   or "Color for the Curse slot on party debuff strips.")
    local debuffDiseaseRow, debuffDiseaseTex = makeDebuffRow(debuffCurseRow, "Disease", L.OPT_COLOR_DEBUFF_DISEASE or "Disease",          L.TOOLTIP_OPT_COLOR_DEBUFF_DISEASE or "Color for the Disease slot on party debuff strips.")
    local debuffMagicRow,   debuffMagicTex   = makeDebuffRow(debuffDiseaseRow, "Magic",   L.OPT_COLOR_DEBUFF_MAGIC   or "Magic",            L.TOOLTIP_OPT_COLOR_DEBUFF_MAGIC   or "Color for the Magic slot on party debuff strips.")
    local debuffPoisonRow,  debuffPoisonTex  = makeDebuffRow(debuffMagicRow, "Poison",  L.OPT_COLOR_DEBUFF_POISON  or "Poison",           L.TOOLTIP_OPT_COLOR_DEBUFF_POISON  or "Color for the Poison slot on party debuff strips.")
    local debuffHealingRow, debuffHealingTex = makeDebuffRow(debuffPoisonRow, "Healing", L.OPT_COLOR_DEBUFF_HEALING or "Healing reduction", L.TOOLTIP_OPT_COLOR_DEBUFF_HEALING or "Color for the Healing-reduction slot (Mortal Strike etc.).")

    --- Low-state flash colors.
    local flashSecLbl = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flashSecLbl:SetPoint("TOPLEFT", debuffHealingRow, "BOTTOMLEFT", 0, -14)
    flashSecLbl:SetTextColor(0.85, 0.87, 0.90)
    flashSecLbl:SetText(L.CONFIG_COLORS_FLASH or "Low-state flash colors")

    local lowHpFlashRow, lowHpFlashTex = makeColorRow(
      flashSecLbl, 8,
      L.OPT_COLOR_LOW_HP_FLASH or "Low HP flash",
      L.TOOLTIP_OPT_COLOR_LOW_HP_FLASH or "Color pulsed on the party frame border when the unit drops below the low-HP threshold.",
      _EL.partyLowHpFlashRGB,
      function(r, g, b)
        EnemyListDB.partyLowHpFlashR, EnemyListDB.partyLowHpFlashG, EnemyListDB.partyLowHpFlashB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    local lowManaFlashRow, lowManaFlashTex = makeColorRow(
      lowHpFlashRow, 6,
      L.OPT_COLOR_LOW_MANA_FLASH or "Low mana flash",
      L.TOOLTIP_OPT_COLOR_LOW_MANA_FLASH or "Color pulsed on the party frame border when a mana-using unit drops below the low-mana threshold.",
      _EL.partyLowManaFlashRGB,
      function(r, g, b)
        EnemyListDB.partyLowManaFlashR, EnemyListDB.partyLowManaFlashG, EnemyListDB.partyLowManaFlashB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    --- Incoming-heal prediction colors. One for all incoming, one for the portion cast by self.
    local incHealSecLbl = scrollChild4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    incHealSecLbl:SetPoint("TOPLEFT", lowManaFlashRow, "BOTTOMLEFT", 0, -14)
    incHealSecLbl:SetTextColor(0.85, 0.87, 0.90)
    incHealSecLbl:SetText(L.CONFIG_COLORS_INC_HEAL or "Incoming heal colors")

    local incHealTotalRow, incHealTotalTex = makeColorRow(
      incHealSecLbl, 8,
      L.OPT_COLOR_INC_HEAL or "Incoming heals",
      L.TOOLTIP_OPT_COLOR_INC_HEAL or "Overlay color for total incoming heals (from self + raid) inside each party HP bar.",
      _EL.partyIncomingHealRGB,
      function(r, g, b)
        EnemyListDB.partyIncomingHealR, EnemyListDB.partyIncomingHealG, EnemyListDB.partyIncomingHealB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    local incHealSelfRow, incHealSelfTex = makeColorRow(
      incHealTotalRow, 6,
      L.OPT_COLOR_SELF_HEAL or "Your own heals",
      L.TOOLTIP_OPT_COLOR_SELF_HEAL or "Overlay color for the portion of incoming heals that you're casting yourself. Layered on top of the 'incoming heals' color so your contribution stands out.",
      _EL.partySelfHealRGB,
      function(r, g, b)
        EnemyListDB.partySelfHealR, EnemyListDB.partySelfHealG, EnemyListDB.partySelfHealB = r, g, b
        _EL.reapplyPartyBarColors()
      end)

    --- Aggro border color — only used when the "Use single color for aggro border" toggle is on;
    --- otherwise each unit borrows its entry from the party-color palette.
    local aggroBorderRow, aggroBorderTex = makeColorRow(
      incHealSelfRow, 10,
      L.OPT_COLOR_AGGRO_BORDER or "Aggro border",
      L.TOOLTIP_OPT_COLOR_AGGRO_BORDER or "Border color painted on a party frame while enemies are attacking that unit. Active when 'Use single color for aggro border' is enabled on the Party / Raid tab.",
      _EL.partyAggroBorderRGB,
      function(r, g, b)
        EnemyListDB.partyAggroBorderR, EnemyListDB.partyAggroBorderG, EnemyListDB.partyAggroBorderB = r, g, b
        if applyPartyFrameAggroAttackedChrome then applyPartyFrameAggroAttackedChrome() end
      end)

    --- Store swatch handles + getters so |refreshConfigFieldsFromDB| (e.g. after a profile switch) can
    --- re-paint each swatch to reflect the now-current DB values.
    configFrame._elColorSwatches = {
      { tex = enemyHpTex,        rgb = _EL.enemyHpBarRGB },
      { tex = enemyAggroTex,     rgb = _EL.enemyAggroBarRGB },
      { tex = enemyCastTex,      rgb = _EL.enemyCastBarRGB },
      { tex = partyHpFallbackTex,rgb = _EL.partyHpFallbackRGB },
      { tex = partyHpOORTex,     rgb = _EL.partyHpOOR_RGB },
      { tex = manaColorTex,      rgb = _EL.partyManaBarRGB },
      { tex = debuffCurseTex,    rgb = function() return _EL.debuffColorRGB("Curse")   end },
      { tex = debuffDiseaseTex,  rgb = function() return _EL.debuffColorRGB("Disease") end },
      { tex = debuffMagicTex,    rgb = function() return _EL.debuffColorRGB("Magic")   end },
      { tex = debuffPoisonTex,   rgb = function() return _EL.debuffColorRGB("Poison")  end },
      { tex = debuffHealingTex,  rgb = function() return _EL.debuffColorRGB("Healing") end },
      { tex = lowHpFlashTex,     rgb = _EL.partyLowHpFlashRGB },
      { tex = lowManaFlashTex,   rgb = _EL.partyLowManaFlashRGB },
      { tex = incHealTotalTex,   rgb = _EL.partyIncomingHealRGB },
      { tex = incHealSelfTex,    rgb = _EL.partySelfHealRGB },
      { tex = aggroBorderTex,    rgb = _EL.partyAggroBorderRGB },
    }
    configFrame._elRefreshColorSwatches = function()
      for _, ent in ipairs(configFrame._elColorSwatches) do
        local r, g, b = ent.rgb()
        if ent.tex and ent.tex.SetVertexColor then
          ent.tex:SetVertexColor(r, g, b)
        end
      end
    end

    --- Resize the scroll child. Previous baseline (~720) + flash section (~80).
    scrollChild4:SetHeight(920)
  end

  --- Profiles tab content (scrollChild5). Grid2-style auto-switch between party and raid settings.
  do
    local Wb = EnemyList.ConfigWidgets
    local profilesTopMark = CreateFrame("Frame", nil, scrollChild5)
    profilesTopMark:SetSize(innerW, 1)
    profilesTopMark:SetPoint("TOPLEFT", scrollChild5, "TOPLEFT", 0, 0)
    configFrame._elProfilesTopMark = profilesTopMark

    local profTitle = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    profTitle:SetPoint("TOPLEFT", profilesTopMark, "TOPLEFT", 6, -6)
    profTitle:SetTextColor(0.74, 0.77, 0.82)
    profTitle:SetText(L.CONFIG_SECTION_PROFILES or "Profiles (Party / Raid)")

    local profDesc = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profDesc:SetPoint("TOPLEFT", profTitle, "BOTTOMLEFT", 0, -6)
    profDesc:SetWidth(innerW - 12)
    profDesc:SetJustifyH("LEFT")
    profDesc:SetWordWrap(true)
    profDesc:SetTextColor(0.62, 0.65, 0.69)
    profDesc:SetText(L.CONFIG_PROFILES_DESC or "Two saved snapshots: one for Party and one for Raid. When auto-switch is on, entering a raid loads the Raid profile; leaving returns to Party. Settings on other tabs apply to whichever profile is currently active.")
    configFrame._elProfDesc = profDesc

    local activeLbl = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeLbl:SetPoint("TOPLEFT", profDesc, "BOTTOMLEFT", 0, -10)
    activeLbl:SetTextColor(0.85, 0.87, 0.90)
    configFrame._elActiveProfileLbl = activeLbl

    local groupStateLbl = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupStateLbl:SetPoint("TOPLEFT", activeLbl, "BOTTOMLEFT", 0, -2)
    groupStateLbl:SetTextColor(0.62, 0.65, 0.69)
    configFrame._elGroupStateLbl = groupStateLbl

    local autoCheck = Wb.CreateBooleanOption(scrollChild5, {
      point = "TOPLEFT",
      ref = groupStateLbl,
      relPoint = "BOTTOMLEFT",
      x = -6,
      y = -8,
      text = L.OPT_AUTO_SWITCH_PROFILE,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        EnemyListDB.autoSwitchProfile = self:GetChecked() and true or false
        if EnemyListDB.autoSwitchProfile then
          elSafe("profile_toggle_auto", enemyListApplyGroupProfileSwitch)
        end
        if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
      end,
      tooltip = L.TOOLTIP_OPT_AUTO_SWITCH_PROFILE,
    })
    configFrame._elAutoSwitchProfileCheck = autoCheck

    --- Manual profile selector (radio-style buttons) so the user can force-load either profile.
    local btnPartyLoad = CreateFrame("Button", nil, scrollChild5, "UIPanelButtonTemplate")
    btnPartyLoad:SetSize(140, 26)
    btnPartyLoad:SetPoint("TOPLEFT", autoCheck, "BOTTOMLEFT", 0, -8)
    btnPartyLoad:SetText(L.OPT_LOAD_PARTY or "Load Party profile")
    btnPartyLoad:SetScript("OnClick", function()
      if type(EnemyListDB) ~= "table" then return end
      if InCombatLockdown and InCombatLockdown() then
        print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_COMBAT_DEFER or "In combat — profile will switch after you leave combat."))
        return
      end
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      enemyListLoadProfile("party")
      enemyListAfterProfileLoad()
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_LOADED or "Loaded %s profile.", enemyListProfileLabel("party")))
    end)

    local btnRaidLoad = CreateFrame("Button", nil, scrollChild5, "UIPanelButtonTemplate")
    btnRaidLoad:SetSize(140, 26)
    btnRaidLoad:SetPoint("LEFT", btnPartyLoad, "RIGHT", 8, 0)
    btnRaidLoad:SetText(L.OPT_LOAD_RAID or "Load Raid profile")
    btnRaidLoad:SetScript("OnClick", function()
      if type(EnemyListDB) ~= "table" then return end
      if InCombatLockdown and InCombatLockdown() then
        print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_COMBAT_DEFER or "In combat — profile will switch after you leave combat."))
        return
      end
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      enemyListLoadProfile("raid")
      enemyListAfterProfileLoad()
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_LOADED or "Loaded %s profile.", enemyListProfileLabel("raid")))
    end)

    local btnCopyPR = CreateFrame("Button", nil, scrollChild5, "UIPanelButtonTemplate")
    btnCopyPR:SetSize(180, 26)
    btnCopyPR:SetPoint("TOPLEFT", btnPartyLoad, "BOTTOMLEFT", 0, -12)
    btnCopyPR:SetText(L.OPT_COPY_PARTY_TO_RAID or "Copy Party → Raid")
    btnCopyPR:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_COPY_PARTY_TO_RAID or "Save current settings to the Party profile, then copy them to the Raid profile (overwrites Raid).", nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnCopyPR:SetScript("OnLeave", GameTooltip_Hide)
    btnCopyPR:SetScript("OnClick", function()
      if type(EnemyListDB) ~= "table" then return end
      --- Snapshot whatever is currently on top-level into the active slot first.
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      EnemyListDB.profiles = EnemyListDB.profiles or {}
      --- Overwrite raid with a deep copy of party.
      EnemyListDB.profiles.raid = elDeepCopy(EnemyListDB.profiles.party or {})
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_COPIED or "Copied %s → %s.", enemyListProfileLabel("party"), enemyListProfileLabel("raid")))
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
    end)

    local btnCopyRP = CreateFrame("Button", nil, scrollChild5, "UIPanelButtonTemplate")
    btnCopyRP:SetSize(180, 26)
    btnCopyRP:SetPoint("LEFT", btnCopyPR, "RIGHT", 8, 0)
    btnCopyRP:SetText(L.OPT_COPY_RAID_TO_PARTY or "Copy Raid → Party")
    btnCopyRP:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_COPY_RAID_TO_PARTY or "Save current settings to the Raid profile, then copy them to the Party profile (overwrites Party).", nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnCopyRP:SetScript("OnLeave", GameTooltip_Hide)
    btnCopyRP:SetScript("OnClick", function()
      if type(EnemyListDB) ~= "table" then return end
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      EnemyListDB.profiles = EnemyListDB.profiles or {}
      EnemyListDB.profiles.party = elDeepCopy(EnemyListDB.profiles.raid or {})
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_COPIED or "Copied %s → %s.", enemyListProfileLabel("raid"), enemyListProfileLabel("party")))
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
    end)

    --- ==== Saved profiles manager (any user-named profile, plus the reserved |party|/|raid| slots) ====
    --- Entries listed below the existing buttons. Each row has a Load and (for non-reserved) Delete
    --- button. A "Save as" input at the top saves current settings under a new name.
    local savedHdr = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    savedHdr:SetPoint("TOPLEFT", btnCopyPR, "BOTTOMLEFT", 0, -14)
    savedHdr:SetTextColor(0.85, 0.87, 0.90)
    savedHdr:SetText(L.CONFIG_PROFILES_SAVED or "Saved profiles")

    local savedHint = scrollChild5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    savedHint:SetPoint("TOPLEFT", savedHdr, "BOTTOMLEFT", 0, -4)
    savedHint:SetWidth(innerW - 12)
    savedHint:SetJustifyH("LEFT")
    savedHint:SetWordWrap(true)
    savedHint:SetTextColor(0.62, 0.65, 0.69)
    savedHint:SetText(L.CONFIG_PROFILES_SAVED_HINT or "'Party' and 'Raid' are reserved and auto-switch with your group. Custom profiles load on demand — if auto-switch is on, entering or leaving a raid will replace a custom load with Party/Raid. Disable auto-switch above to stay on a custom profile.")
    configFrame._elSavedHint = savedHint

    --- Row: [EditBox "new name"]  [Save as…]
    local saveRow = CreateFrame("Frame", nil, scrollChild5)
    saveRow:SetPoint("TOPLEFT", savedHint, "BOTTOMLEFT", 0, -8)
    saveRow:SetSize(innerW - 12, 26)

    local nameBox = CreateFrame("EditBox", nil, saveRow, (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil)
    nameBox:SetSize(math.max(120, innerW - 160), 22)
    nameBox:SetPoint("LEFT", saveRow, "LEFT", 0, 0)
    nameBox:SetFontObject("ChatFontNormal")
    nameBox:SetAutoFocus(false)
    nameBox:SetTextInsets(6, 6, 4, 4)
    nameBox:SetMaxLetters(32)
    if nameBox.SetBackdrop then
      pcall(function()
        nameBox:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          tile = false, edgeSize = 1,
          insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        nameBox:SetBackdropColor(0.09, 0.10, 0.12, 0.95)
        nameBox:SetBackdropBorderColor(0.35, 0.37, 0.42, 1)
      end)
    end

    local btnSaveAs = CreateFrame("Button", nil, saveRow, "UIPanelButtonTemplate")
    btnSaveAs:SetSize(130, 24)
    btnSaveAs:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    btnSaveAs:SetText(L.OPT_SAVE_AS_PROFILE or "Save as…")
    btnSaveAs:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_SAVE_AS_PROFILE or "Snapshots your current settings into a new saved profile under the entered name. If the name already exists, it gets overwritten.", nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    btnSaveAs:SetScript("OnLeave", GameTooltip_Hide)

    --- Profile row pool — one row per profile key. Rebuilt every refresh.
    local profileRows = {}

    local function confirmDelete(name, onYes)
      --- Use StaticPopup if available; otherwise fall back to instant delete with a chat note.
      if _G.StaticPopupDialogs then
        _G.StaticPopupDialogs["ENEMYLIST_DELETE_PROFILE"] = {
          text = string.format(L.CONFIRM_DELETE_PROFILE or "Delete EnemyList profile '%s'? This cannot be undone.", tostring(name)),
          button1 = _G.YES or "Yes",
          button2 = _G.NO or "No",
          OnAccept = function() onYes() end,
          timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("ENEMYLIST_DELETE_PROFILE")
      else
        onYes()
      end
    end

    local function refreshSavedProfiles()
      if type(EnemyListDB) ~= "table" then return end
      EnemyListDB.profiles = EnemyListDB.profiles or {}
      --- Always show the two reserved slots even when empty.
      if type(EnemyListDB.profiles.party) ~= "table" then EnemyListDB.profiles.party = {} end
      if type(EnemyListDB.profiles.raid)  ~= "table" then EnemyListDB.profiles.raid  = {} end

      --- Collect + sort. Reserved names pinned to the top, then alphabetical for everything else.
      local names = {}
      for n in pairs(EnemyListDB.profiles) do names[#names + 1] = n end
      table.sort(names, function(a, b)
        local ra = (a == "party" or a == "raid")
        local rb = (b == "party" or b == "raid")
        if ra ~= rb then return ra end
        if a == "party" and b == "raid" then return true  end
        if a == "raid"  and b == "party" then return false end
        return a < b
      end)

      --- Build/reuse rows.
      local rowH = 26
      local wInner = (configFrame._elInnerW or innerW) or 300
      if configFrame._elTabScrollChildren and configFrame._elTabScrollChildren[5] and configFrame._elTabScrollChildren[5].GetWidth then
        local wx = configFrame._elTabScrollChildren[5]:GetWidth()
        if wx and wx > 32 then
          wInner = math.min(wInner, wx)
        end
      end
      local rowW = math.max(100, wInner - 12)
      local anchor = saveRow
      local active = EnemyListDB.activeProfileName or "party"
      for i = 1, math.max(#names, #profileRows) do
        local row = profileRows[i]
        local name = names[i]
        if not name then
          if row then row:Hide() end
        else
          if not row then
            row = CreateFrame("Frame", nil, scrollChild5)
            row:SetSize(rowW, rowH)
            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
            lbl:SetJustifyH("LEFT")
            row._lbl = lbl
            local btnDel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnDel:SetSize(76, 22)
            btnDel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            btnDel:SetText(L.OPT_DELETE or "Delete")
            row._btnDel = btnDel
            local btnLoad = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnLoad:SetSize(86, 22)
            btnLoad:SetPoint("RIGHT", btnDel, "LEFT", -4, 0)
            btnLoad:SetText(L.OPT_LOAD or "Load")
            row._btnLoad = btnLoad
            profileRows[i] = row
          end
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -6 or -2)
          row:Show()
          anchor = row

          local label = enemyListProfileLabel(name)
          if name ~= "party" and name ~= "raid" then label = name end
          if name == active then
            row._lbl:SetText(string.format(L.OPT_PROFILE_ROW_ACTIVE or "%s  |cff66ccff(active)|r", label))
            row._lbl:SetTextColor(0.96, 0.97, 0.99)
          else
            row._lbl:SetText(label)
            row._lbl:SetTextColor(0.74, 0.77, 0.82)
          end

          --- Load button.
          row._btnLoad:SetScript("OnClick", function()
            if InCombatLockdown and InCombatLockdown() then
              print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_COMBAT_DEFER or "In combat — profile will switch after you leave combat."))
              return
            end
            enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
            enemyListLoadProfile(name)
            enemyListAfterProfileLoad()
            if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
            print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_LOADED or "Loaded %s profile.", label))
          end)

          --- Delete button — disabled for reserved names and the active profile.
          local isReserved = (name == "party" or name == "raid")
          local isActive   = (name == active)
          if isReserved or isActive then
            row._btnDel:Disable()
            row._btnDel:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              if isReserved then
                GameTooltip:SetText(L.TOOLTIP_DELETE_RESERVED or "'Party' and 'Raid' are reserved — they power auto-switch and can't be deleted.", nil, nil, nil, nil, true)
              else
                GameTooltip:SetText(L.TOOLTIP_DELETE_ACTIVE or "Load a different profile first, then delete this one.", nil, nil, nil, nil, true)
              end
              GameTooltip:Show()
            end)
            row._btnDel:SetScript("OnLeave", GameTooltip_Hide)
          else
            row._btnDel:Enable()
            row._btnDel:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              GameTooltip:SetText(L.TOOLTIP_DELETE_PROFILE or "Delete this saved profile.", nil, nil, nil, nil, true)
              GameTooltip:Show()
            end)
            row._btnDel:SetScript("OnLeave", GameTooltip_Hide)
            row._btnDel:SetScript("OnClick", function()
              confirmDelete(name, function()
                if type(EnemyListDB) == "table" and EnemyListDB.profiles then
                  EnemyListDB.profiles[name] = nil
                end
                print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_DELETED or "Deleted profile '%s'.", name))
                if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
              end)
            end)
          end
        end
      end

      --- Resize the scroll child so all rows are reachable.
      local baseH = 260
      local totalH = baseH + math.max(0, #names) * (rowH + 2)
      scrollChild5:SetHeight(totalH)
      if configFrame._elSyncActiveScrollBounds then configFrame._elSyncActiveScrollBounds() end
    end

    --- Save-as action.
    local function trimProfileName(s)
      if type(s) ~= "string" then return "" end
      s = s:gsub("^%s+", ""):gsub("%s+$", "")
      --- Strip anything that would be awkward in a key path.
      return s:gsub("[%c\n\r\t]", "")
    end
    local function saveAsAction()
      local raw = nameBox:GetText() or ""
      local nm = trimProfileName(raw)
      if nm == "" then
        print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_NAME_REQUIRED or "Enter a name for the new profile."))
        return
      end
      if nm:lower() == "party" or nm:lower() == "raid" then
        print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_NAME_RESERVED or "'party' and 'raid' are reserved names — save under a different name and then Copy to Party/Raid if needed."))
        return
      end
      --- Snapshot whatever is currently on top-level (the active profile) under the new name.
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      EnemyListDB.profiles = EnemyListDB.profiles or {}
      EnemyListDB.profiles[nm] = elDeepCopy(EnemyListDB.profiles[EnemyListDB.activeProfileName or "party"] or {})
      nameBox:SetText("")
      nameBox:ClearFocus()
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_SAVED or "Saved current settings as profile '%s'.", nm))
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
    end
    btnSaveAs:SetScript("OnClick", saveAsAction)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); saveAsAction() end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    configFrame._elProfilesRefresh = function()
      if type(EnemyListDB) ~= "table" then return end
      local active = EnemyListDB.activeProfileName or "party"
      activeLbl:SetText(string.format(L.OPT_ACTIVE_PROFILE_LABEL or "Active profile: |cffffcc00%s|r", enemyListProfileLabel(active)))
      local desired = enemyListDesiredProfileName()
      groupStateLbl:SetText(string.format(L.OPT_GROUP_STATE_LABEL or "Current group: %s (auto-switch target: %s)", enemyListProfileLabel(desired), enemyListProfileLabel(desired)))
      autoCheck:SetChecked(EnemyListDB.autoSwitchProfile ~= false)
      refreshSavedProfiles()
    end

    configFrame._elLayoutProfilesTab = function()
      local base = (configFrame._elInnerW or innerW) or 300
      local sc5 = configFrame._elTabScrollChildren and configFrame._elTabScrollChildren[5]
      local inner = minInnerForScrollW(base, sc5)
      if inner < 200 then
        return
      end
      if profilesTopMark and profilesTopMark.SetWidth then
        profilesTopMark:SetWidth(inner)
      end
      local gap = 8
      --- |avail| = room for a row of two equal buttons: match scroll5 width, 6px typical inset from |saveRow| style.
      local hPad = 6
      local btnRowAvail = inner - 2 * hPad
      if btnPartyLoad and btnRaidLoad and btnRowAvail > gap + 8 then
        local half = math.max(1, math.floor((btnRowAvail - gap) / 2))
        if 2 * half + gap > btnRowAvail then
          half = math.max(1, math.floor((btnRowAvail - gap) / 2))
        end
        btnPartyLoad:SetSize(half, 26)
        btnRaidLoad:SetSize(half, 26)
        btnPartyLoad:ClearAllPoints()
        btnRaidLoad:ClearAllPoints()
        btnPartyLoad:SetPoint("TOPLEFT", autoCheck, "BOTTOMLEFT", 0, -8)
        btnRaidLoad:SetPoint("LEFT", btnPartyLoad, "RIGHT", gap, 0)
      end
      if btnCopyPR and btnCopyRP and btnPartyLoad and btnRowAvail and btnRowAvail > gap + 8 then
        local half2 = math.max(1, math.floor((btnRowAvail - gap) / 2))
        if 2 * half2 + gap > btnRowAvail then
          half2 = math.max(1, math.floor((btnRowAvail - gap) / 2))
        end
        btnCopyPR:SetSize(half2, 26)
        btnCopyRP:SetSize(half2, 26)
        btnCopyPR:ClearAllPoints()
        btnCopyRP:ClearAllPoints()
        btnCopyPR:SetPoint("TOPLEFT", btnPartyLoad, "BOTTOMLEFT", 0, -12)
        btnCopyRP:SetPoint("LEFT", btnCopyPR, "RIGHT", gap, 0)
      end
      if saveRow and nameBox and btnSaveAs then
        local sidePad = 6
        local saveW = 130
        saveRow:SetWidth(inner - 2 * sidePad)
        nameBox:SetWidth(math.max(80, inner - 2 * sidePad - gap - saveW - gap))
        nameBox:ClearAllPoints()
        btnSaveAs:ClearAllPoints()
        nameBox:SetPoint("LEFT", saveRow, "LEFT", 0, 0)
        btnSaveAs:SetPoint("LEFT", nameBox, "RIGHT", gap, 0)
        btnSaveAs:SetSize(saveW, 24)
      end
      refreshSavedProfiles()
    end

    configFrame._elProfilesRefresh()
  end

  --- Raid tab content (scrollChild6). Raid-specific toggles + quick profile switcher.
  do
    local Wb = EnemyList.ConfigWidgets

    local raidTopMark = CreateFrame("Frame", nil, scrollChild6)
    raidTopMark:SetSize(innerW, 1)
    raidTopMark:SetPoint("TOPLEFT", scrollChild6, "TOPLEFT", 0, 0)
    configFrame._elRaidTopMark = raidTopMark

    local raidTitle = scrollChild6:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    raidTitle:SetPoint("TOPLEFT", raidTopMark, "TOPLEFT", 6, -6)
    raidTitle:SetTextColor(0.74, 0.77, 0.82)
    raidTitle:SetText(L.CONFIG_SECTION_RAID or "Raid settings")

    local raidDesc = scrollChild6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidDesc:SetPoint("TOPLEFT", raidTitle, "BOTTOMLEFT", 0, -6)
    raidDesc:SetWidth(innerW - 12)
    raidDesc:SetJustifyH("LEFT")
    raidDesc:SetWordWrap(true)
    raidDesc:SetTextColor(0.62, 0.65, 0.69)
    raidDesc:SetText(L.CONFIG_RAID_DESC or "Most per-frame settings (size, gap, HP bar, colors) come from whichever profile is active. The Raid profile auto-loads in raid groups — use the button below to jump there now and tweak raid-only values. The toggles on this tab apply regardless of profile.")
    configFrame._elRaidDesc = raidDesc

    local raidActiveLbl = scrollChild6:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidActiveLbl:SetPoint("TOPLEFT", raidDesc, "BOTTOMLEFT", 0, -10)
    raidActiveLbl:SetTextColor(0.85, 0.87, 0.90)
    configFrame._elRaidActiveLbl = raidActiveLbl

    local raidLoadBtn = CreateFrame("Button", nil, scrollChild6, "UIPanelButtonTemplate")
    raidLoadBtn:SetSize(180, 26)
    raidLoadBtn:SetPoint("TOPLEFT", raidActiveLbl, "BOTTOMLEFT", 0, -8)
    raidLoadBtn:SetText(L.OPT_LOAD_RAID or "Load Raid profile")
    raidLoadBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.TOOLTIP_OPT_LOAD_RAID_EDIT or "Save current settings to the active profile, then load the Raid profile so subsequent edits on other tabs save to Raid.", nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    raidLoadBtn:SetScript("OnLeave", GameTooltip_Hide)
    raidLoadBtn:SetScript("OnClick", function()
      if type(EnemyListDB) ~= "table" then return end
      if InCombatLockdown and InCombatLockdown() then
        print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. (L.MSG_PROFILE_COMBAT_DEFER or "In combat — profile will switch after you leave combat."))
        return
      end
      --- Same direct swap as the Profiles tab's "Load Raid profile" button.
      enemyListCaptureProfile(EnemyListDB.activeProfileName or "party")
      enemyListLoadProfile("raid")
      enemyListAfterProfileLoad()
      if configFrame._elProfilesRefresh then configFrame._elProfilesRefresh() end
      if configFrame._elRaidRefresh then configFrame._elRaidRefresh() end
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_PROFILE_LOADED or "Loaded %s profile.", enemyListProfileLabel("raid")))
    end)
    configFrame._elRaidLoadBtn = raidLoadBtn

    local hideInRaidCheck = Wb.CreateBooleanOption(scrollChild6, {
      placeAfter = raidLoadBtn,
      offsetY = -10,
      text = L.OPT_HIDE_PARTY_IN_RAID,
      textColor = { 0.85, 0.87, 0.90 },
      onClick = function(self)
        EnemyListDB.hidePartyFramesInRaid = self:GetChecked() and true or false
        if togglePartyFramesVisibility then togglePartyFramesVisibility() end
      end,
      tooltip = L.TOOLTIP_OPT_HIDE_PARTY_IN_RAID,
    })
    configFrame._elHideInRaidCheck = hideInRaidCheck

    local raidNote = scrollChild6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    --- Same left edge and width as |raidDesc| / Party tab so the frame panel below matches Party.
    raidNote:SetPoint("TOPLEFT", hideInRaidCheck, "BOTTOMLEFT", 0, -8)
    raidNote:SetWidth(innerW - 12)
    raidNote:SetJustifyH("LEFT")
    raidNote:SetWordWrap(true)
    raidNote:SetTextColor(0.58, 0.61, 0.65)
    raidNote:SetText(L.CONFIG_RAID_NOTE or "Tip: Appearance, Party, and Colors all save to the currently-active profile. Switch profiles (Profiles tab or the button above) before tweaking raid-only looks.")
    configFrame._elRaidNote = raidNote

    configFrame._elRaidRefresh = function()
      if type(EnemyListDB) ~= "table" then return end
      local active = EnemyListDB.activeProfileName or "party"
      raidActiveLbl:SetText(string.format(L.OPT_ACTIVE_PROFILE_LABEL or "Active profile: |cffffcc00%s|r", enemyListProfileLabel(active)))
      hideInRaidCheck:SetChecked(EnemyListDB.hidePartyFramesInRaid == true)
    end
    configFrame._elRaidRefresh()

    --- Full Raid-profile party-frame controls — same widgets as the Party tab, but each edit writes
    --- to |EnemyListDB.profiles.raid.*|, so a user can keep different sizes / gaps / toggles when in
    --- a raid vs. a party without re-configuring every time.
    configFrame._elRaidPanel = buildPartyFramePanel(scrollChild6, "raid", {
      title     = L.CONFIG_SECTION_RAID_PANEL or "Raid Frames (Raid profile)",
      desc      = L.CONFIG_RAID_PANEL_DESC or "Settings on this tab always save to the Raid profile. Live preview only runs when the Raid profile is active.",
      anchorTop = raidNote,
      --- Same horizontal origin as Party tab (|scrollChild3|) — no X offset; rows use full |innerW|.
      anchorPanelOffsetX = 0,
    })

    --- Vertical extent: the shared |buildPartyFramePanel| needs the same room as the Party tab
    --- (|scrollChild3| = 1420) plus a tall raid-only header: title, wrapped desc, active profile,
    --- load button, hide-in-raid, wrapped tip (~300–400 px). 1540 was too small and cut off
    --- the bottom of the panel; keep slack when |buildPartyFramePanel| grows.
    scrollChild6:SetHeight(2000)
  end

  --- Keybinds tab (scrollChild2): points users at Clique for click-casting.
  local cliqueTopMark = CreateFrame("Frame", nil, scrollChild2)
  cliqueTopMark:SetSize(innerW, 1)
  cliqueTopMark:SetPoint("TOPLEFT", scrollChild2, "TOPLEFT", 0, 0)

  local cliqueBody = scrollChild2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cliqueBody:SetPoint("TOPLEFT", cliqueTopMark, "TOPLEFT", 6, -6)
  cliqueBody:SetWidth(innerW - 16)
  cliqueBody:SetJustifyH("LEFT")
  cliqueBody:SetJustifyV("TOP")
  cliqueBody:SetWordWrap(true)
  cliqueBody:SetTextColor(0.78, 0.80, 0.84)
  cliqueBody:SetText(L.CONFIG_KEYBINDS_BODY)
  configFrame._elCliqueTopMark = cliqueTopMark
  configFrame._elKeybindsBodyFs = cliqueBody

  configFrame._elFontSlider = fontSlider
  configFrame._elMaxAggroSlider = maxAggroSlider
  configFrame._elMaxOtherSlider = maxOtherSlider
  configFrame._elInactivitySlider = inactivitySlider
  configFrame._elScaleSlider = scaleSlider
  configFrame._elOpacitySlider = opacitySlider
  configFrame._elWidthSlider = widthSlider
  configFrame._elLockCheck = lockCheck
  configFrame._elTestCheck = testCheck

  local saveCloseBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  saveCloseBtn:SetSize(152, 30)
  saveCloseBtn:SetPoint("LEFT", footer, "LEFT", 14, 0)
  saveCloseBtn:SetText(L.OPT_SAVE_CLOSE)
  saveCloseBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.CONFIG_SAVE_CLOSE_HINT, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  saveCloseBtn:SetScript("OnLeave", GameTooltip_Hide)
  saveCloseBtn:SetScript("OnClick", function()
    saveConfigFields(configFrame)
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_CONFIG_APPLIED)
    configFrame:Hide()
  end)

  local cancelBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  cancelBtn:SetSize(124, 30)
  --- Leave room for resize grip at the footer’s bottom-right corner.
  cancelBtn:SetPoint("RIGHT", footer, "RIGHT", -(14 + 28), 0)
  cancelBtn:SetText(L.OPT_CANCEL)
  cancelBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.CONFIG_CLOSE_HINT, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  cancelBtn:SetScript("OnLeave", GameTooltip_Hide)
  cancelBtn:SetScript("OnClick", function()
    refreshConfigFieldsFromDB(configFrame)
    configFrame:Hide()
  end)

  do
    local sfs = saveCloseBtn:GetFontString()
    local cfs = cancelBtn:GetFontString()
    if sfs then
      sfs:SetTextColor(1, 1, 1)
    end
    if cfs then
      cfs:SetTextColor(1, 1, 1)
    end
  end

  --- Footer bottom-right corner (scrollbar is above the footer, so no overlap there).
  local cfgResizeGrip = CreateFrame("Button", nil, footer)
  cfgResizeGrip:SetSize(22, 22)
  cfgResizeGrip:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -8, 6)
  cfgResizeGrip:SetFrameLevel(55)
  cfgResizeGrip:EnableMouse(true)
  cfgResizeGrip:RegisterForDrag("LeftButton")
  local okCfgGrab = pcall(function()
    cfgResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    cfgResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  end)
  if not okCfgGrab then
    local cg = cfgResizeGrip:CreateTexture(nil, "OVERLAY")
    cg:SetAllPoints()
    cg:SetColorTexture(1, 1, 1, 0.3)
  end
  cfgResizeGrip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TOOLTIP_CONFIG_RESIZE, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  cfgResizeGrip:SetScript("OnLeave", GameTooltip_Hide)
  cfgResizeGrip:SetScript("OnDragStart", function()
    local cf = configFrame
    if not cf then
      return
    end
    cf._elConfigSizing = true
    cf._elManualResize = true
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
      scale = UIParent:GetEffectiveScale() or 1
    end
    if scale < 0.01 then
      scale = 1
    end
    local cx, cy = GetCursorPosition()
    cf._elResizeStartCX = cx / scale
    cf._elResizeStartCY = cy / scale
    cf._elResizeStartW = cf:GetWidth()
    cf._elResizeStartH = cf:GetHeight()
    cf:SetScript("OnUpdate", configManualResizeTick)
  end)
  cfgResizeGrip:SetScript("OnDragStop", function()
    finishConfigResize()
  end)

  if not EnemyList._configResizeWorldHook then
    EnemyList._configResizeWorldHook = true
    local wf = _G.WorldFrame or UIParent
    wf:HookScript("OnMouseUp", function(_, btn)
      if btn ~= "LeftButton" then
        return
      end
      finishConfigResize()
    end)
  end

  syncConfigInnerLayout(configFrame)
  refreshConfigFieldsFromDB(configFrame)
  configFrame._elSlidersReady = true
  configFrame._elConfigBuild = CONFIG_UI_BUILD
  syncScrollBounds()
end

local function showConfig()
  elDebug("showConfig")
  if configFrame and configFrame._elConfigBuild ~= CONFIG_UI_BUILD then
    configFrame:Hide()
    configFrame:SetParent(nil)
    configFrame = nil
  end
  if not configFrame then
    if not elSafe("createConfigFrame", createConfigFrame) then
      return
    end
  end
  if not configFrame then
    elPrintErr("showConfig", L.ERR_CONFIG_FRAME_NIL)
    return
  end
  local ok = elSafe("showConfig.apply", function()
    refreshConfigFieldsFromDB(configFrame)
    local cw = EnemyListDB.configWindowWidth or defaults.configWindowWidth
    local ch = EnemyListDB.configWindowHeight or defaults.configWindowHeight
    configFrame._elConfigSkipSize = true
    configFrame:SetSize(cw, ch)
    configFrame._elConfigSkipSize = false
    syncConfigInnerLayout(configFrame)
    configFrame:Show()
    if configFrame.SetFrameStrata then
      configFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if configFrame.SetFrameLevel then
      configFrame:SetFrameLevel(250)
    end
    if configFrame.SetToplevel then
      configFrame:SetToplevel(true)
    end
    if configFrame.Raise then
      configFrame:Raise()
    end
    if configFrame._elSyncScroll then
      configFrame._elSyncScroll()
    end
  end)
  if not ok then
    return
  end
end
EnemyList.ShowConfig = showConfig

--- Private API exposed to split sibling files (setup wizard, minimap, future modules).
--- Functions stored by reference resolve live names at call time; the |main()| getter exists
--- because |main| is a local that's assigned after createMainFrame() runs.
--- Keep this tight — anything here is an implicit module boundary. Add new entries only when a
--- sibling file genuinely needs them, and prefer passing values/callbacks over raw frame handles.
EnemyList._api = {
  initDB                    = initDB,
  initAccountDB             = initAccountDB,
  elPlayerProfileKey        = elPlayerProfileKey,
  enemyListApplyProfileData = enemyListApplyProfileData,
  elSafe                    = elSafe,
  elPrintErr                = elPrintErr,
  elDebug                   = elDebug,
  applyMaterialSurface      = applyMaterialSurface,
  setCheckButtonLabel       = setCheckButtonLabel,
  createMainFrame           = createMainFrame,
  layoutRows                = function(opt) return layoutRows(opt) end,
  applyUiScale              = applyUiScale,
  showPartyFrames           = function() if showPartyFrames then return showPartyFrames() end end,
  hidePartyFrames           = function() if hidePartyFrames then return hidePartyFrames() end end,
  main                      = function() return main end,
  showConfig                = showConfig,
  toggleMain                = function()
    if not main then return end
    if main:IsShown() then main:Hide() else main:Show() end
  end,
  --- Lets EnemyListMinimap.lua sync the "Show minimap button" checkbox when it hides the button via middle-click.
  setConfigMinimapCheck     = function(v)
    if configFrame and configFrame._elMinimapShowCheck and configFrame._elMinimapShowCheck.SetChecked then
      configFrame._elMinimapShowCheck:SetChecked(v)
    end
  end,
}

--- Setup wizard lives in EnemyListSetupWizard.lua (assigns EnemyList.ShowSetupWizard).
--- Minimap button lives in EnemyListMinimap.lua (assigns EnemyList._createMinimapButton and
--- EnemyList._applyMinimapButtonVisibility). Both files load after this one and read EnemyList._api.



local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:RegisterEvent("PLAYER_LOGOUT")
login:RegisterEvent("PLAYER_REGEN_ENABLED")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:RegisterEvent("GROUP_ROSTER_UPDATE")
pcall(function() login:RegisterEvent("RAID_ROSTER_UPDATE") end)
pcall(function() login:RegisterEvent("PARTY_MEMBERS_CHANGED") end)
local _elPendingProfileSwitch = false
login:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if type(EnemyListDB) == "table" and not EnemyListDB._enemyListKeybindsPurge1854 then
      enemyListClearLegacyAddonKeybinds()
    end
    if _elPendingProfileSwitch then
      _elPendingProfileSwitch = false
      elSafe("profile_switch_deferred", enemyListApplyGroupProfileSwitch)
    end
    if main and main:IsShown() then
      layoutRows()
    end
    return
  end
  if event == "PLAYER_LOGOUT" then
    if type(EnemyListDB) == "table" then
      elSafe("CaptureActiveProfile", EnemyList.CaptureActiveProfile)
    end
    elSafe("EnemyList.SaveAccountProfileSnapshot", EnemyList.SaveAccountProfileSnapshot)
    return
  end
  if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
    if type(EnemyListDB) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then
      _elPendingProfileSwitch = true
      return
    end
    elSafe("profile_switch_group", enemyListApplyGroupProfileSwitch)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    if type(EnemyListDB) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then
      _elPendingProfileSwitch = true
      return
    end
    elSafe("profile_switch_enter", enemyListApplyGroupProfileSwitch)
    return
  end
  elDebug("PLAYER_LOGIN")
  elSafe("initDB", initDB)
  if not elSafe("createMainFrame", createMainFrame) or not main then
    elPrintErr("PLAYER_LOGIN", L.ERR_MAIN_FRAME_FAILED)
    return
  end
  elSafe("profile_switch_login", enemyListApplyGroupProfileSwitch)
  if not EnemyListDB.setupWizardCompleted then
    EnemyList.ShowSetupWizard(false)
  else
    if not EnemyListDB.hidden then
      main:Show()
    else
      main:Hide()
    end
    layoutRows()
  end
  --- Feature: create party frames if enabled
  if EnemyListDB.showPartyFrames then
    elSafe("createPartyFrames", showPartyFrames)
  end
  --- Feature 8: create minimap button
  elSafe("createMinimapButton", createMinimapButton)
  if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
    EnemyList.RefreshNameplateThreatOverlays(true)
  end
  if type(EnemyList.RefreshNameplateListMirrors) == "function" then
    EnemyList.RefreshNameplateListMirrors(true)
  end
  print("|cff66ccff" .. L.ADDON_NAME .. "|r v" .. (EnemyList.version or "?") .. " " .. L.MSG_LOADED_PER_CHARACTER .. " " .. L.MSG_LOADED_CONFIG_HINT)
end)

SLASH_ENEMYLIST1 = "/enemylist"
SLASH_ENEMYLIST2 = "/el"

local function enemyListDebugDump()
  elSafe("initDB", initDB)
  local ver = (type(EnemyList) == "table" and EnemyList.version) or "?"
  elChatCopyLine(string.format(L.MSG_DEBUG_DUMP_START, ver))
  elChatCopyLine("version=" .. tostring(ver))
  if type(EnemyListDB) == "table" then
    elChatCopyLine(string.format(
      "debug=%s saveCombatLogToDB=%s hidden=%s testMode=%s locked=%s width=%s barHeight=%s fontPreset=%s uiScale=%s maxAggro=%s maxOther=%s",
      tostring(EnemyListDB.debug),
      tostring(EnemyListDB.saveCombatLogToDB),
      tostring(EnemyListDB.hidden),
      tostring(EnemyListDB.testMode),
      tostring(EnemyListDB.locked),
      tostring(EnemyListDB.width),
      tostring(EnemyListDB.barHeight),
      tostring(EnemyListDB.fontPreset),
      tostring(EnemyListDB.uiScale),
      tostring(EnemyListDB.maxEnemiesAggro),
      tostring(EnemyListDB.maxEnemiesOther)
    ))
  else
    elChatCopyLine("EnemyListDB=nil")
  end
  local comb = UnitAffectingCombat and UnitAffectingCombat("player")
  local lock = InCombatLockdown and InCombatLockdown()
  elChatCopyLine(string.format("UnitAffectingCombat(player)=%s InCombatLockdown=%s", tostring(comb), tostring(lock)))
  if main then
    local w, h = main:GetWidth(), main:GetHeight()
    local sOut = main.GetScale and main:GetScale()
    local sIn = mainScaleRoot and mainScaleRoot.GetScale and mainScaleRoot:GetScale()
    elChatCopyLine(string.format(
      "main shown=%s size=%.0fx%.0f outerScale=%s innerScale=%s",
      tostring(main:IsShown()),
      w or 0,
      h or 0,
      tostring(sOut),
      tostring(sIn)
    ))
  else
    elChatCopyLine("main=nil")
  end
  if rowContainer then
    elChatCopyLine(string.format("rowContainer height=%.0f", rowContainer:GetHeight() or 0))
  else
    elChatCopyLine("rowContainer=nil")
  end
  local getRows = type(EnemyList) == "table" and EnemyList.GetEnemyRows
  if type(getRows) == "function" then
    local ok, data = pcall(getRows)
    if ok and type(data) == "table" then
      local a = data.aggro or {}
      local o = data.other or {}
      elChatCopyLine(string.format("GetEnemyRows #aggro=%d #other=%d total=%s", #a, #o, tostring(data.total)))
    else
      elChatCopyLine("GetEnemyRows failed: " .. tostring(data))
    end
  else
    elChatCopyLine("GetEnemyRows=nil")
  end
  elChatCopyLine(L.MSG_DEBUG_DUMP_END)
end

local function ensureEnemyListReadyForSlash()
  elSafe("initDB", initDB)
  if main then
    return true
  end
  if elSafe("createMainFrame", createMainFrame) and main then
    if not EnemyListDB.hidden then
      main:Show()
    else
      main:Hide()
    end
    layoutRows()
    return true
  end
  elPrintErr("slash", L.ERR_MAIN_FRAME_FAILED)
  return false
end

SlashCmdList["ENEMYLIST"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  rest = rest or ""

  if cmd == "debug" then
    elSafe("initDB", initDB)
    local r = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if r == "dump" then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_DEBUG_DUMP_CHAT_NOTE)
      enemyListDebugDump()
      return
    end
    if r == "" or r == "toggle" then
      EnemyListDB.debug = not EnemyListDB.debug
    elseif r == "on" or r == "1" or r == "true" then
      EnemyListDB.debug = true
    elseif r == "off" or r == "0" or r == "false" then
      EnemyListDB.debug = false
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.SLASH_HINT)
      return
    end
    if EnemyListDB.debug then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_DEBUG_ON)
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_DEBUG_OFF)
    end
    elChatCopyLine("DEBUG mode is now " .. tostring(EnemyListDB.debug) .. " (verbose [EnemyList] lines; errors always duplicate as plain text)")
    return
  end

  if cmd == "tracecombat" or cmd == "logcombat" then
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOG_COMBAT_DEPRECATED)
    return
  end

  if cmd == "logsave" or cmd == "savelog" then
    elSafe("initDB", initDB)
    local r = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local on
    if r == "" or r == "toggle" then
      on = not EnemyListDB.saveCombatLogToDB
    elseif r == "on" or r == "1" or r == "true" then
      on = true
    elseif r == "off" or r == "0" or r == "false" then
      on = false
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.SLASH_HINT)
      return
    end
    EnemyListDB.saveCombatLogToDB = on
    if on then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOG_SAVE_ON)
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOG_SAVE_OFF)
    end
    elChatCopyLine("saveCombatLogToDB=" .. tostring(EnemyListDB.saveCombatLogToDB))
    return
  end

  if cmd == "logclear" then
    elSafe("initDB", initDB)
    EnemyListDB.combatLogLines = {}
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOG_CLEARED)
    return
  end

  if cmd == "logtest" then
    elSafe("initDB", initDB)
    local lines = EnemyListDB.combatLogLines
    local before = type(lines) == "table" and #lines or 0
    EnemyList.AppendCombatLogLine(L.MSG_LOG_TEST_LINE)
    lines = EnemyListDB.combatLogLines
    local after = type(lines) == "table" and #lines or 0
    if after <= before then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOG_TEST_NEED_LOGSAVE)
      return
    end
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_LOG_TEST_DONE, after))
    elChatCopyLine(string.format("combatLogLines count=%d — run /reload or logout so WTF writes EnemyList.lua", after))
    return
  end

  if cmd == "minimap" then
    elSafe("initDB", initDB)
    if type(EnemyListDB) ~= "table" then
      return
    end
    local r = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if r == "" or r == "toggle" then
      EnemyListDB.minimapButtonHidden = not (EnemyListDB.minimapButtonHidden == true)
    elseif r == "show" or r == "on" or r == "1" or r == "true" then
      EnemyListDB.minimapButtonHidden = false
    elseif r == "hide" or r == "off" or r == "0" or r == "false" then
      EnemyListDB.minimapButtonHidden = true
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.SLASH_HINT)
      return
    end
    elSafe("createMinimapButton", createMinimapButton)
    enemyListApplyMinimapButtonVisibility()
    if configFrame and configFrame._elMinimapShowCheck and configFrame._elMinimapShowCheck.SetChecked then
      configFrame._elMinimapShowCheck:SetChecked(EnemyListDB.minimapButtonHidden ~= true)
    end
    if EnemyListDB.minimapButtonHidden then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MINIMAP_SLASH_HIDDEN)
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MINIMAP_SLASH_SHOWN)
    end
    return
  end

  if cmd == "setup" or cmd == "wizard" or cmd == "initialsetup" or cmd == "setupwizard" then
    elSafe("initDB", initDB)
    if not elSafe("createMainFrame", createMainFrame) or not main then
      elPrintErr("slash", L.ERR_MAIN_FRAME_FAILED)
      return
    end
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_SETUP_REOPEN)
    EnemyList.ShowSetupWizard(true)
    return
  end

  if not ensureEnemyListReadyForSlash() then
    return
  end

  if cmd == "" or cmd == "show" then
    EnemyListDB.hidden = false
    main:Show()
    layoutRows()
    return
  end
  if cmd == "hide" then
    EnemyListDB.hidden = true
    main:Hide()
    return
  end
  if cmd == "toggle" then
    EnemyListDB.hidden = not main:IsShown()
    if EnemyListDB.hidden then
      main:Hide()
    else
      main:Show()
      layoutRows()
    end
    return
  end
  if cmd == "reset" then
    EnemyListDB.point = defaults.point
    EnemyListDB.relPoint = defaults.relPoint
    EnemyListDB.x = defaults.x
    EnemyListDB.y = defaults.y
    EnemyListDB.width = defaults.width
    EnemyListDB.barHeight = defaults.barHeight
    EnemyListDB.fontPreset = defaults.fontPreset
    EnemyListDB.maxEnemiesAggro = defaults.maxEnemiesAggro
    EnemyListDB.maxEnemiesOther = defaults.maxEnemiesOther
    EnemyListDB.uiScale = defaults.uiScale
    EnemyListDB.configWindowWidth = defaults.configWindowWidth
    EnemyListDB.configWindowHeight = defaults.configWindowHeight
    EnemyListDB.locked = defaults.locked
    EnemyListDB.testMode = defaults.testMode
    EnemyListDB.extendNameplateRange = defaults.extendNameplateRange
    EnemyListDB.nameplateThreatOverlay = defaults.nameplateThreatOverlay
    EnemyListDB.nameplateListMirror = defaults.nameplateListMirror
    EnemyListDB.nameplateThreatSecondStyle = defaults.nameplateThreatSecondStyle
    EnemyListDB.listShowSecondInAggroSection = defaults.listShowSecondInAggroSection
    EnemyListDB.showPartyFrames = defaults.showPartyFrames
    EnemyListDB.partyFramePoint = defaults.partyFramePoint
    EnemyListDB.partyFrameRelPoint = defaults.partyFrameRelPoint
    EnemyListDB.partyFrameX = defaults.partyFrameX
    EnemyListDB.partyFrameY = defaults.partyFrameY
    EnemyListDB.partyFrameSize = defaults.partyFrameSize
    EnemyListDB.partyFrameShowHpDeficit = defaults.partyFrameShowHpDeficit
    EnemyListDB.partyFrameShowDebuffs = defaults.partyFrameShowDebuffs
    EnemyListDB.partyFrameHealthBarHeight = defaults.partyFrameHealthBarHeight
    EnemyListDB.partyFrameHpDeficitTextR = defaults.partyFrameHpDeficitTextR
    EnemyListDB.partyFrameHpDeficitTextG = defaults.partyFrameHpDeficitTextG
    EnemyListDB.partyFrameHpDeficitTextB = defaults.partyFrameHpDeficitTextB
    EnemyListDB.partyFrameHpDeficitBorderR = defaults.partyFrameHpDeficitBorderR
    EnemyListDB.partyFrameHpDeficitBorderG = defaults.partyFrameHpDeficitBorderG
    EnemyListDB.partyFrameHpDeficitBorderB = defaults.partyFrameHpDeficitBorderB
    EnemyListDB.partyFrameHpDeficitFontScale = defaults.partyFrameHpDeficitFontScale
    EnemyListDB.partyFrameAggroCountTextR = defaults.partyFrameAggroCountTextR
    EnemyListDB.partyFrameAggroCountTextG = defaults.partyFrameAggroCountTextG
    EnemyListDB.partyFrameAggroCountTextB = defaults.partyFrameAggroCountTextB
    EnemyListDB.partyFrameAggroCountFontScale = defaults.partyFrameAggroCountFontScale
    EnemyListDB.minimapButtonHidden = defaults.minimapButtonHidden
    togglePartyFramesVisibility()
    updatePartyFrameSize()
    refreshPartyHpDeficitColorSwatches()
    refreshPartyAggroCountSwatch()
    elSafe("createMinimapButton", createMinimapButton)
    enemyListApplyMinimapButtonVisibility()
    if type(EnemyList.ApplyNameplateRangePreference) == "function" then
      EnemyList.ApplyNameplateRangePreference()
    end
    if type(EnemyList.RefreshNameplateThreatOverlays) == "function" then
      EnemyList.RefreshNameplateThreatOverlays(true)
    end
    if type(EnemyList.RefreshNameplateListMirrors) == "function" then
      EnemyList.RefreshNameplateListMirrors(true)
    end
    main:ClearAllPoints()
    if EnemyListDB.x and EnemyListDB.y then
      main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", EnemyListDB.x, EnemyListDB.y)
    else
      main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    layoutRows()
    return
  end
  if cmd == "test" then
    local r = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if r == "" or r == "toggle" then
      local cur = type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn()
      EnemyListDB.testMode = not cur
    elseif r == "on" or r == "1" or r == "true" then
      EnemyListDB.testMode = true
    elseif r == "off" or r == "0" or r == "false" then
      EnemyListDB.testMode = false
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.SLASH_HINT)
      return
    end
    if type(EnemyList.IsTestModeOn) == "function" and EnemyList.IsTestModeOn() then
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_TEST_ON)
    else
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_TEST_OFF)
    end
    if main then
      layoutRows()
    end
    return
  end
  if cmd == "config" or cmd == "options" then
    showConfig()
    return
  end
  if cmd == "height" then
    local n = tonumber(rest)
    if n then
      EnemyListDB.barHeight = math.min(BAR_HEIGHT_MAX, math.max(BAR_HEIGHT_MIN, math.floor(n)))
      layoutRows()
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_HEIGHT_SET, EnemyListDB.barHeight))
    end
    return
  end
  if cmd == "font" then
    local n = tonumber(rest)
    if n then
      EnemyListDB.fontPreset = math.min(FONT_PRESET_MAX, math.max(2, math.floor(n)))
      layoutRows()
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_FONT_SET, EnemyListDB.fontPreset))
    end
    return
  end
  if cmd == "max" then
    local n = tonumber(rest)
    if n then
      n = math.min(MAX_ENEMIES_CAP, math.max(1, math.floor(n)))
      EnemyListDB.maxEnemiesAggro = n
      EnemyListDB.maxEnemiesOther = n
      layoutRows()
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_MAX_PER_COL_SET, n, n))
    end
    return
  end
  if cmd == "scale" then
    local n = tonumber(rest)
    if n then
      EnemyListDB.uiScale = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, n))
      layoutRows()
      print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. string.format(L.MSG_SCALE_SET, EnemyListDB.uiScale))
    end
    return
  end
  if cmd == "lock" then
    EnemyListDB.locked = true
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_LOCKED)
    return
  end
  if cmd == "unlock" then
    EnemyListDB.locked = false
    print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.MSG_UNLOCKED)
    return
  end

  print("|cff66ccff" .. L.ADDON_NAME .. "|r " .. L.SLASH_HINT)
end

