# Changelog

All notable changes to **EnemyList** are documented here. Version numbers match `EnemyList.toc` / `EnemyList.version`.

## [1.8.122]

### Added

- **Max-duration filter for the player buff strip** — Hides long buffs (Mark of the Wild, Power Word: Fortitude, blessings, Thorns, paladin auras, etc.) so the strip only shows the short-duration buffs you actually need to refresh: HoTs, shields, Prayer of Mending, Beacon of Light, etc.
- New profile key `partyPlayerBuffMaxDuration` (default 60s, range 0–600s, step 5s). 0 disables the filter and shows every buff you cast. The filter also drops permanent buffs (`duration == 0`) when active.
- Helper `_EL.partyPlayerBuffMaxDuration()`.
- Config UI: "Max buff duration" slider directly under the buff icon size slider in each Party / Raid panel. Format shows `Off` / `Ns` / `Nm` depending on value.
- New locale strings `OPT_PARTY_PLAYER_BUFF_MAXDUR`, `TOOLTIP_OPT_PARTY_PLAYER_BUFF_MAXDUR`, `OPT_VAL_OFF`.

### Changed

- `updatePartyPlayerBuffs` now skips entries that fail the duration check before counting them against the slot budget — so a unit with 5 long auras and 3 HoTs still shows all 3 HoTs at the user's configured slot count.

---

## [1.8.121]

### Reverted

