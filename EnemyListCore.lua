local addonName, EnemyList = ...
local L = EnemyList.L

EnemyList.version = "1.8.96"

local playerGUID

local function saveCombatLogMirrorEnabled(db)
  if type(db) ~= "table" then
    return false
  end
  local v = db.saveCombatLogToDB
  if v == true or v == 1 then
    return true
  end
  if type(v) == "string" then
    local s = v:lower():gsub("^%s+", ""):gsub("%s+$", "")
    return s == "1" or s == "true" or s == "yes" or s == "on"
  end
  return false
end

--- Ring buffer in SavedVariables (WoW addons cannot write loose .log files). Safe to call before UI loads.
function EnemyList.AppendCombatLogLine(text)
  local db = rawget(_G, "EnemyListDB")
  if type(db) ~= "table" or not saveCombatLogMirrorEnabled(db) then
    return
  end
  local t = db.combatLogLines
  if type(t) ~= "table" then
    t = {}
    db.combatLogLines = t
  end
  local maxN = tonumber(db.combatLogMaxLines) or 500
  maxN = math.max(50, math.min(5000, math.floor(maxN + 0.5)))
  local s = tostring(text or ""):gsub("|", "/")
  local ts
  if type(_G.date) == "function" and type(_G.time) == "function" then
    local okd, ds = pcall(function()
      return date("%Y-%m-%d %H:%M:%S", time())
    end)
    ts = okd and ds or string.format("%.3f", GetTime())
  else
    ts = string.format("%.3f", GetTime())
  end
  t[#t + 1] = ts .. "\t" .. s
  while #t > maxN do
    table.remove(t, 1)
  end
end

--- Lua errors in refresh paths; also mirrors to UIErrorsFrame when available (secure/C errors often skip Lua).
local function corePrintErr(phase, err)
  local e = tostring(err or "?"):gsub("|", "/")
  local ph = tostring(phase or "?"):gsub("|", "/")
  print("|cffff4444[EnemyList ERROR]|r " .. ph .. ": " .. e)
  print("[EnemyList] ERROR " .. ph .. ": " .. e)
  local uef = _G.UIErrorsFrame
  if uef and uef.AddMessage then
    pcall(function()
      uef:AddMessage("[EnemyList] " .. ph .. ": " .. e, 1.0, 0.22, 0.22)
    end)
  end
  if type(EnemyListDB) == "table" and EnemyListDB.debug and debugstack then
    pcall(function()
      local st = debugstack(3, 10, 0) or ""
      for line in string.gmatch(st, "[^\n]+") do
        print("[EnemyList] TRACE " .. line:gsub("|", "/"))
      end
    end)
  end
  EnemyList.AppendCombatLogLine("[EnemyList] ERROR " .. ph .. ": " .. e)
end
local enemies = {}
local enemyOrder = {}
local clearEnemiesTime = 0
local CLEAR_ENEMIES_GRACE = 0.5
--- Must be declared before any function that loops raid/nameplate indices (otherwise |MAX_RAID| resolves to global, often nil).
local MAX_NAMEPLATES = 40
local MAX_RAID = 40
--- Drop enemies with no combat-log activity for this long (seconds); configured in settings (default 5).
local function getEnemyStaleCleuSec()
  local db = rawget(_G, "EnemyListDB")
  if type(db) ~= "table" then
    return 5
  end
  local v = tonumber(db.enemyInactivityFilterSec)
  if not v then
    return 5
  end
  return math.max(1, math.min(60, math.floor(v + 0.5)))
end

local function band(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return 0
  end
  if _G.bit and _G.bit.band then
    return _G.bit.band(a, b)
  end
  if _G.bit32 and _G.bit32.band then
    return _G.bit32.band(a, b)
  end
  local r, aa, bb, m = 0, a, b, 1
  for _ = 1, 32 do
    if aa % 2 == 1 and bb % 2 == 1 then
      r = r + m
    end
    aa = math.floor(aa / 2)
    bb = math.floor(bb / 2)
    if aa == 0 and bb == 0 then
      break
    end
    m = m * 2
  end
  return r
end

local function wipeTable(t)
  if wipe then
    wipe(t)
  else
    for k in pairs(t) do
      t[k] = nil
    end
  end
end

--- Format a raw threat number as a compact string: 850, 3.6k, 1.2M, etc.
--- WoW returns threat values scaled by 100; divide first to match other addons (TinyThreat, ThreatClassic).
function EnemyList.FormatThreatShort(value)
  if type(value) ~= "number" then
    return nil
  end
  value = value / 100
  local abs = math.abs(value)
  if abs < 1000 then
    return string.format("%d", value)
  elseif abs < 1000000 then
    return string.format("%.1fk", value / 1000)
  else
    return string.format("%.1fM", value / 1000000)
  end
end

local function isHostileFlags(flags)
  if not flags or not COMBATLOG_OBJECT_REACTION_HOSTILE then
    return false
  end
  return band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
end

local function isPlayerOrPet(guid, flags)
  if guid == playerGUID then
    return true
  end
  if flags and COMBATLOG_OBJECT_AFFILIATION_MINE then
    return band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
  end
  return false
end

--- Victim is player, pet, or group member (CLEU dest flags). Fallback when roster GUID cache misses.
local function isFriendlyGroupVictim(destGUID, destFlags)
  if destGUID and destGUID == playerGUID then
    return true
  end
  if not destFlags then
    return false
  end
  if COMBATLOG_OBJECT_AFFILIATION_MINE and band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
    return true
  end
  if COMBATLOG_OBJECT_AFFILIATION_PARTY and band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0 then
    return true
  end
  if COMBATLOG_OBJECT_AFFILIATION_RAID and band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0 then
    return true
  end
  return false
end

--- guid -> display name for player, pet, party, raid (CLEU destGUID often matches these; destFlags are unreliable).
local groupGuidCache = { names = {}, t = 0 }
local GROUP_GUID_CACHE_TTL = 0.35

local function invalidateGroupGuidCache()
  groupGuidCache.t = 0
end

local function refreshGroupTargets(now)
  now = now or GetTime()
  if now - groupGuidCache.t < GROUP_GUID_CACHE_TTL then
    return
  end
  groupGuidCache.t = now
  wipeTable(groupGuidCache.names)
  playerGUID = playerGUID or UnitGUID("player")
  if playerGUID then
    groupGuidCache.names[playerGUID] = UnitName("player") or "?"
  end
  if UnitExists("pet") then
    local g = UnitGUID("pet")
    if g then
      groupGuidCache.names[g] = UnitName("pet") or "?"
    end
  end
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do
      local uid = "raid" .. i
      if UnitExists(uid) then
        local g = UnitGUID(uid)
        if g then
          groupGuidCache.names[g] = UnitName(uid) or "?"
        end
      end
    end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do
      local uid = "party" .. i
      if UnitExists(uid) then
        local g = UnitGUID(uid)
        if g then
          groupGuidCache.names[g] = UnitName(uid) or "?"
        end
      end
    end
  end
end

local function cleuDestIsOurSide(destGUID, destFlags)
  if not destGUID then
    return false
  end
  playerGUID = playerGUID or UnitGUID("player")
  if playerGUID and destGUID == playerGUID then
    return true
  end
  refreshGroupTargets(GetTime())
  if groupGuidCache.names[destGUID] then
    return true
  end
  return isFriendlyGroupVictim(destGUID, destFlags)
end

local function cleuVictimDisplayName(destGUID, destName)
  if destName and destName ~= "" then
    return destName
  end
  refreshGroupTargets(GetTime())
  return groupGuidCache.names[destGUID]
end

local damageSubevents = {
  SWING_DAMAGE = true,
  SWING_MISSED = true,
  RANGE_DAMAGE = true,
  RANGE_MISSED = true,
  SPELL_DAMAGE = true,
  SPELL_MISSED = true,
  SPELL_PERIODIC_DAMAGE = true,
  SPELL_PERIODIC_MISSED = true,
  SPELL_BUILDING_DAMAGE = true,
  SPELL_BUILDING_MISSED = true,
  ENVIRONMENTAL_DAMAGE = true,
}

local function trackEnemy(guid, name, opts)
  if not guid or guid == "" or not name or name == "" then
    return
  end
  if not enemies[guid] then
    enemies[guid] = {
      guid = guid,
      name = name,
      added = GetTime(),
      firstSeen = GetTime(),
      incomingToPlayer = false,
      outgoingFromPlayer = false,
    }
    tinsert(enemyOrder, guid)
  else
    enemies[guid].name = name
    enemies[guid].added = GetTime()
    if not enemies[guid].firstSeen then
      enemies[guid].firstSeen = GetTime()
    end
  end
  local d = enemies[guid]
  if type(opts) == "table" then
    if opts.incomingToPlayer then
      d.incomingToPlayer = true
    end
    if opts.outgoingFromPlayer then
      d.outgoingFromPlayer = true
    end
    if opts.fromCleu then
      d.lastCleuTime = GetTime()
    end
  end
end

--- Hostile must be attackable. (We do not require UnitAffectingCombat(unit): on Classic / Anniversary, nameplate units often report not in combat while you are fighting them, which hid the whole list.)
local function unitHostileEligible(unit)
  if not unit or not UnitExists(unit) then
    return false
  end
  if not UnitCanAttack("player", unit) or UnitIsDead(unit) then
    return false
  end
  return true
end

local function trackFromUnitId(unit)
  if not unitHostileEligible(unit) then
    return
  end
  local g, n = UnitGUID(unit), UnitName(unit)
  if g and n then
    trackEnemy(g, n)
  end
end

--- Like trackFromUnitId but only adds the unit if it is actually in combat (threat on
--- player or any group member, or targeting a group member).  Used for nameplate scans
--- to avoid listing every nearby hostile mob that the player is not fighting.
local function trackFromUnitIdIfEngaged(unit)
  if not unitHostileEligible(unit) then
    return
  end
  --- Already tracked via combat log — just refresh the timestamp.
  local g = UnitGUID(unit)
  if g and enemies[g] then
    local n = UnitName(unit)
    if n then trackEnemy(g, n) end
    return
  end
  --- Check if the unit is in combat at all.
  if UnitAffectingCombat and not UnitAffectingCombat(unit) then
    return
  end
  --- Check if the player (or group) has threat on this unit.
  if UnitThreatSituation then
    local ok, threat = pcall(UnitThreatSituation, "player", unit)
    if ok and type(threat) == "number" and threat >= 0 then
      local n = UnitName(unit)
      if g and n then trackEnemy(g, n) end
      return
    end
  end
  --- Fallback: check if the unit is targeting the player or a group member.
  local targetUnit = unit .. "target"
  if UnitExists(targetUnit) then
    if UnitIsUnit(targetUnit, "player") or UnitIsUnit(targetUnit, "pet") then
      local n = UnitName(unit)
      if g and n then trackEnemy(g, n) end
      return
    end
    if IsInRaid and IsInRaid() then
      for i = 1, MAX_RAID do
        if UnitExists("raid" .. i) and UnitIsUnit(targetUnit, "raid" .. i) then
          local n = UnitName(unit)
          if g and n then trackEnemy(g, n) end
          return
        end
      end
    elseif IsInGroup and IsInGroup() then
      for i = 1, 4 do
        if UnitExists("party" .. i) and UnitIsUnit(targetUnit, "party" .. i) then
          local n = UnitName(unit)
          if g and n then trackEnemy(g, n) end
          return
        end
      end
    end
  end
end

local function trackFromFriendlyTarget(friendUnit)
  if not friendUnit or not UnitExists(friendUnit) then
    return
  end
  trackFromUnitId(friendUnit .. "target")
end

local function getShowPartyCombatEnemies()
  local db = rawget(_G, "EnemyListDB")
  return type(db) == "table" and db.showPartyCombatEnemies and true or false
end

--- True if a group member other than the player is in combat (party or raid).
local function anyGroupMemberInCombat()
  if not UnitAffectingCombat or not IsInGroup or not IsInGroup() then
    return false
  end
  if IsInRaid and IsInRaid() then
    for i = 1, MAX_RAID do
      local u = "raid" .. i
      if UnitExists(u) and not UnitIsUnit(u, "player") then
        local ok, ic = pcall(UnitAffectingCombat, u)
        if ok and ic then
          return true
        end
      end
    end
  else
    for i = 1, 4 do
      local u = "party" .. i
      if UnitExists(u) then
        local ok, ic = pcall(UnitAffectingCombat, u)
        if ok and ic then
          return true
        end
      end
    end
  end
  return false
end

--- List should populate: player in combat, or (option) a party/raid member is in combat.
local function enemyListCombatActive()
  local okP, playerIc = pcall(UnitAffectingCombat, "player")
  if okP and playerIc then
    return true
  end
  if getShowPartyCombatEnemies() and anyGroupMemberInCombat() then
    return true
  end
  return false
end

function EnemyList.IsEnemyListCombatActive()
  return enemyListCombatActive()
end

--- Populate: roster targets + focus/boss + nameplates + party/raid targets while list combat context is active.
local function scanDiscoveredEnemies()
  playerGUID = playerGUID or UnitGUID("player")
  if not enemyListCombatActive() then
    return
  end

  trackFromUnitId("target")
  trackFromUnitId("focus")
  for _, uid in ipairs({ "softenemy", "mouseover", "pettarget" }) do
    local ok, exists = pcall(UnitExists, uid)
    if ok and exists then
      trackFromUnitId(uid)
    end
  end
  for i = 1, 5 do
    trackFromUnitId("boss" .. i)
  end

  trackFromFriendlyTarget("player")
  if UnitExists("pet") then
    trackFromFriendlyTarget("pet")
  end
  if IsInRaid and IsInRaid() then
    for i = 1, MAX_RAID do
      trackFromFriendlyTarget("raid" .. i)
    end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do
      if UnitExists("party" .. i) then
        trackFromFriendlyTarget("party" .. i)
      end
    end
  end

  for i = 1, MAX_NAMEPLATES do
    trackFromUnitIdIfEngaged("nameplate" .. i)
  end
end

local function removeEnemy(guid)
  if not enemies[guid] then
    return
  end
  enemies[guid] = nil
  for i = #enemyOrder, 1, -1 do
    if enemyOrder[i] == guid then
      tremove(enemyOrder, i)
    end
  end
end

local function parseCleu(event, ...)
  if CombatLogGetCurrentEventInfo then
    return CombatLogGetCurrentEventInfo()
  end
  return ...
end

local function onCombatLog(event, ...)
  --- Ignore combat log events during the grace period after ClearEnemies to prevent re-adding stale enemies.
  if (GetTime() - clearEnemiesTime) < CLEAR_ENEMIES_GRACE then
    return
  end
  local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags =
    parseCleu(event, ...)
  if not subevent then
    return
  end

  if subevent == "UNIT_DIED" then
    if destGUID and enemies[destGUID] then
      removeEnemy(destGUID)
    end
    return
  end

  if not damageSubevents[subevent] then
    return
  end

  if not playerGUID then
    playerGUID = UnitGUID("player")
  end
  if not playerGUID then
    return
  end

  --- Hostile damaged player / pet / party / raid: track attacker (not only when the player is the victim).
  local ourSide = cleuDestIsOurSide(destGUID, destFlags)
  if ourSide and sourceGUID and sourceGUID ~= destGUID and not isPlayerOrPet(sourceGUID, sourceFlags) then
    if isHostileFlags(sourceFlags) or sourceFlags == nil then
      trackEnemy(sourceGUID, sourceName, {
        incomingToPlayer = (destGUID == playerGUID),
        fromCleu = true,
      })
    end
  end

  -- Outgoing: player damaged a hostile (or unknown flags) unit.
  if sourceGUID == playerGUID and destGUID and destGUID ~= playerGUID and not isPlayerOrPet(destGUID, destFlags) then
    if isHostileFlags(destFlags) or destFlags == nil then
      trackEnemy(destGUID, destName, { outgoingFromPlayer = true, fromCleu = true })
    end
  end

  --- Prefer this over nameplate *target (often broken for multiple plates). Uses roster GUID match when destName is empty.
  local vName = cleuVictimDisplayName(destGUID, destName)
  if sourceGUID and destGUID and sourceGUID ~= destGUID and enemies[sourceGUID]
    and not isPlayerOrPet(sourceGUID, sourceFlags)
    and (isHostileFlags(sourceFlags) or sourceFlags == nil)
    and ourSide and vName and vName ~= "" then
    local e = enemies[sourceGUID]
    e.inferredTargetName = vName
    e.inferredTargetTime = GetTime()
    e.lastCleuTime = GetTime()
  end
end

function EnemyList.GetPlayerGUID()
  return playerGUID
end

function EnemyList.ResolveUnitToken(guid)
  if not guid then
    return nil
  end
  if UnitGUID("target") == guid then
    return "target"
  end
  if UnitGUID("focus") == guid then
    return "focus"
  end
  local function guidMatch(unitId)
    local ok, g = pcall(UnitGUID, unitId)
    return ok and g == guid and unitId or nil
  end
  local u = guidMatch("softenemy") or guidMatch("mouseover") or guidMatch("pettarget")
  if u then
    return u
  end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and UnitGUID(u) == guid then
      return u
    end
  end
  for i = 1, 5 do
    local u = "boss" .. i
    if UnitExists(u) and UnitGUID(u) == guid then
      return u
    end
  end
  return nil
end

--- Classic / Anniversary has no direct "yards to target" API. This is a tiered estimate using
--- CheckInteractDistance (returns true if within the probe range) + C_NamePlate (nameplate implies
--- within nameplateMaxDistance ≈ 41 yd). Probe indices for hostile units: 3 = inspect (10 yd),
--- 4 = follow (28 yd). Index 2 (trade, 9 yd) and 1 (compare achievements, 28 yd) are friendly-only
--- on Vanilla. Returns a coarse yard bucket (10 / 28 / 40) or nil when unknown.
local function unitDistanceYards(unit)
  if not unit or not UnitExists(unit) then return nil end
  if type(CheckInteractDistance) == "function" then
    local ok, r = pcall(CheckInteractDistance, unit, 3)
    if ok and r then return 10 end
    ok, r = pcall(CheckInteractDistance, unit, 4)
    if ok and r then return 28 end
  end
  if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    local ok, nf = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and nf then return 40 end
  end
  return nil
end

--- Same inputs as Details! Tiny Threat: UnitDetailedThreatSituation("player", mob) → isTanking, status, threatpct, rawthreatpct, threatvalue
local function getThreatAnalysis(unit)
  local targetingPlayer = false
  if unit and UnitExists(unit) and UnitExists(unit .. "target") and UnitIsUnit(unit .. "target", "player") then
    targetingPlayer = true
  end

  if not unit or not UnitExists(unit) then
    return {
      aggroText = L.AGGRO_UNKNOWN,
      threatPct = nil,
      rawThreatPct = nil,
      isTanking = false,
      status = nil,
      hasAPI = false,
      targetingPlayer = targetingPlayer,
    }
  end

  if UnitDetailedThreatSituation then
    local ok, isTanking, status, threatpct, rawthreatpct, threatvalue = pcall(UnitDetailedThreatSituation, "player", unit)
    if ok and status ~= nil then
      local pct = type(threatpct) == "number" and threatpct or nil
      local rawPct = type(rawthreatpct) == "number" and rawthreatpct or nil
      local tv = type(threatvalue) == "number" and threatvalue or nil
      local aggroText
      if isTanking then
        aggroText = L.AGGRO_TANK
      elseif status == 2 or status == 1 then
        aggroText = L.AGGRO_HIGH
      elseif status == 0 then
        aggroText = L.AGGRO_LOW
      else
        aggroText = L.AGGRO_NONE
      end
      return {
        aggroText = aggroText,
        threatPct = pct,
        rawThreatPct = rawPct,
        threatValue = tv,
        isTanking = isTanking and true or false,
        status = status,
        hasAPI = true,
        targetingPlayer = targetingPlayer,
      }
    end
  end

  if UnitThreatSituation then
    local ok, threat = pcall(UnitThreatSituation, "player", unit)
    if ok and type(threat) == "number" then
      local pct = (threat == 3 or threat == 2) and 100 or (threat == 1 and 72) or (threat == 0 and 18) or nil
      local aggroText
      if threat == 3 or threat == 2 then
        aggroText = L.AGGRO_TANK
      elseif threat == 1 then
        aggroText = L.AGGRO_HIGH
      elseif threat == 0 then
        aggroText = L.AGGRO_LOW
      else
        aggroText = L.AGGRO_NONE
      end
      return {
        aggroText = aggroText,
        threatPct = pct,
        rawThreatPct = nil,
        isTanking = (threat == 3 or threat == 2),
        status = threat,
        hasAPI = true,
        targetingPlayer = targetingPlayer,
      }
    end
  end

  if targetingPlayer then
    return {
      aggroText = L.AGGRO_TANK,
      threatPct = 100,
      rawThreatPct = nil,
      isTanking = true,
      status = 3,
      hasAPI = true,
      targetingPlayer = true,
    }
  end

  return {
    aggroText = L.AGGRO_UNKNOWN,
    threatPct = nil,
    rawThreatPct = nil,
    isTanking = false,
    status = nil,
    hasAPI = false,
    targetingPlayer = false,
  }
end

function EnemyList.GetThreatAnalysis(unit)
  return getThreatAnalysis(unit)
end

local function isAggroSectionRow(t, data)
  if type(data) == "table" and (data.incomingToPlayer or data.outgoingFromPlayer) then
    return true
  end
  if not t then
    return false
  end
  if t.targetingPlayer or t.isTanking then
    return true
  end
  if t.status == 1 or t.status == 2 then
    return true
  end
  if type(t.threatPct) == "number" and t.threatPct >= 50 then
    return true
  end
  return false
end

--- Details! util.lua percent_color: low value → red, high → green; pass (100 - pct) so high threat on mob → red.
function EnemyList.GetThreatBackgroundRGBA(threatInfo)
  local t = threatInfo
  if not t or not t.hasAPI then
    return 0.12, 0.14, 0.18, 0.82
  end
  local pct = t.threatPct
  if t.isTanking or t.targetingPlayer then
    pct = 100
  end
  if type(pct) ~= "number" then
    if t.status == 1 or t.status == 2 then
      pct = 75
    elseif t.status == 0 then
      pct = 22
    else
      return 0.18, 0.16, 0.14, 0.78
    end
  end
  pct = math.max(0, math.min(100, pct))
  local details = _G.Details
  local r, g
  if details and type(details.percent_color) == "function" then
    r, g = details:percent_color(100 - pct, false)
  else
    local value = 100 - pct
    if value < 50 then
      r = 1
      g = (value * 2) / 100
    else
      r = (255 - (value * 2 - 100) * 255 / 100) / 255
      g = 1
    end
  end
  local a = 0.55 + (pct / 100) * 0.28
  return r, g, 0.05, a
end

local function resolveDisplayTargetName(unit, data)
  --- CLEU-backed name is reliable per mob; nameplate *target often works for only one row.
  if data and type(data.inferredTargetName) == "string" and data.inferredTargetName ~= "" then
    return data.inferredTargetName
  end
  if unit and UnitExists(unit) and UnitExists(unit .. "target") then
    local n = UnitName(unit .. "target")
    if n and n ~= "" then
      return n
    end
  end
  return L.TARGET_NONE
end

local function formatUnitLevel(unit)
  if not unit or not UnitExists(unit) then
    return L.LEVEL_UNKNOWN
  end
  local lvl = UnitLevel(unit)
  if type(lvl) ~= "number" then
    return L.LEVEL_UNKNOWN
  end
  if lvl < 0 then
    return L.LEVEL_BOSS
  end
  if lvl == 0 then
    return L.LEVEL_UNKNOWN
  end
  return tostring(lvl)
end

local function sortRows(a, b)
  return (a.name or "") < (b.name or "")
end

--- Sort modes for single-column view.
local sortModes = {
  [1] = function(a, b) -- highest aggro first
    local pa = a.threatInfo and a.threatInfo.threatPct or 0
    local pb = b.threatInfo and b.threatInfo.threatPct or 0
    if pa ~= pb then return pa > pb end
    return (a.name or "") < (b.name or "")
  end,
  [2] = function(a, b) -- lowest aggro first
    local pa = a.threatInfo and a.threatInfo.threatPct or 0
    local pb = b.threatInfo and b.threatInfo.threatPct or 0
    if pa ~= pb then return pa < pb end
    return (a.name or "") < (b.name or "")
  end,
  [3] = function(a, b) -- highest hp first
    local ha = (a.healthMax and a.healthMax > 0) and (a.health or 0) / a.healthMax or 0
    local hb = (b.healthMax and b.healthMax > 0) and (b.health or 0) / b.healthMax or 0
    if ha ~= hb then return ha > hb end
    return (a.name or "") < (b.name or "")
  end,
  [4] = function(a, b) -- lowest hp first
    local ha = (a.healthMax and a.healthMax > 0) and (a.health or 0) / a.healthMax or 0
    local hb = (b.healthMax and b.healthMax > 0) and (b.health or 0) / b.healthMax or 0
    if ha ~= hb then return ha < hb end
    return (a.name or "") < (b.name or "")
  end,
}
EnemyList.sortModes = sortModes

--- Fake rows for layout preview. Respects max row settings.
local function buildPreviewEnemyRows()
  local Loc = EnemyList.L
  if not Loc then
    return { aggro = {}, other = {}, total = 0 }
  end
  local db = type(EnemyListDB) == "table" and EnemyListDB or {}
  local singleCol = db.singleColumn
  local capA = math.max(1, math.min(20, math.floor(tonumber(db.maxEnemiesAggro) or 10)))
  local capO = math.max(1, math.min(20, math.floor(tonumber(db.maxEnemiesOther) or 10)))
  --- Fake cast names for preview.
  local fakeCasts = { "Shadow Bolt", "Fireball", "Heal", "Chain Lightning", nil, "Frostbolt", nil, "Holy Light" }
  local fakeRaidMarkers = { 8, nil, 7, nil, nil, 4, nil, nil }
  local function row(guid, name, unit, dist, distText, targetName, ti, hp, hpMax, idx)
    local castName, castStart, castEnd
    local fc = fakeCasts[((idx or 1) - 1) % #fakeCasts + 1]
    if fc then
      --- Use a very long duration so progress drift between refresh ticks is imperceptible (appears static).
      local now = GetTime()
      local duration = 1000
      local progressFrac = 0.3 + (((idx or 1) - 1) % 5) * 0.12  -- varied but deterministic per idx
      castStart = now - duration * progressFrac
      castEnd = now + duration * (1 - progressFrac)
      castName = fc
    end
    return {
      guid = guid,
      name = name,
      levelText = tostring(60 - (((idx or 1) - 1) % 4)),
      unit = unit,
      distance = dist,
      distanceText = distText,
      targetName = targetName,
      aggro = ti.aggroText,
      threatInfo = ti,
      health = hp or (50 + (((idx or 1) - 1) * 11) % 51),
      healthMax = hpMax or 100,
      castName = castName,
      castStart = castStart,
      castEnd = castEnd,
      raidMarker = fakeRaidMarkers[((idx or 1) - 1) % #fakeRaidMarkers + 1],
      runnerUpThreats = ti.runnerUps,
    }
  end
  --- Aggro entries: these mobs ARE targeting the player.
  local tiBoss = {
    aggroText = Loc.AGGRO_TANK,
    threatPct = 100,
    threatValue = 4825000,
    isTanking = true,
    status = 3,
    hasAPI = true,
    targetingPlayer = true,
    runnerUps = {
      { name = "DPS Alpha",   pct = 85 },
      { name = "DPS Bravo",   pct = 62 },
      { name = "Healer",      pct = 41 },
      { name = "DPS Charlie", pct = 18 },
      { name = "DPS Delta",   pct = 5  },
    },
  }
  local tiBrute = {
    aggroText = Loc.AGGRO_HIGH,
    threatPct = 78,
    threatValue = 3760000,
    isTanking = false,
    status = 1,
    hasAPI = true,
    targetingPlayer = true,
    runnerUps = {
      { name = "Tank",      pct = 94 },
      { name = "DPS Alpha", pct = 55 },
      { name = "Healer",    pct = 28 },
      { name = "DPS Bravo", pct = 12 },
    },
  }
  local tiStubAggro = {
    aggroText = Loc.AGGRO_UNKNOWN,
    threatPct = nil,
    threatValue = nil,
    isTanking = false,
    status = nil,
    hasAPI = false,
    targetingPlayer = true,
  }
  --- Non-aggro entries: these mobs are attacking someone ELSE.
  local tiCaster = {
    aggroText = Loc.AGGRO_LOW,
    threatPct = 34,
    threatValue = 364000,
    isTanking = false,
    status = 0,
    hasAPI = true,
    targetingPlayer = false,
    runnerUps = {
      { name = "DPS Alpha", pct = 72 },
      { name = "DPS Bravo", pct = 45 },
      { name = "Healer",    pct = 20 },
    },
  }
  local tiScout = {
    aggroText = Loc.AGGRO_NONE,
    threatPct = 11,
    threatValue = 87000,
    isTanking = false,
    status = 0,
    hasAPI = true,
    targetingPlayer = false,
    runnerUps = {
      { name = "DPS Alpha", pct = 48 },
      { name = "Tank",      pct = 22 },
    },
  }
  local tiFar = {
    aggroText = Loc.AGGRO_UNKNOWN,
    threatPct = nil,
    isTanking = false,
    status = nil,
    hasAPI = false,
    targetingPlayer = false,
  }
  local tiAggroCycle = { tiBoss, tiBrute, tiStubAggro }
  local tiOtherCycle = { tiCaster, tiScout, tiFar }
  --- Targets for non-aggro mobs: always someone else (varied names).
  local otherTargets = { "Tank", "Healer", "DPS", "Thunderfist", "Shadowbane", "Lightbeam" }
  local aggro, other = {}, {}
  if singleCol then
    --- Single column: generate capA total enemies, mix of aggro and non-aggro.
    local total = capA
    for i = 1, total do
      local isAggro = (i <= math.ceil(total / 2))
      local ti = isAggro and tiAggroCycle[((i - 1) % #tiAggroCycle) + 1] or tiOtherCycle[((i - 1) % #tiOtherCycle) + 1]
      local tgt = isAggro and (UnitName("player") or "You") or otherTargets[((i - 1) % #otherTargets) + 1]
      local name = isAggro and string.format(Loc.PREVIEW_NAME_AGGRO, i) or string.format(Loc.PREVIEW_NAME_OTHER, i)
      local hp = isAggro and (65 + ((i - 1) * 7) % 36) or (25 + ((i - 1) * 13) % 56)
      local entry = row("el-p-" .. i, name, nil, nil, Loc.DIST_UNKNOWN, tgt, ti, hp, 100, i)
      if isAggro then
        aggro[#aggro + 1] = entry
      else
        other[#other + 1] = entry
      end
    end
  else
    --- Two columns: generate capA aggro + capO other.
    for i = 1, capA do
      local tiA = tiAggroCycle[((i - 1) % #tiAggroCycle) + 1]
      aggro[#aggro + 1] = row("el-p-a-" .. i, string.format(Loc.PREVIEW_NAME_AGGRO, i), nil, nil, Loc.DIST_UNKNOWN, UnitName("player") or "You", tiA, 65 + ((i - 1) * 7) % 36, 100, i)
    end
    for i = 1, capO do
      local tiO = tiOtherCycle[((i - 1) % #tiOtherCycle) + 1]
      local otherTgt = otherTargets[((i - 1) % #otherTargets) + 1]
      other[#other + 1] = row("el-p-o-" .. i, string.format(Loc.PREVIEW_NAME_OTHER, i), nil, nil, Loc.DIST_UNKNOWN, otherTgt, tiO, 25 + ((i - 1) * 13) % 56, 100, i)
    end
  end
  return {
    aggro = aggro,
    other = other,
    total = #aggro + #other,
  }
end

--- Nameplate/group discovery is expensive; UI refresh can exceed 10/s. Throttle scans (Grid2-style: decouple discovery cadence from redraw).
local lastEnemyDiscoveryScanTime = -1e9
local ENEMY_DISCOVERY_SCAN_INTERVAL = 0.06

local function getEnemyRowsImpl()
  local aggroRows = {}
  local otherRows = {}
  --- Grace period after ClearEnemies: UnitAffectingCombat can lag behind PLAYER_REGEN_ENABLED
  --- on Anniversary, allowing scanDiscoveredEnemies to re-add stale enemies from nameplates.
  if (GetTime() - clearEnemiesTime) < CLEAR_ENEMIES_GRACE then
    return { aggro = aggroRows, other = otherRows, total = 0 }
  end
  --- No combat context: show an empty list but do not wipe tables here (flicker / party-OOC handled by REGEN + ticker).
  if not enemyListCombatActive() then
    return { aggro = aggroRows, other = otherRows, total = 0 }
  end

  local nowScan = GetTime()
  if nowScan - lastEnemyDiscoveryScanTime >= ENEMY_DISCOVERY_SCAN_INTERVAL then
    lastEnemyDiscoveryScanTime = nowScan
    scanDiscoveredEnemies()
  end

  for i = #enemyOrder, 1, -1 do
    if not enemies[enemyOrder[i]] then
      tremove(enemyOrder, i)
    end
  end

  --- Remove enemies with no damage-related CLEU for getEnemyStaleCleuSec() (nameplate-only stubs time out via firstSeen).
  do
    local now = GetTime()
    local staleSec = getEnemyStaleCleuSec()
    local toRemove = {}
    for _, guid in ipairs(enemyOrder) do
      local d = enemies[guid]
      if d then
        local last = d.lastCleuTime
        local t0 = d.firstSeen or d.added or now
        if last then
          if (now - last) >= staleSec then
            toRemove[#toRemove + 1] = guid
          end
        elseif (now - t0) >= staleSec then
          toRemove[#toRemove + 1] = guid
        end
      end
    end
    for _, g in ipairs(toRemove) do
      removeEnemy(g)
    end
  end

  for _, guid in ipairs(enemyOrder) do
    local data = enemies[guid]
    if data then
      local unit = EnemyList.ResolveUnitToken(guid)
      if unit and UnitExists(unit) and not UnitIsDead(unit) and UnitCanAttack("player", unit) then
        local dist = unitDistanceYards(unit)
        local ta = getThreatAnalysis(unit)
        local hp = UnitHealth(unit) or 0
        local hpMax = UnitHealthMax(unit) or 1
        --- Feature: aggro swap detection
        local curTarget = resolveDisplayTargetName(unit, data)
        local aggroSwapped = false
        local aggroSwapTime = data._aggroSwapTime or 0
        if data._prevTargetName and data._prevTargetName ~= curTarget and curTarget ~= L.TARGET_NONE then
          aggroSwapped = true
          aggroSwapTime = GetTime()
          data._aggroSwapTime = aggroSwapTime
        end
        data._prevTargetName = curTarget
        if not aggroSwapped and aggroSwapTime > 0 and (GetTime() - aggroSwapTime) < 1.5 then
          aggroSwapped = true
        end
        --- Feature: raid marker
        local raidMarker = nil
        pcall(function() raidMarker = GetRaidTargetIndex(unit) end)
        --- Feature: cast bar info
        local castName, castStart, castEnd = nil, nil, nil
        pcall(function()
          if UnitCastingInfo then
            local name, _, _, startMS, endMS = UnitCastingInfo(unit)
            if name then castName = name; castStart = startMS and (startMS / 1000) or nil; castEnd = endMS and (endMS / 1000) or nil end
          end
          if not castName and UnitChannelInfo then
            local name, _, _, startMS, endMS = UnitChannelInfo(unit)
            if name then castName = name; castStart = startMS and (startMS / 1000) or nil; castEnd = endMS and (endMS / 1000) or nil end
          end
        end)
        --- Feature: creature type
        local creatureType = nil
        pcall(function() creatureType = UnitCreatureType(unit) end)
        local row = {
          guid = guid,
          name = data.name or (UnitName(unit) or "?"),
          levelText = formatUnitLevel(unit),
          unit = unit,
          distance = dist,
          distanceText = dist and string.format(L.DIST_YARDS, dist) or L.DIST_UNKNOWN,
          targetName = curTarget,
          aggro = ta.aggroText,
          threatInfo = ta,
          health = hp,
          healthMax = hpMax,
          aggroSwapped = aggroSwapped,
          aggroSwapTime = aggroSwapTime,
          raidMarker = raidMarker,
          castName = castName,
          castStart = castStart,
          castEnd = castEnd,
          creatureType = creatureType,
        }
        if isAggroSectionRow(ta, data) then
          tinsert(aggroRows, row)
        else
          tinsert(otherRows, row)
        end
      elseif unit and UnitExists(unit) and UnitIsDead(unit) then
        removeEnemy(guid)
      else
        if (GetTime() - (data.added or 0)) > 60 then
          removeEnemy(guid)
        else
          local engaged = data.incomingToPlayer or data.outgoingFromPlayer
          local ta = {
            aggroText = L.AGGRO_UNKNOWN,
            threatPct = nil,
            isTanking = false,
            status = nil,
            hasAPI = false,
            targetingPlayer = engaged and true or false,
          }
          local row = {
            guid = guid,
            name = data.name or "?",
            levelText = L.LEVEL_UNKNOWN,
            unit = nil,
            distance = nil,
            distanceText = L.DIST_UNKNOWN,
            targetName = resolveDisplayTargetName(nil, data),
            aggro = ta.aggroText,
            threatInfo = ta,
          }
          if isAggroSectionRow(ta, data) then
            tinsert(aggroRows, row)
          else
            tinsert(otherRows, row)
          end
        end
      end
    end
  end

  table.sort(aggroRows, sortRows)
  table.sort(otherRows, sortRows)

  return {
    aggro = aggroRows,
    other = otherRows,
    total = #aggroRows + #otherRows,
  }
end

--- SavedVariables sometimes store non-booleans; only explicit "on" values count as test mode.
function EnemyList.IsTestModeOn()
  local db = rawget(_G, "EnemyListDB")
  if type(db) ~= "table" then
    return false
  end
  local v = db.testMode
  if v == true or v == 1 then
    return true
  end
  if v == false or v == nil or v == 0 then
    return false
  end
  if type(v) == "string" then
    local s = v:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if s == "0" or s == "false" or s == "off" or s == "no" then
      return false
    end
    return s == "1" or s == "true" or s == "on" or s == "yes"
  end
  return false
end

function EnemyList.GetEnemyRows()
  if EnemyList.IsTestModeOn() then
    return buildPreviewEnemyRows()
  end
  local ok, ret = pcall(getEnemyRowsImpl)
  if not ok then
    corePrintErr("GetEnemyRows", ret)
    return { aggro = {}, other = {}, total = 0 }
  end
  return ret
end

function EnemyList.ClearEnemies()
  wipeTable(enemies)
  wipeTable(enemyOrder)
  clearEnemiesTime = GetTime()
end

--- Match Plater-style caps: mainline 60 yd, classic-era 41 yd. Only raises nameplateMaxDistance if yours is lower (never forces down).
function EnemyList.ApplyNameplateRangePreference()
  local db = rawget(_G, "EnemyListDB")
  if type(db) == "table" and db.extendNameplateRange == false then
    return
  end
  if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
    return
  end
  local cur = tonumber(GetCVar("nameplateMaxDistance"))
  if not cur then
    return
  end
  local target = 41
  local pid, pmain = _G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE
  if pid and pmain and pid == pmain then
    target = 60
  end
  if cur < target then
    pcall(SetCVar, "nameplateMaxDistance", target)
  end
end

--- Many events (CLEU, threat, plates, …) used to each trigger a full |layoutRows| rebuild. Grid2-style: coalesce to a capped rate so we do one cheap “data pull” pass instead of dozens per second with many enemies.
local pendingUIRefresh = false
local lastUIRefreshTime = -1e9
local UI_REFRESH_MIN_INTERVAL = 0.1

local function useCoalescedUIRefresh()
  local db = rawget(_G, "EnemyListDB")
  if type(db) ~= "table" then
    return true
  end
  return db.coalesceUIRefresh ~= false
end

local function invokeUILayoutIfShown()
  local ok, err = pcall(function()
    --- If UI has not registered ShouldRefreshUI yet (before PLAYER_LOGIN), skip — avoids treating nil as “refresh”.
    local refresh = type(EnemyList.ShouldRefreshUI) == "function" and EnemyList.ShouldRefreshUI() or false
    if not refresh then
      return
    end
    if EnemyList.OnDataChanged then
      EnemyList.OnDataChanged()
    end
  end)
  if not ok then
    corePrintErr("notifyUIRefresh", err)
  end
end

local function runUIRefreshNow()
  if not pendingUIRefresh then
    return
  end
  pendingUIRefresh = false
  lastUIRefreshTime = GetTime()
  invokeUILayoutIfShown()
end

local function maybeFlushPendingUIRefresh()
  if not useCoalescedUIRefresh() then
    return
  end
  if pendingUIRefresh and (GetTime() - lastUIRefreshTime >= UI_REFRESH_MIN_INTERVAL) then
    runUIRefreshNow()
  end
end

--- |forceNow|: skip interval when coalescing (list clear, regen, etc.). Legacy mode ignores coalescing and always redraws immediately.
local function notifyUIRefresh(source, forceNow)
  if not useCoalescedUIRefresh() then
    pendingUIRefresh = false
    invokeUILayoutIfShown()
    return
  end
  pendingUIRefresh = true
  if forceNow or (GetTime() - lastUIRefreshTime >= UI_REFRESH_MIN_INTERVAL) then
    runUIRefreshNow()
  end
end

--- Limits CLEU-driven UI scheduling; coalesced mode uses a looser throttle (legacy reproduces older cadence).
local cleuRefreshNext = 0
local CLEU_UI_THROTTLE_COALESCE = 0.05
local CLEU_UI_THROTTLE_LEGACY = 0.03

local function combatUiTickInterval()
  return useCoalescedUIRefresh() and 0.08 or 0.05
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(function()
  frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
end)
pcall(function()
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
end)
pcall(function()
  frame:RegisterEvent("RAID_ROSTER_UPDATE")
end)
pcall(function()
  frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
end)

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" and select(1, ...) == addonName then
    playerGUID = UnitGUID("player")
  elseif event == "PLAYER_LOGIN" then
    playerGUID = UnitGUID("player")
    invalidateGroupGuidCache()
    EnemyList.ApplyNameplateRangePreference()
  elseif event == "PLAYER_REGEN_ENABLED" then
    --- Keep tracking if a party/raid member is still fighting (option) so the list can stay populated.
    if not (getShowPartyCombatEnemies() and anyGroupMemberInCombat()) then
      EnemyList.ClearEnemies()
    end
    notifyUIRefresh("regen_enabled", true)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    onCombatLog(event, ...)
    local t = GetTime()
    local cleuThrottle = useCoalescedUIRefresh() and CLEU_UI_THROTTLE_COALESCE or CLEU_UI_THROTTLE_LEGACY
    if t >= cleuRefreshNext then
      cleuRefreshNext = t + cleuThrottle
      notifyUIRefresh("cleu")
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    if enemyListCombatActive() then
      notifyUIRefresh("nameplate")
    end
  elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
    if enemyListCombatActive() then
      notifyUIRefresh("threat_situation")
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if enemyListCombatActive() then
      notifyUIRefresh("target_changed")
    end
  elseif event == "UNIT_THREAT_LIST_UPDATE" then
    if enemyListCombatActive() then
      notifyUIRefresh("threat_list")
    end
  elseif event == "UNIT_TARGET" then
    if enemyListCombatActive() then
      notifyUIRefresh("unit_target")
    end
  elseif event == "UNIT_HEALTH" then
    if enemyListCombatActive() and not useCoalescedUIRefresh() then
      notifyUIRefresh("unit_health")
    end
  elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
    invalidateGroupGuidCache()
    if getShowPartyCombatEnemies() then
      notifyUIRefresh("group_roster")
    end
  end
end)

frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
pcall(function() frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED") end)
pcall(function() frame:RegisterEvent("UNIT_TARGET") end)
pcall(function() frame:RegisterEvent("UNIT_HEALTH") end)

local ticker = CreateFrame("Frame")
local acc = 0
local tickerOocAccum = 0
local TICKER_OOC_CLEAR_SEC = 0.35
ticker:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  local tickStep = combatUiTickInterval()
  local due = acc >= tickStep
  if due then
    acc = 0
  end
  if not enemyListCombatActive() then
    if due then
      tickerOocAccum = tickerOocAccum + tickStep
      if tickerOocAccum >= TICKER_OOC_CLEAR_SEC then
        tickerOocAccum = 0
        if next(enemies) then
          EnemyList.ClearEnemies()
          notifyUIRefresh("ooc_party_clear", true)
        end
      end
    end
    maybeFlushPendingUIRefresh()
    return
  end
  tickerOocAccum = 0
  if due then
    notifyUIRefresh("ticker")
  end
  maybeFlushPendingUIRefresh()
end)
