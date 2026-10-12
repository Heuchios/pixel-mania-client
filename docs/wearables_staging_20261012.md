# Wearables staging update — 2026-10-12

44 requested wearables: 40 new items and four existing entries updated in place. Atlas cells are zero-based, 32 × 32 pixels in `Assets/items/wearable.png`. Current/minimum staging version remains 1.2.25. Restart the updated editor/debug client against staging to see the new artwork; published desktop/Android binaries are unchanged.

Masks use the existing persisted `beard` equipment slot, labelled Mask in inventory and Masks / Beards in the developer inventory. This update completes mask inventory counts, equip/unequip, save/broadcast, inventory refresh, pickup routing and last-item removal. No new persistence schema or item distribution changes are needed. New entries are grantable through the developer catalog.

Coveralls, skirts, robes, dresses and coats use the shirt slot. Their atlas canvas origin differs from standard shirts: body offset (-2, 4), right sleeve (0, 4), left sleeve (-8, 4). These offsets follow the existing animated body/arms and reset when switching back to a normal shirt. Rows without supplied arms are sleeveless. Split pants follow the animated feet; shoes retain their original canvas and zero per-foot offsets.

Yellow Shoes retains its existing `basic_yellow_shoes` ID, with the requested row 7 artwork. Row 5 is now Golden Shoes. Existing `void_shoes` and the `flaming_skull` hat remain valid; Void Slippers and the Burning Skull mask are separate requested items. Void Visor now uses exactly four frames. All seven animated additions/updates loop at 6 fps across idle, walk, jump, fall, punch, hurt and death states.

| Name | Item ID | Slot | Preview | Equipped parts | Frames | Change |
| --- | --- | --- | --- | --- | --- | --- |
| Scrub Top | `scrub_top` | shirt | 0,13 | base 1,13; right arm 5,13; left arm 6,13 | 1 | New |
| Space Suit | `space_suit` | shirt | 0,14 | base 1,14; right arm 5,14; left arm 6,14 | 1 | New |
| Void Shirt | `void_shirt` | shirt | 0,15 | base 1,15; right arm 5,15; left arm 6,15 | 1 | Updated |
| Scrub Bottoms | `scrub_bottoms` | pants | 7,13 | base 8,13; left leg 9,13; right leg 10,13 | 1 | New |
| Space Pants | `space_pants` | pants | 7,14 | base 8,14; left leg 9,14; right leg 10,14 | 1 | New |
| Void Pants | `void_pants` | pants | 7,15 | base 8,15; left leg 9,15; right leg 10,15 | 1 | Updated |
| Scrub Mask | `scrub_mask` | Mask (face/beard) | 22,13 | base 23,13 | 1 | New |
| Duck Beak | `duck_beak` | Mask (face/beard) | 22,14 | base 23,14 | 1 | New |
| Cat Face Mask | `cat_face_mask` | Mask (face/beard) | 22,15 | base 23,15 | 1 | New |
| Rat Face Mask | `rat_face_mask` | Mask (face/beard) | 22,16 | base 23,16 | 1 | New |
| Clown Nose | `clown_nose` | Mask (face/beard) | 22,17 | base 23,17 | 2 | New |
| Cigar | `cigar` | Mask (face/beard) | 22,18 | base 23,18 | 3 | New |
| Red Headphones | `red_headphones` | hat | 22,19 | base 23,19 | 3 | New |
| Meowphones | `meowphones` | hat | 22,20 | base 23,20 | 3 | New |
| Floral Circlet | `floral_circlet` | Mask (face/beard) | 22,21 | base 23,21 | 1 | New |
| Eye Patch | `eye_patch` | eyewear | 22,22 | base 23,22 | 1 | New |
| Void Visor | `void_visor` | eyewear | 22,23 | base 23,23 | 4 | Updated |
| Golden Shoes | `golden_shoes` | shoes | 33,5 | base 34,5; right foot 38,5 | 1 | New |
| Green Sneakers | `green_sneakers` | shoes | 33,6 | base 34,6; right foot 38,6 | 1 | New |
| Yellow Shoes | `basic_yellow_shoes` | shoes | 33,7 | base 34,7; right foot 38,7 | 1 | Updated |
| White Shoes | `white_shoes` | shoes | 33,8 | base 34,8; right foot 38,8 | 1 | New |
| Diamond Shoes | `diamond_shoes` | shoes | 33,9 | base 34,9; right foot 38,9 | 1 | New |
| Slippers | `slippers` | shoes | 33,10 | base 34,10; right foot 38,10 | 1 | New |
| Black Slippers | `black_slippers` | shoes | 33,11 | base 34,11; right foot 38,11 | 1 | New |
| Bunny Slippers | `bunny_slippers` | shoes | 33,12 | base 34,12; right foot 38,12 | 1 | New |
| Duck Slippers | `duck_slippers` | shoes | 33,13 | base 34,13; right foot 38,13 | 1 | New |
| Green Slippers | `green_slippers` | shoes | 33,14 | base 34,14; right foot 38,14 | 1 | New |
| Grey Sneakers | `grey_sneakers` | shoes | 33,15 | base 34,15; right foot 38,15 | 1 | New |
| Void Slippers | `void_slippers` | shoes | 33,16 | base 34,16; right foot 38,16 | 1 | New |
| Coveralls | `coveralls` | Outfit (shirt) | 42,0 | base 43,0; right arm 47,0; left arm 48,0 | 1 | New |
| White Skirt | `white_skirt` | Outfit (shirt) | 42,1 | base 43,1; right arm 47,1; left arm 48,1 | 1 | New |
| Purple Skirt | `purple_skirt` | Outfit (shirt) | 42,2 | base 43,2; right arm 47,2; left arm 48,2 | 1 | New |
| Black Skirt | `black_skirt` | Outfit (shirt) | 42,3 | base 43,3; right arm 47,3; left arm 48,3 | 1 | New |
| Red Skirt | `red_skirt` | Outfit (shirt) | 42,4 | base 43,4 | 1 | New |
| Wizard's Robe | `wizards_robe` | Outfit (shirt) | 42,5 | base 43,5 | 1 | New |
| Purple Dress | `purple_dress` | Outfit (shirt) | 42,6 | base 43,6 | 1 | New |
| Black Coat | `black_coat` | Outfit (shirt) | 42,7 | base 43,7 | 1 | New |
| Horse Mask | `horse_mask` | Mask (face/beard) | 49,0 | base 50,0 | 2 | New |
| Welding Mask | `welding_mask` | Mask (face/beard) | 49,1 | base 50,1 | 1 | New |
| Space Mask | `space_mask` | Mask (face/beard) | 49,2 | base 50,2 | 1 | New |
| Skull Mask | `skull_mask` | Mask (face/beard) | 49,3 | base 50,3 | 1 | New |
| Burning Skull | `burning_skull` | Mask (face/beard) | 49,4 | base 50,4 | 4 | New |
| Sack Mask | `sack_mask` | Mask (face/beard) | 49,5 | base 50,5 | 1 | New |
| Bag on the Head | `bag_on_the_head` | Mask (face/beard) | 49,6 | base 50,6 | 1 | New |

