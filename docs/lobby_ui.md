# Lobby UI

The live lobby is `Scenes/ui/lobby/LobbyScene.tscn`, driven by
`Scripts/ui/lobby_scene.gd`. Its compact panel, icon tabs, and world rows follow
the supplied lobby reference. Atlas coordinates use the 32px grid in
`Assets/ui/UI_3.0.png`; named regions live in `Scripts/UIAtlasDB.gd`.

| Control | Atlas cells | Behavior |
| --- | --- | --- |
| Row entry | (22,2), (23,2), (24,2) | Cycles while hovered or keyboard-focused; joins that row's world |
| Favorite | (0,8) on, (1,8) off | Saves the existing local profile favorite list |
| World of the Week | (0,5) | Placeholder until a weekly world is configured |
| PixelMania worlds | (1,5) | START currently; configured official worlds remain listed at zero population |
| Active worlds | (2,5) | Existing population feed, with START retained as the hub |
| Owned worlds | (4,5) | Existing server-owned-world feed |
| History | (5,5) | Existing recent-world list, newest first |
| Favorites tab | (0,8) | Retains access to saved favorites |
| Landfill logo | (0,9), (2,9), (4,9), (6,9) | Four 64px frames; clicking requests event entry through the existing server route |

The supplied third landfill coordinate `(3,9)` intersects two images in the
current sheet. `(4,9)` is the complete third frame, so it is used here.
The event card remains gated by the server's active-event status.

The scene root exposes **Lobby World Directory** properties in the Inspector:
`official_world_names` currently contains `START`; add future official world
names to that array. `world_of_the_week` is intentionally empty until the weekly
selection feature is ready. Neither tab invents worlds from population rankings.

Local verification:

```text
godot --headless --path . --log-file <absolute-path> --script tests/lobby_ui_test.gd
godot --headless --path . --log-file <absolute-path> --script tests/lobby_start_world_entry_test.gd
```

The UI fixture tests signals, filters, atlas animation frames, and favorite
state without entering worlds or changing the real profile. Live authenticated
multiplayer entry is not covered by these tests.
