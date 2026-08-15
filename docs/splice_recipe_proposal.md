# Seed splicing recipe proposal

**Status: design only. Nothing here is wired into the game.** No code, item, or server
changes have been made. This is a proposal to review and cut before anything ships.

Adding these later is a pure data change: entries in `SPLICE_RECIPES`
(`item_database.gd:8114`) plus matching `TIER_1_SPLICE_BALANCE` entries for grow times and
drop rates. No new art, no new blocks, no server item entries — every result below is a
block that **already exists** in `ITEMS` and already carries a seed id.

- **Existing recipes:** 26
- **Proposed:** 46
- **Total:** 72

---

## The design grammar

Rather than 46 arbitrary pairs, the set follows five rules a player can actually learn and
predict. That is the difference between a recipe list and a crafting *system*.

| agent seed | role | example |
|---|---|---|
| `pile_of_sand_seed` | **pigment carrier** — natural colour + sand = coloured block | `pile_of_sand` + `rose` = red_block |
| `white_block_seed` | **lightener** — makes the pastel/light variant | `red_block` + `white_block` = red_pastel_block |
| `black_block_seed` | **darkener** — makes the dark variant | `red_block` + `black_block` = dark_red_block |
| `cave_background_seed` | **background-ifier** — turns a solid into its wall version | `red_brick` + `cave_background` = red_brick_wall |
| `gem_block_seed` | **gem base** — colour decides which ore | `gem_block` + `red_block` = ruby_block |

Two consequences worth calling out, because they are deliberate:

1. **Colour mixing is real.** `red + yellow = orange`, `blue + red = purple`,
   `blue + green = aqua`. Players who know colour theory can guess these without a wiki.
2. **There is no natural blue in the game.** Nothing in your block palette is blue, so blue
   has to come from ice, and ice from glass. That makes blue the deepest primary — and
   everything downstream of it (purple, aqua, and their dark/pastel variants, plus
   amethyst) inherits that depth. This is the single biggest balance lever in the set; see
   the open questions at the end.

---

## Tier map

Tier = steps from a base seed. Your existing tree reaches tier 4; this extends it to 6.

| tier | existing | proposed | grow time suggestion |
|---|---|---|---|
| 1 | glass, pile_of_sand, rose, sign, stone_brick, sun_flower, tulip, vines, wood_plank, wood_platform | — | 24s (current) |
| 2 | apple, climbing_vine, gem_block, glass_panel, lily, mushroom, poppy, sand_castle, vines_2, wooden_background, wooden_block, wooden_entrance, wooden_ladder | 9 neutrals + pigments | 45s |
| 3 | wooden_door, wooden_fence | 22 | 90s |
| 4 | wooden_frame | 6 | 180s |
| 5 | — | 5 | 300s |
| 6 | — | 4 | 600s |

Grow times are a suggestion for the `TIER_1_SPLICE_BALANCE` entries, matching the existing
24s→600s ladder. Not part of the recipe data itself.

---

## The recipes

### Neutrals — the modifier seeds everything else needs

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 2 | `glass` + `pile_of_sand` | **white_block** | `"glass_seed+pile_of_sand_seed": "white_block_seed"` | 45s |
| 2 | `cave_background` + `pile_of_sand` | **black_block** | `"cave_background_seed+pile_of_sand_seed": "black_block_seed"` | 45s |
| 2 | `pile_of_sand` + `stone` | **grey_block** | `"pile_of_sand_seed+stone_seed": "grey_block_seed"` | 45s |
| 2 | `dirt` + `pile_of_sand` | **brown_block** | `"dirt_seed+pile_of_sand_seed": "brown_block_seed"` | 45s |

### Natural pigments

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 2 | `pile_of_sand` + `rose` | **red_block** | `"pile_of_sand_seed+rose_seed": "red_block_seed"` | 45s |
| 2 | `pile_of_sand` + `sun_flower` | **yellow_block** | `"pile_of_sand_seed+sun_flower_seed": "yellow_block_seed"` | 45s |
| 2 | `pile_of_sand` + `tulip` | **pink_block** | `"pile_of_sand_seed+tulip_seed": "pink_block_seed"` | 45s |
| 2 | `pile_of_sand` + `vines` | **green_block** | `"pile_of_sand_seed+vines_seed": "green_block_seed"` | 45s |

### Cold chain — the only route to blue

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `glass` + `white_block` | **ice_block** | `"glass_seed+white_block_seed": "ice_block_seed"` | 90s |
| 4 | `ice_block` + `pile_of_sand` | **blue_block** | `"ice_block_seed+pile_of_sand_seed": "blue_block_seed"` | 180s |