- Reverted the 1.8.120 aggro-counter fallback path. The new `layoutPartyColorByName` map and the multi-tier fallback in `populatePartyMemberAttacked` (threatInfo.targetingPlayer + targetName) broke the addon load. Restored the original unit-token-only counter path. Will re-attempt with a safer approach (likely a separate file to keep the main chunk's local count headroom).

---

## [1.8.120]

### Fixed

- **Aggro counter intermittently disappearing on party / raid frames** — `populatePartyMemberAttacked` only counted an enemy toward a party member when the enemy had a valid unit token (`entry.unit`) AND that unit's `..target` suffix resolved. Both conditions fail constantly during normal play: CLEU-only mobs have no unit token, plates moving in/out of nameplate range churn `entry.unit`, and `nameplateN..target` is unreliable on Anniversary. Result: counters flickered or stayed at 0 even when the enemy was clearly hitting someone.
- Added two fallbacks. If the unit-token path doesn't resolve a color index, use `entry.threatInfo.targetingPlayer` (count toward the player's slot — already computed by the core when scanning the enemy's target). If still nothing, look up `entry.targetName` (the string the core caches for who the enemy is attacking) in a new `layoutPartyColorByName` map.
- New `layoutPartyColorByName` is rebuilt alongside `layoutPartyColorByGuid` in `rebuildLayoutPartyColorByGuid`, populated from `UnitName("player")` / `UnitName("party1-4")` / `UnitName("raid1-40")`.

---

## [1.8.119]

### Added

- **Movable player buff strip** — The buff strip now has a position selector (Top / Bottom / Left / Right) and pixel-precise X/Y offset sliders, just like the HP / mana bar pickers. Top and Bottom render the icons left-to-right; Left and Right stack them vertically.
- New profile keys: `partyPlayerBuffAnchor` (default "bottom"), `partyPlayerBuffOffsetX`, `partyPlayerBuffOffsetY` (both default 0, range -50..50).
- Helpers: `_EL.partyPlayerBuffAnchor()`, `_EL.partyPlayerBuffOffsetX()`, `_EL.partyPlayerBuffOffsetY()`.
- Config UI: "Buff position" 4-button row + "Buff offset X / Y" sliders, placed directly under the buff size slider.
- New locale strings `OPT_PARTY_PLAYER_BUFF_POS`, `TOOLTIP_OPT_PARTY_PLAYER_BUFF_POS`, `OPT_PARTY_PLAYER_BUFF_OFFSET_X`, `OPT_PARTY_PLAYER_BUFF_OFFSET_Y` (+ tooltips).

### Changed

- `layoutPartyPlayerBuffRow` now branches on the configured anchor: horizontal placement (top/bottom) lays icons left-to-right at the chosen edge; vertical placement (left/right) stacks them top-to-bottom. Icon sizing accounts for the available main-axis extent so they shrink to fit either axis.
- `POS_ORDER` / `POS_LABEL` hoisted earlier in the panel builder so the buff position picker can reuse them (previously they were declared below my new section).

---

## [1.8.118]

### Added

- **Player buff icon strip on party / raid frames** — Show icons of buffs cast BY THE PLAYER on each member: Renew, Power Word: Shield, Prayer of Mending, Lifebloom, Rejuvenation, Beacon of Light, etc. Other casters' HoTs are filtered out so the strip stays focused on what you can refresh / extend. Each icon shows the spell texture, stack count (top-right), and remaining time (bottom). Anchored to the bottom edge of each frame so it doesn't conflict with the dispel debuff strip on top.
- New profile keys: `partyShowPlayerBuffs` (default off), `partyPlayerBuffSlotCount` (default 5, 1–8), `partyPlayerBuffIconSize` (default 14px, 8–32).
- Helpers: `_EL.partyShowPlayerBuffs()`, `_EL.partyPlayerBuffSlotCount()`, `_EL.partyPlayerBuffIconSize()`, `_EL.updatePartyPlayerBuffs(uf)`.
- Config UI: "Show your own buffs" toggle + "Buff slots" slider + "Buff icon size" slider in each Party / Raid panel, between *Show pet frames* and *Show mana bar*.
- Test mode: populates fake buff icons cycling Renew, PW:Shield, Prayer of Mending, Rejuvenation, Lifebloom, Beacon of Light, Regrowth so the strip is previewable.
- New locale strings `OPT_PARTY_PLAYER_BUFFS`, `TOOLTIP_OPT_PARTY_PLAYER_BUFFS`, `OPT_PARTY_PLAYER_BUFF_SLOTS`, `TOOLTIP_OPT_PARTY_PLAYER_BUFF_SLOTS`, `OPT_PARTY_PLAYER_BUFF_SIZE`, `TOOLTIP_OPT_PARTY_PLAYER_BUFF_SIZE`.

### Changed

- Live: `_EL.updatePartyUnitFrame(uf)` now also drives `updatePartyPlayerBuffs(uf)`, so existing `UNIT_AURA` / poll paths refresh the buff icons without extra wiring.
- Each unit frame now allocates 8 slot containers up-front (max), regardless of the configured count, so the slider doesn't need to recreate widgets when you raise it.

---

## [1.8.117]

### Fixed

- **Test mode flooded the screen with all 90 frames** — Both the layout pass and the test-mode visual loop force-showed every frame in `partyUnitFrames` (5 party + 5 pets + 40 raid + 40 raidpets). The party config tab looked broken because users got a 40-man raid grid rendered on top of a 5-man party preview. Test mode now scopes the preview to the active profile: `party` shows `player + party1-4 + pet + partypet1-4` only, and `raid` shows `raid1-40 + raidpet1-40` only. Frames outside the active profile are hidden cleanly and parked off-screen.
- **Switching profiles while test mode is active** now immediately re-scopes the preview because `enemyListAfterProfileLoad()` already calls `updatePartyFrameSize()`, and the layout/test loops re-read `EnemyListDB.activeProfileName` on each pass.

---

## [1.8.116]

### Added

- **Pet strip in party/raid layout** — Pets render in their own dedicated lane within each subgroup: a second row beneath the members in horizontal layout, or a second column beside them in vertical layout. The strip is separated by a small extra gap so it reads as visually distinct from the member row.
- **Pet test data** — Test mode now populates pet frames with smaller HP pools and a warm tan color (creature-type-Beast tint) so they're easy to identify at a glance. Honors the `partyShowPets` toggle in test mode too — toggling off cleanly hides the pet strip.

### Changed

- `groups[g]` is now a `{ members, pets }` pair rather than a flat array; the layout pass positions each lane independently.
- Test-mode subgroup math: `pet` and `partypetN` now go to subgroup 1 (matching their owners), and `raidpetN` mirrors `raidN`'s subgroup bucket — previously pets ended up in subgroup 2 because their `fi` indices fell into the next 5-frame bucket.
- `partyFrameContainer` size accounts for the extra pet lane (width when vertical, height when horizontal).

---

## [1.8.115]

### Fixed

- **Pet frames not appearing when toggled on** — The `_EL.partyShowPets()` helper called `_EL.profileRead(nil, key)`, but `profileRead` does `EnemyListDB.profiles[nil]` for a nil profile name (which is just `nil`), so the result fell through to `defaults[key] = false` regardless of what the user toggled. Same bug existed in `_EL.partyShowRoleIcon()` and `_EL.partyRoleIconSize()`. Both helpers now read `EnemyListDB[key]` directly, which `profileWrite` mirrors when the active profile matches — the canonical "current effective value" path.
- **Pets summoned mid-session not appearing** — Added `UNIT_PET` to the party unit-watch frame so summoning/dismissing a pet triggers an immediate `updatePartyFrameSize` pass instead of waiting for the next roster change.

---

## [1.8.114]

### Added

- **Pet frames in party/raid layout** — Optional frames for `pet`, `partypet1-4`, and `raidpet1-40`. Pets appear in their owner's subgroup (or group 1 in 5-mans), at the end of the member list. Profile-scoped so party and raid can have different pet visibility.
- New profile key `partyShowPets` (default off). Helper `_EL.partyShowPets()` reads it (profile → global → defaults).
- Config UI: "Show pet frames" toggle in each Party/Raid panel, between *Incoming heals* and *Show mana bar*. Toggling triggers an immediate `updatePartyFrameSize` pass (deferred during combat).
- New locale strings `OPT_PARTY_SHOW_PETS` / `TOOLTIP_OPT_PARTY_SHOW_PETS`.

### Changed

- `partyUnitFrames` always creates pet button slots, so toggling the option no longer requires a `/reload`.
- `updatePartyFrameSize` now skips pet units when the toggle is off, and routes `raidpetN` to the same subgroup as `raidN` (looked up via `GetRaidRosterInfo`).

---

## [1.8.113]

### Fixed

- **Stock nameplate not fully restoring after the list mirror went away** — `squashBarSubtreeForMirror` walked four levels deep into the healthBar / castBar / powerBar / HealthBarsContainer subtrees and `Hide()` + `SetAlpha(0)`'d every frame and every region, but the restore path never touched any of them. Result: even after `persistSuppressPlateUnitFrames(_, false)`, the stock plate showed only name + level — the bars themselves stayed hidden indefinitely. Now records every visited frame's pre-hide `IsShown`/alpha and every region's alpha into `nameplate._elSquashState`, and the suppression-release path restores both.
- All four `squashBarSubtreeForMirror` call sites now pass the nameplate so the state table has somewhere to live.

---

## [1.8.112]

### Added

- **Experimental warning banner** at the top of the Nameplates config section, calling out that nameplate features (threat overlay + list mirror) can interact unexpectedly with Blizzard's stock plates and Plater, and may show visual glitches.
- New locale string `NAMEPLATE_EXPERIMENTAL_WARNING`.

### Changed

- `scrollChild7` height grown by 60px to fit the banner without clipping.

---

## [1.8.111]

### Fixed

- **Runner-up threat bars** now include the current aggro holder. Previously the tank was skipped, so the first bar showed the 2nd-place threat — making it look as though the 2nd-on-aggro was duplicated. Bars now read top-to-bottom: tank (100%), then 2nd, then 3rd, etc. De-duplicates by name so a unit appearing under multiple tokens doesn't show twice.
- **Nameplate name disappearing pre-combat** — `applyDefaultPlateVisualHideToUf` was setting alpha=0 on `uf.name` / `uf.Name` (and other children), but the restore path only put the parent UnitFrame's alpha back. Result: any plate that had ever been mirrored stayed name-less until the addon re-mirrored it, so the user only saw the level. Now the per-child alphas are captured into `nameplate._elChildPrevAlpha` and restored on suppression release.

### Changed

- Preview test data leads the runner-up list with a Tank entry at 100% so the new layout previews correctly.

---

## [1.8.110]

### Added

- **Second-on-threat bar** — One extra bar directly **under your threat bar** on each enemy row showing whoever is **2nd on the full threat list** for that mob (sorted by group `UnitDetailedThreatSituation` percentages). Name left, percent right; color by risk (green / yellow / red). Uses the same vertical size as **runner-up** bars (see Appearance → runner-up height).
- **`EnemyList.GetSecondOnThreatInfo(unit)`** — Returns `{ name, pct, isTanking }` for the second-ranked threat holder, or `nil` if there is no 2nd entry. Uses the same roster cache as threat-rank logic (~0.12s per mob GUID).
- **Option:** *Bar for 2nd on threat (under yours)* (`showSecondOnThreatBar`, default on). Toggle in **Appearance**, between threat bar height and runner-up bars.
- **Test mode / layout preview** — Fake rows can show sample 2nd-on-threat data via `secondOnDemo` on preview threat info.

### Changed

- Row height calculation (`effectiveRowHeight`) accounts for the optional second bar when enabled.
- Config UI build (`CONFIG_UI_BUILD`) bumped to **84** so the options panel rebuilds after an add-on update.

---

## [1.8.109]

### Added

- **Threat list rank** — `EnemyList.GetThreatAnalysis` now enriches results with `threatListRank`, `threatListMemberCount`, and **`isSecondOnThreat`** (player is exactly 2nd in the sorted group roster, and not tanking), using a shared sorted threat roster with short TTL caching.
- **Options (opt-in, default off):**
  - **List:** *2nd on threat in aggressives column* (`listShowSecondInAggroSection`) — puts qualifying mobs in the aggressives column.
  - **Nameplates:** *Second on threat: distinct border color* (`nameplateThreatSecondStyle`) — cyan-style border when you are 2nd on threat and the nameplate threat overlay is enabled.

### Changed

- Threat roster queries refactored to a single **cached sorted roster** per mob GUID, reused for rank, “2nd” detection, and (in 1.8.110) the second-on-threat bar.

---

## [1.8.108]

### Fixed

- **Nameplate list mirror** — Removed duplicate `squashBarSubtreeForMirror` definition; deferred squash after `Show` / `SetShown` now runs on the correct **unit frame(s)** via `getUnitFrameList`, not the bar’s parent.
- **Whole nameplate blinking** — High-frequency `OnUpdate` no longer runs full subtree + region “squash” every tick. **Light** reapply (hide bars + alpha) runs on a ~0.06s cadence; **full squash** runs on a separate ~0.18s maintenance pass to catch redrawn textures without fighting the client.

### Changed

- Squash roots aligned with `partHide` (`ClassPowerBar`, `CastBar`, `secondaryPowerBar`, etc.).

---

## [1.8.107] and earlier (nameplate mirror / threat work)

### Fixed (summary)

- Stock **HP / cast** flicker on mirrored nameplates: hooks on sub-bars (`Show`, `SetAlpha`, `SetShown`) plus subtree squash to catch textures that bypass a single `SetAlpha` on a `StatusBar`.
- **Main list** / layout flicker: coalesced refresh, fade-OOC tick stability, `applyMainLayoutSize` when size unchanged, deferred nameplate mirror refresh.

### Added (summary)

- **Nameplate list mirror** — Optional full enemy-list row on the nameplate (with insets, `SetIgnoreParentAlpha`, threat z-order, cast hysteresis, ToT off on mirror rows, etc.).
- **Nameplate threat overlay** — Optional colored border by threat role and percentage.

---

*For full file-by-file history, use your version control log alongside this file.*
