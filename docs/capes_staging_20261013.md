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

## Verified deployment

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

Collars draw in front of the face: their relative Z is 15 under Body (30),
giving effective player-relative Z 45 above Head (40). This is applied when
creating and refreshing the collar, including player rebinds. The cape body
stays behind the player. Rendered tests verify the actual collar/head ordering
for all five capes and both facing directions.
