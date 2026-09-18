# Startup warning cleanup — September 18, 2026

## Changes

- Renamed electrical-control locals and parameters that shadowed `Object.disconnect`, `Node2D.position`, and the `endpoint_type()` helper. Network payload field names remain unchanged.
- Removed the unused menu action lookup and its unused index argument.
- Marked the shared style helpers' legacy size parameters as intentionally unused. The established global typography policy still controls sizes.
- Configured `login.wav` to import with a full-length forward loop and rebuilt it. Godot's importer uses **2** for Forward; the runtime `AudioStreamWAV` enum uses **1**. The old Detect setting produced no loop bounds because the WAV has no embedded loop markers. Retained runtime recovery for genuinely invalid assets.
- Changed the `main.tscn` reference to `image.png` to use its resource path directly, avoiding the unresolved UID fallback. Verified scene loading.
- Retained seed-tree rarity textures across warmup calls. Previously the warmup repeatedly loaded and released the same few textures.
- Limited wearable-manifest filesystem checks to once per second in editor builds and once per process in packaged builds.
- Added named item-database, core-manager, seed-system, and inventory timing stages. Loading-state records now identify the actual state instead of all saying `client_loading_stage`.

## Validation

Passed offline checks, with the WebSocket backend disabled:

- `script_warning_regression_test.gd`: recompiles all changed runtime scripts with the reported unused/shadowing warning categories treated as errors.
- `startup_resource_cache_test.gd`: verifies baked music loop bounds, main-scene loading, retained rarity textures, and bounded manifest checks.
- `electric_flow_test.gd`.
- `global_typography_test.gd`.
- `world_loading_operation_id_test.gd`.

Updated two stale test expectations: headers require an explicit role when their names do not identify them as headers, and the reveal fade must remain at most 100 ms rather than exactly the historical 340 ms.

## Loading measurement and limits

The user's local log recorded a 2,258 ms join with a 628 ms setup interval. An offline probe using the real scene and completed resource preloading measured synchronous world setup at **464 ms before** and **219 ms after** the cache fixes. Seed setup fell from **167 ms to 13 ms** and item-database setup from **85 ms to 22 ms**. These are individual local observations, not an end-to-end production benchmark.

The threaded headless timing probe reports a Godot dummy-renderer texture initialization error and resource-retention warnings on exit both before and after the changes. The focused correctness checks above pass without those errors. The timing numbers measure CPU setup only; they do not verify rendering or network latency.

The one-second join warning remains enabled with its original threshold. A live join can still exceed that target due to snapshot transfer, world building, or frame stalls. A fresh live join is needed to establish the total improvement.

Changes are saved locally; this task did not commit, export, or deploy them.