### Colour mixing

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `red_block` + `yellow_block` | **orange_block** | `"red_block_seed+yellow_block_seed": "orange_block_seed"` | 90s |
| 5 | `blue_block` + `red_block` | **purple_block** | `"blue_block_seed+red_block_seed": "purple_block_seed"` | 300s |
| 5 | `blue_block` + `green_block` | **aqua_block** | `"blue_block_seed+green_block_seed": "aqua_block_seed"` | 300s |

### Dark variants — colour + black_block

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `black_block` + `red_block` | **dark_red_block** | `"black_block_seed+red_block_seed": "dark_red_block_seed"` | 90s |
| 3 | `black_block` + `yellow_block` | **dark_yellow_block** | `"black_block_seed+yellow_block_seed": "dark_yellow_block_seed"` | 90s |
| 3 | `black_block` + `pink_block` | **dark_pink_block** | `"black_block_seed+pink_block_seed": "dark_pink_block_seed"` | 90s |
| 3 | `black_block` + `green_block` | **dark_green_block** | `"black_block_seed+green_block_seed": "dark_green_block_seed"` | 90s |
| 5 | `black_block` + `blue_block` | **dark_blue_block** | `"black_block_seed+blue_block_seed": "dark_blue_block_seed"` | 300s |
| 3 | `black_block` + `brown_block` | **dark_brown_block** | `"black_block_seed+brown_block_seed": "dark_brown_block_seed"` | 90s |
| 6 | `black_block` + `purple_block` | **dark_purple_block** | `"black_block_seed+purple_block_seed": "dark_purple_block_seed"` | 600s |
| 6 | `aqua_block` + `black_block` | **dark_aqua_block** | `"aqua_block_seed+black_block_seed": "dark_aqua_block_seed"` | 600s |

### Light & pastel variants — colour + white_block

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `red_block` + `white_block` | **red_pastel_block** | `"red_block_seed+white_block_seed": "red_pastel_block_seed"` | 90s |
| 3 | `white_block` + `yellow_block` | **yellow_pastel_block** | `"white_block_seed+yellow_block_seed": "yellow_pastel_block_seed"` | 90s |
| 3 | `pink_block` + `white_block` | **pink_pastel_block** | `"pink_block_seed+white_block_seed": "pink_pastel_block_seed"` | 90s |
| 3 | `green_block` + `white_block` | **green_pastel_block** | `"green_block_seed+white_block_seed": "green_pastel_block_seed"` | 90s |
| 5 | `blue_block` + `white_block` | **blue_pastel_block** | `"blue_block_seed+white_block_seed": "blue_pastel_block_seed"` | 300s |
| 4 | `orange_block` + `white_block` | **orange_pastel_block** | `"orange_block_seed+white_block_seed": "orange_pastel_block_seed"` | 180s |
| 6 | `purple_block` + `white_block` | **purple_pastel_block** | `"purple_block_seed+white_block_seed": "purple_pastel_block_seed"` | 600s |
| 3 | `brown_block` + `white_block` | **light_brown_block** | `"brown_block_seed+white_block_seed": "light_brown_block_seed"` | 90s |

### Specials

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `apple` + `sun_flower` | **happy_block** | `"apple_seed+sun_flower_seed": "happy_block_seed"` | 90s |
| 4 | `lily` + `pink_pastel_block` | **pastel_flower_block** | `"lily_seed+pink_pastel_block_seed": "pastel_flower_block_seed"` | 180s |

### Masonry

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `red_block` + `stone_brick` | **red_brick** | `"red_block_seed+stone_brick_seed": "red_brick_seed"` | 90s |
| 3 | `green_block` + `stone_brick` | **green_brick** | `"green_block_seed+stone_brick_seed": "green_brick_seed"` | 90s |
| 4 | `green_brick` + `vines` | **green_moss_brick** | `"green_brick_seed+vines_seed": "green_moss_brick_seed"` | 180s |

### Walls — brick + cave_background

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 2 | `cave_background` + `stone_brick` | **stone_brick_wall** | `"cave_background_seed+stone_brick_seed": "stone_brick_wall_seed"` | 45s |
| 4 | `cave_background` + `red_brick` | **red_brick_wall** | `"cave_background_seed+red_brick_seed": "red_brick_wall_seed"` | 180s |
| 4 | `cave_background` + `green_brick` | **green_brick_wall** | `"cave_background_seed+green_brick_seed": "green_brick_wall_seed"` | 180s |
| 5 | `cave_background` + `green_moss_brick` | **green_moss_brick_wall** | `"cave_background_seed+green_moss_brick_seed": "green_moss_brick_wall_seed"` | 300s |

