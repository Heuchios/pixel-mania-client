# Netfox Runtime Disable Safety Report

Created before disabling Netfox from the active PixelMania runtime.

## Goal

Restore the stable WebSocket movement/runtime path as the default and prevent
Netfox from controlling active game movement unless it is launched later as an
explicit archived experiment.

## Netfox-Related Files

- `addons/netfox/**`
- `addons/netfox.extras/**`
- `addons/netfox.internals/**`
- `Scripts/networking/movement_mode.gd`
- `Scripts/networking/netfox_real_manager.gd`
- `Scripts/player/netfox_player_controller.gd`
- `Scripts/player/netfox_player_input.gd`
- `Scripts/player.gd`
- `Scripts/player_manager.gd`
- `Scripts/network_manager.gd`
- `Scripts/save_manager.gd`
- `Scripts/world.gd`
- `Scripts/world_menu_ui.gd`
- `Scripts/world_state_sync_manager.gd`
- `Scripts/login_screen.gd`
- `project.godot`

## Netfox-Related Scenes

- `Scenes/player/netfox_player.tscn`
- `netfox_test/scenes/netfox_test_main.tscn`
- `netfox_test/scenes/netfox_test_player.tscn`
- `netfox_test/scenes/netfox_real_player_test.tscn`
- `netfox_test/scenes/netfox_world_collision_test.tscn`

## Netfox Test Scripts

- `netfox_test/scripts/netfox_test_main.gd`
- `netfox_test/scripts/netfox_test_player.gd`
- `netfox_test/scripts/netfox_test_input.gd`
- `netfox_test/scripts/netfox_real_player_test.gd`
- `netfox_test/scripts/netfox_world_collision_test.gd`

## RollbackSynchronizer Nodes

- `Scenes/player/netfox_player.tscn`
- `netfox_test/scenes/netfox_test_player.tscn`

## TickInterpolator Nodes

- `Scenes/player/netfox_player.tscn`
- `netfox_test/scenes/netfox_test_player.tscn`

## PlayerInput/BaseNetInput Usage

- `Scenes/player/netfox_player.tscn` has `PlayerInput`
- `netfox_test/scenes/netfox_test_player.tscn` has `PlayerInput`
- `Scripts/player/netfox_player_input.gd`
- `netfox_test/scripts/netfox_test_input.gd`
- `addons/netfox.extras/base-net-input.gd`

## Active Runtime Netfox Code Paths

- `MovementMode.Mode.NETFOX_REAL`
- `MovementMode.Mode.NETFOX_TEST`
- `--netfox-real`
- `--server`
- `--client`
- `--phase7-test`
- `--netfox-real-debug`
- `--netfox-player-audit`
- `--netfox-correction-debug`
- `--netfox-collision-debug`
- `--netfox-identity-debug`
- `--netfox-server-token`
- `NETFOX_REAL_DEBUG`
- `NETFOX_PLAYER_AUDIT`
- `NETFOX_CORRECTION_DEBUG`
- `NETFOX_COLLISION_DEBUG`
- `NETFOX_IDENTITY_DEBUG`
- `NETFOX_SERVER_PLAYER`
- `PIXELMANIA_NETFOX_SERVER_TOKEN`

## Dev Login/Test Bypasses Added For Netfox Testing

- Godot client flags:
  - `--backend-dev-login`
  - `--dev-test-login`
  - `--dev-profile`
  - `--world NETFOX_TEST`
- Godot client environment gates:
  - `ENVIRONMENT=development`
  - `PIXELMANIA_ALLOW_DEV_LOGIN=true`
- Backend flags/environment:
  - `PIXELMANIA_ENABLE_DEV_BACKEND_LOGIN`
  - `PIXELMANIA_ALLOW_DEV_LOGIN`

## Backend Dev/Netfox Endpoints

- WebSocket message: `dev_backend_login`
- HTTP endpoint: `/dev/netfox/world-state`
- HTTP endpoint: `/netfox/server/world-state`

## Preservation Decision

No useful Netfox scenes, scripts, or addons are deleted by this cleanup. They are
kept as archived/reference experiment code. Runtime activation is disabled by
default and should require an explicit archived test opt-in before any Netfox
server, rollback synchronizer, tick interpolator, or Netfox input path can run.

## Disable Notes

- Netfox autoload singletons were removed from active `project.godot` startup.
- Netfox editor plugins were disabled in `project.godot`.
- `--netfox-real`, `--phase7-test`, and Netfox test-scene mode changes no longer
  switch the active game out of WebSocket mode by default.
- Archived Netfox experiments require `--netfox-archive-test`,
  `OS.is_debug_build()`, `ENVIRONMENT=development` or `NODE_ENV=development`,
  and `PIXELMANIA_ALLOW_DEV_TOOLS=true`.
- Backend Netfox world-state endpoints require development tools plus
  `PIXELMANIA_ENABLE_NETFOX_ARCHIVE=true`.
- Backend dev login remains a locked development tool only and is not part of
  normal runtime authentication.
- The isolated custom movement test is launched through
  `res://custom_movement_test/scenes/custom_movement_test_main.tscn` with
  `--server` or `--client`. `MovementMode.should_run_websocket_backend()` now
  returns `false` for that scene path or `--custom-movement-test`, so the
  normal backend/WebSocket autoload does not connect during the sandbox test.

## Archived/Kept Netfox Files

The following remain in the repository as archived/reference material only:

- `addons/netfox/**`
- `addons/netfox.extras/**`
- `addons/netfox.internals/**`
- `netfox_test/**`
- `Scenes/player/netfox_player.tscn`
- `Scripts/networking/netfox_real_manager.gd`
- `Scripts/player/netfox_player_controller.gd`
- `Scripts/player/netfox_player_input.gd`

They are not deleted in this cleanup. Normal launch stays on the WebSocket
movement path, and archived Netfox paths require the explicit archive gates
listed above.
