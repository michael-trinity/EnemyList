local addonName, EnemyList = ...

local locales = EnemyList._locales or {}
local base = locales.enUS or {}
local locale = (GetLocale and GetLocale()) or "enUS"
local override = locales[locale] or {}

local L = {}
for k, v in pairs(base) do
  L[k] = v
end
for k, v in pairs(override) do
  L[k] = v
end

setmetatable(L, {
  __index = function(_, k)
    return base[k] or k
  end,
})

EnemyList.L = L
