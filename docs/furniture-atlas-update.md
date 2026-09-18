# Furniture atlas update

Added or updated all 65 requested items, plus nine internal on/open states. Existing item IDs are retained when renaming furniture so saved inventories and worlds still resolve.

- All 65 collectible items have seeds and block, seed, and gem rewards on breaking and tree harvesting. Existing reward amounts and chances were preserved where available.
- Farm Fence and Gothic Fence use the Wooden Fence foreground behavior. House Table, Dresser, and both platforms use one-way platform collision.
- Couch, Potato Couch, and Park Bench connect horizontally; vertically adjacent furniture does not change their artwork.
- House Entrance and Ventilation use entrance access, collision, and pass-through animations. House Door, Grand House Door, and Barn Door use the existing door system.
- Toilet, Refrigerator, and Sink open on a punch and remain open while subsequent punches break them. Refrigerator remains solid in either state.
- Fireplace, Bathtub, Digital Sign, Open Sign, Chandelier, and Sirene Lamp toggle on/off while retaining accumulated break damage. Internal states drop the base item's rewards, not an extra collectible state or seed.
- Fireplace uses frames 1–2–3–2–1; Bathtub uses 1–2; Digital Sign uses 1–2–3. Rubber Duck and Fan animate only on a server-confirmed hit. Water Fountain animates continuously.
- Polished Stone Brick uses both confirmed artwork variants, chosen deterministically by placement position.
- The Starry Night uses a 64×64 region. Sun is solid; White Window, signs, and the unspecified paintings are non-solid.
- Landfill TV and Used Tires retain the event's existing `broken_tv` and `tires` IDs and scoring integration.
- Barn Window and Barn Door use the explicitly confirmed (0,20) and (0,21). The overlapping old Barn Block registration is retired from new placement/admin grants; its saved data remains resolvable. Barn Wall uses (2,26).

Validation covers client runtime loading, textures, collisions, seed mappings, reward preservation, connected furniture, entrance frames, deterministic artwork, server toggle behavior and base-item drops. Existing 93-item atlas checks pass. Recipe synchronization was subsequently completed against the live Google Sheet; see `splicing-recipe-report.md` for current counts and deferred rows. These local changes have not been deployed.