### Ores & gems — gem_block + colour

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `gem_block` + `yellow_block` | **gold_block** | `"gem_block_seed+yellow_block_seed": "gold_block_seed"` | 90s |
| 3 | `gem_block` + `green_block` | **emerald_block** | `"gem_block_seed+green_block_seed": "emerald_block_seed"` | 90s |
| 3 | `gem_block` + `red_block` | **ruby_block** | `"gem_block_seed+red_block_seed": "ruby_block_seed"` | 90s |
| 6 | `gem_block` + `purple_block` | **amethyst_block** | `"gem_block_seed+purple_block_seed": "amethyst_block_seed"` | 600s |
| 3 | `gem_block` + `glass_panel` | **diamond_block** | `"gem_block_seed+glass_panel_seed": "diamond_block_seed"` | 90s |

### Decorative & world

| tier | recipe | result block | key to add | grow |
|---|---|---|---|---|
| 3 | `grass` + `sand_castle` | **sugar_cane** | `"grass_seed+sand_castle_seed": "sugar_cane_seed"` | 90s |
| 3 | `red_block` + `wood_plank` | **barn_block** | `"red_block_seed+wood_plank_seed": "barn_block_seed"` | 90s |
| 3 | `black_block` + `glass_panel` | **street_lamp** | `"black_block_seed+glass_panel_seed": "street_lamp_seed"` | 90s |
---

## Verification

Checked mechanically against the 26 existing recipes, not by eye:

| check | result |
|---|---|
| Keys bytewise-sorted (required by `get_splice_key`) | **46/46 pass** |
| Collisions with existing recipes | **0** |
| Duplicate keys within the new set | **0** |
| Two recipes producing the same seed | **0** |
| Every input reachable from base seeds | **0 unreachable** |
| Results that are real blocks with seed ids | **46/46** |

Base seeds assumed obtainable without splicing: `dirt`, `grass`, `stone`, `wood`, `leaf`,
`lava`, `sand`, `cave_background`.

---

## Open questions before this ships

**1. Amethyst is tier 6 while the other four ores are tier 3.** Because amethyst needs
purple, which needs blue, which needs ice. Either that's the story — amethyst is the rarest
ore — or the ore family should be flattened so all five sit together. Your call; the fix is
one line (`gem_block` + `dark_pink_block` would bring it to tier 4).

**2. Diamond is tier 3, cheaper than amethyst.** Conventionally diamond is the top ore. If
you want that, `gem_block` + `ice_block` (tier 4) or `gem_block` + `white_block` reads
better than the current `gem_block` + `glass_panel`.

**3. `ice_block` currently exists as a winter-event block.** Giving it a recipe
(`glass` + `white_block`) makes it year-round obtainable. If ice should stay seasonal, blue
needs a different source — and there isn't an obvious one, which would mean dropping the
blue family or accepting a less intuitive pairing.

**4. Blue's depth cascades.** 9 of the 46 recipes sit downstream of ice. If that feels too
punishing, making `blue_block` a tier-2 pigment directly (e.g. `glass` + `pile_of_sand`,
moving white elsewhere) collapses the whole branch by two tiers.

---

## Deliberately not covered

**Blocks with no seed id.** These would need a `seed` field added before they could be
splice targets — a data change beyond recipes: `wooden_chair`, `wooden_table`, `steel_block`,
`steel_door`, `screen_door`, `steel_platform`, `steel_ladder`, `steel_sign`,
`steel_background`, `white_fence`, `city_fence`, `fire_escape`, `barn_door`,
`barn_background`, `hay`, `bone`, the 12 solid-colour `*_bg` backgrounds.

**Functional and machine blocks.** `vend_empty`, `safe`, `atm_machine`, `cctv`,
`oil_refinery`, `anti_gravity`, portals, checkpoints, hazards. These are progression or
purchase rewards; making them farmable would undercut whatever currently gates them.

**Locks.** `small_lock` through `super_world_lock` — deliberately outside any farming loop.

**The 5 prestige colours** (`ps_*_block`) — pack rewards, should stay exclusive.

**Winter event set** — seasonal by design, and most are `placeable: false`.

**The 10 orphaned seeds** (`royal_door_seed`, `lamp_seed`, `tv_seed`, `blue_couch_seed`,
`green_couch_seed`, `purple_curtains_seed`, `pink_curtains_seed`, `fish_bowl_seed`,
`royal_window_seed`, `royal_entrance_seed`). These seeds exist but the blocks they grow into
do not, so a recipe targeting them would hand players a seed that grows into nothing. Worth
fixing separately — either build the blocks or remove the seeds.
