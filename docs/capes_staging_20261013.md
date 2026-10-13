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
is the fall pose. Capes add no extra jumps. Neck pieces render in a dedicated
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
