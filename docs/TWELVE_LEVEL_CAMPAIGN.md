# Twelve-level campaign expansion

The original six maps and their 12/12/14/14/16/16 wave counts are preserved. Six additional authored maps extend the campaign to 18/18/20/20/22/22 waves. All remain freely selectable; the final map's Next action wraps to the first map.

## New maps

| Map | Waves / gold | Routes and tactical identity |
|---|---:|---|
| 07 苔湾长堤 | 18 / 700 | One 69-unit sea-wall switchback; regeneration and splitters; frost helps fire/area towers control a crowd |
| 08 金砂折塔 | 18 / 730 | Two gated vertical comb routes, 72/42 units; shield/armor escort pressure rewards covering several columns |
| 09 潮汐三洲 | 20 / 770 | Three alternating coastal entries, 57/69/45 units; fast runners and splitters pressure separate approach lanes |
| 10 赤铜盘山 | 20 / 800 | A 94.5-unit inward spiral ending inside the island; shield/healer/armor groups favor repeated central engagement |
| 11 月杉双环 | 22 / 840 | Two gated ring approaches, 57/48 units, ending at the western forest core; armored splitters and frost |
| 12 星陨终阵 | 22 / 900 | Four alternating routes, 63/66/54/75 units, mixing perimeter and central approaches; full mixed-unit finale |

Each new map has 16 valid build pads, a different route set, a named environment and a map-specific formation (eight units, or sixteen for the finale). Early waves introduce normal/runners/armor before map formations begin in wave 4. Every final wave ends with the mother bug. Each late formation contains armor, shields, regeneration and splitters; frost/lava and gate switching retain their existing mechanics.

## Economy and progression

No extra resource grants, free upgrades or scripted enemy removal are used. The existing capped between-wave supply, tower prices, upgrades, kill rewards and abilities are unchanged. Initial gold scales from 700 to 900 as the number of simultaneous approach lanes and opening enemy count rise.

For maps 7–12 only, enemy effective HP strength grows by 0.5 per wave from waves 7–12 and 0.2 per wave after wave 12. This prevents late regeneration/HP scaling from outgrowing a fully upgraded 16-pad board while wave counts, formations and spawn pressure still increase. After wave 12, new maps add one enemy per wave rather than two; their entrance-pressure bonus rises by one enemy per map. New-map spawn intervals tighten gradually to a 0.58-second floor rather than the original 0.38-second floor, preventing support formations from becoming an unbreakable continuously healing cluster. These longer waves remain bounded by the same 16-pad upgrade ceiling. Original map and custom-map HP formulas are untouched.

The selector is a scrollable grid with three columns on desktop and two on mobile. Every card displays wave count and initial gold. Gate notifications consistently use A/B rather than assuming compass positions.

## Reproduction and scope

Run Godot 4.6.3 headlessly from the project directory, with XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME pointed at writable directories:

- `godot --headless --path . --script tests/extra_levels_geometry.gd`
- `godot --headless --path . --script tests/extra_levels_balance.gd`
- `godot --headless --path . --script tests/integration.gd`
- `godot --headless --path . --script tests/thumbnail_ui.gd`

The expanded balance test runs actual main-scene combat, building/upgrading from earned money between waves, using Q and switching available gates. On map 11, the tested late defense chooses entrance B to route enemies through its upgraded inner-ring crossfire instead of continuing to alternate blindly. It checks defended wins and undefended losses for maps 4–12 and writes per-wave resources, health, kills, tower counts, ability use and placements to `tests/extra-level-balance-results.json`. Integration retains original six-map combat coverage and expands progression/restart/boss assertions to all twelve maps. UI tests check scroll access to map 12, model survival through all map rebuilds, repeated selector reopening, final-level redeployment and 12-to-1 wraparound.

These are headless gameplay and logical layout checks, not a claim of screenshot, physical-touch-device or platform-export QA. No workflow/export configuration or custom editor feature is changed by this expansion.

## Final campaign evidence

- Geometry: 3,231 checks passed, including route bounds/grid alignment, unique entrances, shared goals, no self-crossing, pad clearance and hazard-road coverage
- Actual-combat balance: 196 checks passed; all maps 4–12 win with normal earned-money defense and lose undefended
- Defended remaining HP on maps 7–12: 20, 20, 20, 20, 20, 11 (out of 20)
- Per-wave machine-readable evidence: `tests/extra-level-balance-results.json`; complete logs: `tests/reports/twelve_final_extra_levels_balance.log` and `twelve_final_extra_levels_geometry.log`

## Combined-source regression

Final sequential checks also pass: integration 276, selector/thumbnails 67, UI integration 189, designer validation 20, designer integration 35, author replay 18, settings 25, camera 20, responsive desktop/mobile 101 each, and tower drag desktop/mobile 18 each. These include the separately implemented responsive and drag work, not campaign-only code.

The designer integration test originally hard-coded six maps; it was updated to twelve. Its first rerun refused the reused test data directory as designed; a fresh disposable XDG directory produced the final 35/35 pass. The raw exit-code history retains those attempts; `twelve_final_summary.json` records final verified outcomes.