## Full-head covers

Horse Mask, Welding Mask, Space Mask, Skull Mask, Burning Skull, Sack Mask,
Bag on the Head and the existing Flaming Skull hat use head layer 4, above
eyewear and small face accessories on layer 3. The shared local/remote equipment
renderer now honors the configured head layer when equipping or swapping items.

These eight items also set `hides_hair: true`. Hair stays equipped and keeps its
sprite/animation data, but is invisible while either the hat or face slot contains
a full-head cover. Removing the last cover restores the hair. Swapping to ordinary
headwear restores normal layering; actually unequipping hair keeps it hidden.

`tests/helmet_layering_test.gd` checks both facings, local and remote appearance,
all movement states, equipment order, overlapping covers, swaps and unequips.
Its GPU regression checked 30 animation-frame/facing combinations and 47,968
fully opaque helmet pixels, with zero accessory pixels drawn over them. Lowering
the helmet layer reproduced the bug in 6,680 pixels. Authored transparent pixels
remain transparent. Existing wearable and remote-equipment checks also pass.

## Deployed release

- Staging release: `20261012-helmet-cover-72ff82f`.
- Backend commit: `72ff82f4665da0d565ae6988172f0072b26a9aaf`.
- Client commit: `21cb942a23d0107bdd45421b116abb42247d1bcc`.
- API: `https://staging-api.pixelmaniagame.com`; current/minimum client 1.2.25.
- Immutable archive validation, remote release checks, public smoke checks and the 44-item catalog check on the active staging server all passed. PostgreSQL and Redis are ready.
- Prior staging release / rollback: `20261012-wearables-a22bc8b` (the original 44-item addition).
- Production remains `20261010-hand-visuals-33256ff`.
- Helmet correction evidence: `D:/Pixelmania/work/helmet-cover-deploy.log`, `helmet-cover-security.log` and `helmet-layering-render.log`. Full security and deployed catalog checks passed again for the correction. Original item-addition deployment log: `D:/Pixelmania/work/wearables-20261012-deploy.log`.

The release used a clean checkout of the client commit at `D:/Pixelmania/releases/wearables-staging-20261012/pixel-mania`. Concurrent UI-transition edits in the main workspace were left outside these commits and this release's client metadata.

## Verification

- Godot `tests/wearable_expansion_test.gd`: all 44 definitions, exact atlas regions, visible art, preview separation, split limb attachment, both facings, all animation states, outfit alignment/restoration, and unequip.
- Godot rendered contact sheet reviewed for all 44 worn items and their previews.
- Godot `tests/mask_inventory_test.gd`: all 14 masks, owned/unowned equip, unequip, save and appearance broadcast hooks, Mask label, pickup category routing, count refresh, and removing the last equipped copy.
- Existing basic pants, remote equipment performance and inventory incremental refresh regressions passed.
- Backend `npm run check:security` passed, including dependency audit, TypeScript, item parity, anti-dupe, persistence, account and gameplay checks.
- Backend `npm run check:wearable-expansion` and comparison against the Godot-exported definitions passed for all 44 items.

Evidence: `D:/Pixelmania/work/wearables-20261012-security.log`, `wearables-20261012-render.log`, `wearables-20261012-preview.png`, `wearables-20261012-client.json` and the corresponding `*-wearables.log` regression logs.

To export the contact sheet and client parity data, set `PIXELMANIA_TEST_OUTPUT_DIR` to an existing output directory, then run the wearable test with a rendering driver and `-- --render`. The test also runs headlessly without those optional outputs.
