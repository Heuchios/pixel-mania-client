# Character expression atlas

`emotes.png` is an unchanged copy of the supplied 512 × 256 reference sheet.
Both `Scenes/main.tscn` and `Scenes/player/netfox_player.tscn` use the shared
`face_expressions.tres` and `dead_spirit.tres` resources. Normal remote players
inherit the same resources through the shared visual pipeline.

Open `Scenes/debug/emote_atlas_preview.tscn` in Godot and press **F6** for live
previews beside the source sheet. **F** mirrors the previews; **Space** pauses.
Select a frame in either SpriteFrames resource to inspect its AtlasTexture region.

| Frame | Atlas region (x, y, width, height) | Bottom margin |
| --- | --- | --- |
| Idle | 64, 39, 32, 25 | 7 |
| Blink | 96, 40, 32, 24 | 8 |
| Jump | 96, 7, 32, 25 | 7 |
| Fall | 128, 7, 32, 25 | 7 |
| Punch / angry | 128, 39, 32, 25 | 7 |
| Hurt | 160, 7, 32, 25 | 7 |
| Dead | 192, 7, 32, 25 | 7 |
| Talk 1 | 160, 39, 32, 25 | 7 |
| Talk 2 | 192, 39, 32, 25 | 7 |
| Swim / underwater | 224, 39, 32, 25 | 7 |
| Wave / laugh smile | 160, 71, 32, 25 | 7 |
| Laugh 2 | 192, 71, 32, 25 | 7 |
| Laugh 3 | 224, 71, 32, 25 | 7 |
| Sad | 64, 71, 32, 25 | 7 |
| Spirit 1 | 256, 160, 32, 32 | 0 |
| Spirit 2 | 288, 160, 32, 32 | 0 |
| Spirit 3 | 320, 160, 32, 32 | 0 |

The face regions remove the sheet's top padding. AtlasTexture margins restore
the original 32 × 32 canvas without changing character or equipment positions.
All spirit frames now use the same 32 × 32 canvas (the old second PNG was 32 × 31).
Nearest-neighbor filtering and lossless import preserve the pixel art.

Idle holds for 3.5 seconds and blinks for 0.14 seconds. Talk switches frames every
0.16 seconds; the three spirit frames run at 6 fps. `angry` aliases `punch`, and
`swim` aliases `underwater`. The existing movement, damage, death, water and chat
triggers choose expressions.

The smile button beneath the right-hand chat button opens Wave, Laugh and Sad.
These use the third-row examples in the sheet. Wave swings the near arm forward for
2.4 seconds; Laugh cycles the three selected smiling faces at 0.22 seconds each
with a head/body bounce for 2.6 seconds. The bounce runs at 4.5 rises per second,
25% slower than the original, with the same 2px/1px height.
Sad lowers the head for 3 seconds. The waving arm's sleeve and
held item follow the shoulder rotation. Movement, actions, damage,
death or leaving the world cancel the gesture. Equipped parts follow their
existing parent nodes and their original transforms are restored afterward.

`Scenes/debug/player_emotes_preview.tscn` is an interactive F6 preview with the
actual dropdown, assembled avatars and the atlas reference. The menu follows
the shared mobile scale and stays inside the viewport.

`player_emote` WebSocket events carry an allowlisted ID and current world. The
server checks authentication and world membership, supplies the sender identity
and sequence, and broadcasts only to that world. The sender plays immediately
and ignores its echo; other clients discard repeated sequences. Both WebSocket
and Netfox visuals use the shared gesture helper. This is ephemeral visual state,
with the standard Redis-backed message limiter and a one-second gesture cooldown.
The matching backend changes must be deployed for other players to see emotes.

Regression checks: `tests/face_expression_atlas_test.gd` checks pixels, timing,
scene wiring and normal/alternate-controller state transitions.
`tests/face_expression_atlas_render_test.gd` requires a rendering driver and
compares atlas draws with the original aligned sprites in both directions.
`tests/player_emotes_test.gd` checks gestures, reset/cancellation, packet routing,
duplicate suppression, dropdown input and desktop/mobile layout.
`tests/player_emotes_render_test.gd` renders the assembled preview.
Backend: `node scripts/test_player_emotes.js` plus the phase7/phase9 build checks.

Chat typing uses `Scenes/player/chat_typing_indicator.tscn`: UI_3.0.png cells
`(7, 2)`, `(8, 2)`, `(9, 2)` on its 32px grid, looping at 3 fps. The 16px bubble
is attached to `PlayerVisual/Head` at `(18, -16)` and mirrors with the player.
Both main chat and quick chat require a focused, visible, nonempty input edited
within the last 2.2 seconds. Sending, clearing, losing focus, hiding chat, death
or leaving the world stops the indicator. Other text fields cannot trigger it.
The existing WebSocket `chat_typing` movement field carries this same state;
typing transitions trigger a rate-limited update even when standing still.
No additional backend route is needed. Local Netfox visuals share the indicator;
remote Netfox typing is not carried by its existing movement protocol.

`Scenes/debug/chat_typing_preview.tscn` provides an offline F6 preview with both
facing directions and main/quick input fields. `tests/chat_typing_indicator_test.gd`
checks the chat lifecycle, local/remote visuals, exact atlas cells and network
payload. `tests/chat_typing_render_test.gd` renders the assembled preview.
