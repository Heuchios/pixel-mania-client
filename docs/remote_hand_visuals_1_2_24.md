# Remote hand-item visuals — 1.2.24

Remote PlayerVisual nodes were cloned from the observing player's live rig,
including its runtime SwordSlashTrail. Remote equipment then created another
trail, while animation lookups still addressed the inherited node. This left
the actual remote weapon's trail idle and could give another player an effect
belonging to the observer's weapon. The clone now excludes actor-bound runtime
trails; each remote equipment manager creates and owns its own effect.

Most free-swing particles were only emitted locally. Free swings now carry a
sequence and bounded aim offset in normal movement presence. The server stamps
the tool from validated equipment and facing from accepted movement, ignoring
client-provided identities or tool names. Stationary swings change the presence
signature. Existing block-hit delivery reuses the same effect routing without
generating an additional free-swing event. Player-targeted swings now use the
same general hand-effect path. This remains cosmetic and grants no damage,
inventory, movement, or economy authority.

Observers establish a baseline on join, consume hidden events without replay,
and deduplicate repeated snapshots. The first new swing from a player with no
previous event is visible. Existing sustained water jets remain one per actor.
Both players need 1.2.24 for the complete fix. Legacy clients remain compatible.

## Regression coverage

- The initial real-rig test reproduced ten failed assertions before the fix.
- Expanded test passes 189 checks across 13 hand items: independent remote
  rigs and trails, artwork playback, local movement payloads, first/subsequent
  swings, initial/hidden/duplicate snapshots, water-jet refresh and switching.
- Existing sword trails, Void Trident, Neptune water jets, Serpent Staff,
  Battleaxe, Angelic Sword, Phoenix Sword and Wizard Staff regressions pass.
- Remote equipment performance, fishing visuals and partial player state pass.
- Backend route/presence checks cover stationary events, authoritative tool and
  facing, malformed/non-finite/out-of-range inputs, rejected movement and joins.

Full backend `npm run check:security` passed, including type checks, security,
deployment and dependency gates. A rendered synthetic remote-player scene was
visually inspected for Neptune Trident, Serpent Staff, Void Trident, Phoenix
Sword, Fire Staff and Blood Battleaxe. Physical two-device testing has not
been performed.

## Verified production release

Released 2026-10-09 local / 2026-10-10 UTC. Client build source `4577519` and
backend `33256ff` shipped as `20261010-hand-visuals-33256ff`. Rollback target:
`20261010-fishing-5a59e28`.

- Main port 8080 and routes 18091/18092 report 1.2.24 and ready PostgreSQL/Redis.
- Post-deploy smoke checks and deployed route/presence regressions pass.
- The actual packaged Windows client starts with normal rendering and connects
  to production without script/resource errors.
- Public manifest checksum matches the Windows ZIP; the real launcher
  downloaded, verified and installed 1.2.24.
- Android APK/AAB signatures are verified, code 46, non-debuggable APK, same
  signing certificate as 1.2.23. Temporary export credentials were removed.
  These Android builds have not been uploaded to Google Play.
- Global minimum remains 1.2.14, desktop minimum 1.2.21; Android publication
  policy is unchanged. All prior production content/fixes are included.

Artifacts, logs, preview and exact checksums are in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.24/`.

| Artifact | SHA-256 |
| --- | --- |
| Windows ZIP | `8e7d8c7da8bc043e52a33a110917f7a207a3102dccd718d9530a27a6b5f8ccab` |
| Android APK | `9d2a02844a53bb8ee69757a8692d9f3f7bf8d950884a9c7bcc63c118eb126c55` |
| Android AAB | `0c47a30c8794b78549f3a3bacba2d6491b5f295e737815f96e9c3d13cce23140` |

Unrelated local wearable/temporary work was excluded. No GitHub push was made.
