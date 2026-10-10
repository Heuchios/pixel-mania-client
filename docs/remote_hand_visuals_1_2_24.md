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

Physical two-device testing has not been performed. Production deployment and
artifact verification are recorded below after the release completes.
