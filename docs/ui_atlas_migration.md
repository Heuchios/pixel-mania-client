# Shared UI atlas

Updated 2026-09-13.

Panel roles follow the Developer Panel reference: light lavender `outer_panel`
for the enclosing window, dark purple `inner_panel` for headers, lists, and
inset sections. Scene assignments were corrected to follow this convention;
the atlas coordinates and Developer Panel styling were not swapped.

## Source of truth and editing

- `Scripts/UIAtlasDB.gd` owns the named 32px regions, nine-slice margins,
  shared inventory/hotbar selection animation, and rarity tints.
- `Assets/ui/UI_3.0.png` is the artwork source. The catalogue contains 74
  finished regions. Promotional composites lower on the sheet are reference
  artwork, not production card layouts or price labels.
- `tools/ui_atlas_resources.py` generates the editable `.tres` textures/styles
  under `Assets/ui/atlas/`. Run it after moving an atlas region; `--check`
  reports stale generated resources without writing anything.
- Scenes reference shared resources instead of repeating atlas coordinates.
  Layout, icons, and labels remain editable in the Godot Inspector.
- To customize one control, make its style unique first. Runtime callers must
  duplicate a cached style before changing tint/padding. For generated variants,
  update `metadata/atlas_properties` as well, so regeneration retains the change.
- The project uses `Assets/ui/atlas/theme.tres` for default controls. Existing
  explicit scene styles take priority. Runtime-created dialogs use
  `PixelUIStyle`, which now returns atlas styles for visible chrome. Transparent
  shadows, outlines, glows, and other effects may still use `StyleBoxFlat`.

## Completed migration

1. Inventory and hotbar share slot crops, rarity tints, and the same timed
   1-2-3-2-1 selection animation. Inventory upgrades show the purchase overlay.
2. Shared, Inspector-editable textures, state styles, and a fallback theme replace
   repeated coordinates. Input and slot nine-slice margins are explicit.
3. The catalogue includes the existing HUD controls, social/status bubble frames,
   and standalone icons. Distinct illustrations, logos, item art, category icons,
   and unsupported specialty icons remain separate assets intentionally.
4. Scene chrome was migrated across inventory, hotbar, chat, settings, menu,
   login, lobby, leaderboard, trade, emotes, profile, recipe book, locks, vending,
   charging, generator, refinery, and loading UI. Runtime style helpers also
   cover donation, crafting, furnace, fishing, sign, and other generated dialogs.
   Mobile movement/action icons use the atlas; zoom artwork remains separate.
5. The shop manager supplies gem balance to the active detail popup. An
   unaffordable purchase is disabled with a shortfall message while cards stay
   browsable. Gem checkout is not gated by in-game gem balance. Purchase routing
   and server validation remain in the existing shop manager/backend.
6. Shop windows and popups fit smaller viewports. Resize cancels stale open
   animation targets; Escape dismisses the uppermost shop overlay. Authored
   text sizes are preserved during the deferred global typography pass.
7. `Scenes/ui/shop/ShopScene.tscn` is a compatibility instance of the active
   `ShopSceneRedesign.tscn`. Its previous layout is retained in
   `docs/archive/ui/ShopScene.legacy.tscn`, excluded from import by `.gdignore`.
   Old PNGs remain on disk because backups and specialized callers still refer
   to them; unreferenced scene declarations were removed rather than deleting art.

## Verification

Use a Godot 4.7.1 editor build. Supply an absolute writable `--log-file` on this
Windows environment; its default log location caused an engine startup crash.

```text
python tools/ui_atlas_resources.py --check
godot --headless --log-file <log-path> --path . --script tests/ui_atlas_migration_test.gd
godot --headless --log-file <log-path> --path . --script tests/inventory_incremental_refresh_test.gd
godot --headless --log-file <log-path> --path . --script tests/mobile_inventory_layout_test.gd
godot --headless --log-file <log-path> --path . --script tests/vending_ui_external_styles_test.gd
godot --rendering-method gl_compatibility --log-file <log-path> --path . --script tests/ui_atlas_render.gd -- --output=<absolute-directory>
```

The atlas test loads every UI scene, checks generated regions against the sheet,
checks live slot textures, purchase signals/affordability, viewport fitting at
640x360, 1280x720, 1920x1080 and 2400x1080, and touch scrollbar release.
The render harness previews 18 screens without purchasing or sending world
interaction requests. It uses authored preview data, not a live gameplay session.

Physical Android touch/keyboard behavior, real account checkout, and a full
multiplayer gameplay pass are not covered by these local checks. The environment
reports a root certificate-store warning during normal project startup, and the
OpenGL render harness reports resource leaks at shutdown. An unrelated backup
script (`Backups/inventory_manager_claude_code_before_codex_fix_20260530.gd`)
also contains an existing `PANEL_DARKERER` parse error when scanned by the editor.
