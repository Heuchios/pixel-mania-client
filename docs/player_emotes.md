# Player emotes

The emote dropdown offers Wave, Laugh, Sad and Dance. Chat accepts `/wave`,
`/lol`, `/sad` and `/dance` for every player; `/lol` uses the existing `laugh`
network ID. Commands and the dropdown share the gameplay controller and its
one-second cooldown. `/help` lists the commands.

Dance loops its 1.6-second cycle until interrupted, with no time limit. It moves both arms, both feet,
hips, torso and head. Clothing follows its body-part parent, the held item
follows the right arm, and the back slot follows the torso. Movement, actions,
damage and death cancel the gesture and restore the prior pose. Opening a menu
or going offscreen keeps an idle dance running; leaving the world clears it.
Gameplay position and collision are unchanged.

## Editing in Godot

Select `Player/EmoteAnimationPlayer` in `Scenes/main.tscn`, or
`EmoteAnimationPlayer` in `Scenes/player/netfox_player.tscn`, then select `dance`.
Both use `Assets/player/animations/dance.tres`, an AnimationLibrary with 18
position/rotation tracks and a RESET animation. Runtime playback samples the
animation after locomotion and blends its start against the saved pose.

Run `Scenes/debug/player_emotes_preview.tscn` to preview all four emotes and
the real dropdown. Remote avatars use the same animation. Creating a remote
avatar during a local gesture restores the copied rig's saved pose first.

## Verification and release status

Implemented locally on 2026-10-11; not deployed. The client and backend changes
must ship together for other players to receive Dance. The backend allowlist
in `src/server_phase9_remaining_routes.ts` and its generated JavaScript now
accept `dance`, retaining authentication, world membership and cooldown checks.

Focused checks passed with Godot 4.7.1:

- `tests/player_emotes_test.gd`: all commands, menu, faces, remote events,
  cooldowns, an hour of simulated continuous dancing, local/remote punch and
  damage interruption, offscreen behavior and mobile menu bounds.
- `tests/player_dance_rig_test.gd`: 168 checks covering the actual dressed rig,
  both directions, attachments, remote spawning and repeated cancellation;
  renders `previews/player_dance_rig.png` with a rendering backend.
- `tests/player_emotes_render_test.gd`: renders the actual dropdown and avatars.
- `tests/walk_cycle_test.gd` and `tests/world_honors_commands_test.gd`.
- `tests/remote_hand_item_visuals_test.gd`: 189 checks, zero failures.
- Backend: `npm run check:server-phase9-remaining-routes` and
  `node scripts/test_player_emotes.js`.

Sandbox runs also emit existing certificate-store/shader-cache warnings;
scene-based tests retain the existing image UID fallback and exit-time resource
warning. No live two-client session or deployment was performed.
