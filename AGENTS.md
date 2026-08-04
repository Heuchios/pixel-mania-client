# PixelMania Project Rules

## Backend Persistence

For backend persistence policy, read:

- `docs/backend_persistence_rules.md`
- `docs/codex_handoff_status.md`

Short version:

- PostgreSQL is the permanent source of truth for durable game data.
- Redis is only for temporary live coordination such as locks, rate limits,
  presence, sessions, cooldowns, and queues.
- DigitalOcean Spaces is file/object storage for off-site backups and large
  world snapshot files.
- Local JSON is only for development, migration fallback, or emergency recovery.

When adding any durable backend feature, wire it to PostgreSQL as part of the
feature.

Before continuing backend/security/economy work in a new Codex chat, read
`docs/codex_handoff_status.md` for the current production status, completed
systems, deployment notes, and remaining caveats.

## Wearable Hair Assets

When adding hair items, keep the equipped sprite and UI preview separate:

- `texture` must point to the base hair-only sprite used on the player.
- `inventory_icon` must point to the matching `_icon` sprite.
- `_icon` sprites are for inventory icons, detail panel previews, vending
  previews, and display case/box previews only.
- Equipped hair visuals must use the base hair sprite, not the `_icon` sprite.
- Shop hair style/color variants should be rewards in
  `hairpack`/`HAIR_PACK_REWARDS`, not separate shop listings, unless the user
  explicitly asks for direct sales.
- `baby_hair` is the legendary Hair Pack chase reward. Keep it at a 0.1%
  server-authoritative chance unless the user explicitly asks to rebalance it.

## Wearable Hat Assets

When adding head/hat items, keep the equipped sprite and UI preview separate:

- Put new hat art in `Assets/clothes/head/` using `<item_id>.png` and
  `<item_id>_icon.png`.
- `texture` must point to the base hat sprite equipped on the player.
- `inventory_icon` must point to the matching `_icon` sprite.
- `_icon` sprites are for inventory slots, detail panel previews, vending
  previews, and display case/box previews only.
- Equipped hat visuals must use the base hat sprite, not the `_icon` sprite.

## Wearable Shoes Assets

When adding shoes items, keep equipped foot sprites and UI preview separate:

- `left_shoe_texture` must point to the left-foot sprite equipped on the player.
- `right_shoe_texture` must point to the right-foot sprite equipped on the player.
- `texture` and `inventory_icon` must point to the paired `*_shoes` sprite used
  for inventory slots, detail previews, vending previews, and display previews.
- Equipped shoes visuals must use the left/right foot sprites, not the paired
  preview sprite.
- Do not crop, trim, or auto-center equipped shoe sprites; their LibreSprite
  canvas placement is part of the alignment.
- Keep per-foot shoe offsets at `[0, 0]` by default; only add offsets after
  testing the equipped item in-game.

## Wearable Shirt Assets

When adding shirt items, keep equipped body/arm sprites and UI preview separate:

- Put new shirt art in `Assets/clothes/shirts/` using this file format:
  `<item_id>_body.png`, `<item_id>_arm.png`, `<item_id>_arm_left.png`, and
  `<item_id>_icon.png`.
- `texture` and `shirt_body_texture` must point to the `<item_id>_body.png`
  sprite equipped on the player body.
- `arm_texture` or `right_arm_texture` must point to `<item_id>_arm.png`, the
  right-arm equipped sprite.
- `left_arm_texture` must point to `<item_id>_arm_left.png`, the left-arm
  equipped sprite.
- `inventory_icon` must point to `<item_id>_icon.png`.
- `_icon` sprites are for inventory slots, detail panel previews, vending
  previews, and display case/box previews only.
- Equipped shirt visuals must use body/right-arm/left-arm sprites, not the
  `_icon` sprite.
