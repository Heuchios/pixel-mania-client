# Standing at block edges

The rectangular player collider could retain floor contact with only a fraction
of a pixel over a block. Gravity then returned early because `is_on_floor()` was
still true, allowing a player to balance outside the block indefinitely.

Before movement decisions, `player_floor_support.gd` measures the union of actual
support beneath the collider. Less than three world pixels is an unsupported
overhang. A small clearance through `move_and_collide()` releases that corner,
then a zero-motion slide refreshes the floor flag. Normal gravity resumes in the
same movement step. Horizontal/falling velocity, air-jump usage and coyote-jump
grace are preserved. Clearance is bounded to the small unsupported sliver and
cannot pass through adjacent walls.

The check uses block collision rectangles and physical collider anchors, so it
handles custom shapes, wide machines, block nodes, TileMapLayer terrain and
one-way platforms. Neighboring tiles contribute continuous support across seams.
Slopes, nonrectangular actors, unknown floors and fully supported narrow custom
platforms retain native behavior. Jumping/rebounding actors are not moved.

Validation: mirrored tiny overhangs and stable edge landings; tile seams;
one-way platforms; offset narrow and multi-tile colliders; the full movement
step and coyote grace; wall clearance; slopes and unknown floors; actual
TileMapLayer collision. The existing corner regression still verifies 504
mirrored airborne approaches without injected horizontal motion. Developer
noclip/visibility movement tests also pass.
