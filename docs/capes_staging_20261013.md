# Hero and vampire capes

Five instance-tracked items use the existing back equipment slot:

| Item | ID | Preview | Neck | Six 64×64 frames |
| --- | --- | --- | --- | --- |
| Black Hero Cape | `black_hero_cape` | 0,25 | 0,26 | 1/3/5/7/9/11,25 |
| Red Hero Cape | `red_hero_cape` | 0,27 | 0,28 | 1/3/5/7/9/11,27 |
| Blue Hero Cape | `blue_hero_cape` | 0,29 | 0,30 | 1/3/5/7/9/11,29 |
| Vampire Cape | `vampire_cape` | 0,31 | 0,32 | 1/3/5/7/9/11,31 |
| Dracula Cape | `dracula_cape` | 0,33 | 0,34 | 1/3/5/7/9/11,33 |

Coordinates above reference the user's `back_item.png` atlas. The requested area
was copied without resizing or trimming into `Assets/items/capes.png` (416×320),
preserving canvases and subtracting 25 from atlas rows in runtime aliases. This
keeps other pending edits to the original atlas out of the cape commit.

Frames 1–4 loop at 6 FPS for idle/walking, frame 5 is the jump pose, and frame 6
is the fall pose. Capes grant double jump (one ground jump and one air jump). Neck pieces render in a dedicated
`Body/CapeNeckAnimated` child above shirt art, independent of necklaces. Removing
or swapping a cape hides its collar and removes its FX, for local and remote
players using the shared equipment manager.

Vampire Cape emits small dark-purple pixel bats; Dracula Cape emits red bats.
The shared effect has a bounded pool of 16 bats, fewer while idle, and never
changes the cape pose. Scene files expose the two colors for editor adjustment.

Items are grantable, tradeable, vendable and dropable through existing durable
PostgreSQL ownership/transaction paths. No new shop listing or acquisition odds
are introduced.

Validation: `check_capes.js`, full backend `check:security`, rendered
`capes_test.gd` (all poses, both facings, icons, collars, coexistence, cleanup and
both bat colors), wing atlas migration, helmet layering and remote equipment
performance checks. Render: `D:/Pixelmania/work/capes-preview.png`.

## Initial verified deployment

Staging runs `20261013-capes-atlas`, backend
`d591f0c79ad6b8fe3ccfca4cac40304e9c264fa0` and client metadata
`ab597707f2d8b2d92df1fd267b68f6040eebbcfa`. Runtime item registration commit is
`e7607b8cbb244a76712b2c9dac64d46c13035bb4`; the subsequent backend commit includes
wearable atlas metadata in the immutable validation package. The full security
gate passed for the cape runtime, and release packaging checks pass for the final
archive. The deployed `check_capes.js` passes, including every atlas region.
Public deployment smoke checks pass; PostgreSQL authoritative/ready and Redis
ready. Client version and minimum remain 1.2.25.

Rollback is `20261013-capes-e7607b8` (same cape runtime, without the additional
validation manifest); the pre-cape release is `20261012-recipes-5a11f5f`.
Production was not deployed and published client binaries were not replaced.
Restart the updated Godot editor/debug client to use the new cape artwork and FX.

## Shoulder alignment and double-jump correction

The first release inherited the wing sprite's centered anchor. Opaque cape pixels
started above the shoulders, and the separately centered 32×32 collar sat inside
the head. The corrected item data applies a 13px downward offset from the editor
back anchor and a 7px collar offset. Lifted Vampire/Dracula fall artwork has
separate offsets (8px/16px) to keep its attachment at the collar. Full atlas
canvases and all six authored frames are preserved. Swapping to wings restores
their editor anchor; rebinding the same player cannot accumulate offsets.

All five items specify `jump_type = double` in both catalogs. The real player
ability lookup and inherited jump gate are tested for two accepted jumps and
rejection of a third. Rendered checks compare the opaque Black Hero Cape and
collar start to the body's actual shoulder line, then cover all five capes,
both facings and all poses, rebind, swap, and unequip. Existing wing atlas,
repeated wing jump and remote equipment performance regressions pass. Full
backend security and the updated cape registration check pass.

Collars use two complementary halves. The atlas-left half has relative Z 15
under Body (30), giving player-relative Z 45 above Head (40). The atlas-right
half has relative Z 3 (effective 33) behind the face. A shader clips each
centered 32×32 canvas at its midpoint without changing or trimming the artwork.
Both halves inherit player mirroring, share the same attachment offset, and
hide together when the cape is removed. Player rebinds retain the two layers.
The cape body stays behind the player.

`cape_collar_render_test.gd` checks actual pixels for all five collars and both
facings against an opaque face: zero mismatches; deliberately reversing the
front half produces 242 wrong pixels. Cape equip/swap/rebind checks also pass.

Earlier correction release: `20261013-cape-collars`, backend
`bddbbab6b622aa9efbb66116b4991ef3ba6160ee`, client
`ff89e78bcd690bce4afa6994d504f58d64447cd8`. The deployed cape registration
check and public smoke/health checks pass; PostgreSQL and Redis are ready.
Client/minimum version remains 1.2.25. Rollback is
`20261013-cape-alignment-bddbbab` (correct alignment/double jump, earlier collar
layer). Restart the updated editor/debug client for the collar rendering change.

## Video reference alignment

The user supplied `preview_animation2.mp4` as the placement reference. Its eight
seconds show the Dracula and Vampire idle animations. Frames were decoded at
native resolution and aligned to the game's unchanged head pixels, avoiding
screen zoom differences. The collar needed a further 2px right / 1px down shift;
the cape body needed 1px left / 1px up. These adjustments apply consistently to
all five capes and preserve the full source canvases, mirrored front/rear collar
halves, double jump, and the authored jump/fall poses.

The final collar offset is `[2, 8]` from the necklace editor anchor. The default
back offset is `[-1, 12]`; hero fall uses the same offset, Vampire fall uses
`[-1, 7]`, and Dracula fall uses `[-1, 15]`. The video does not show airborne
movement, so jump/fall retain their prior attachment relationship with the same
one-pixel body correction. Rendered lifecycle and pose checks cover all five
capes in both directions; the source atlas remains unchanged.

Split-collar release `20261013-collar-halves` was verified live with client
`3d58c513a4985823deb16388beeeefec5a84fe26` and backend `bddbbab6b622` before this
video adjustment. Its registration and smoke checks pass; PostgreSQL and Redis
are ready, and client/minimum version remains 1.2.25.
