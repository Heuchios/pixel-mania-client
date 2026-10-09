# Wearables release 1.2.21

Released to production on 2026-10-09 UTC (2026-10-08 local).

Added 15 items from `Assets/items/wearable.png`; the existing Police Hat already
used the requested cells and was retained. All coordinates below are zero-based
32-pixel atlas cells. Inventory previews and equipped artwork remain separate.

| Category | Name | Item ID | Icon cell | Equipped cells |
| --- | --- | --- | --- | --- |
| Hair | Black Spiky Hair | `black_spiky_hair` | 12,12 | 13,12 |
| Hair | Chestnut Curtains | `chestnut_curtains` | 12,13 | 13,13 |
| Hair | Supernova Hair | `supernova_hair` | 12,14 | 13,14 through 15,14 |
| Hair | Chestnut Bob | `chestnut_bob` | 12,15 | 13,15 |
| Hair | Ginger Ponytail | `ginger_ponytail` | 12,16 | 13,16 |
| Hair | Ginger Pigtails | `ginger_pigtails` | 12,17 | 13,17 |
| Hat | Police Hat (existing) | `police_hat` | 17,13 | 18,13 |
| Hat | Scrub Hat | `scrub_hat` | 17,14 | 18,14 |
| Hat | Ruby Bow | `ruby_bow` | 17,15 | 18,15 |
| Hat | Violet Bow | `violet_bow` | 17,16 | 18,16 |
| Hat | Sunflower Cap | `sunflower_cap` | 17,17 | 18,17 |
| Hat | Wizard's Hat | `wizards_hat` | 17,18 | 18,18 |
| Hat | Witch Hat | `witch_hat` | 17,19 | 18,19 through 21,19 |
| Hat | Cone Hat | `cone_hat` | 17,20 | 18,20 |
| Hat | Pirate Hat | `pirate_hat` | 17,22 | 18,22 |
| Hat | Go Green Hat | `go_green_hat` | 17,23 | 18,23 |

Supernova Hair loops three frames and Witch Hat loops four frames, both at 5 FPS
for every movement state. All six new hairstyles are Hair Pack rewards. Seventeen
ordinary rewards have weight 999 each; Baby Hair has weight 17, maintaining its
server-authoritative 0.1% chance. Generated shop disclosures match these odds.
The hats use the existing equipment/admin catalog; no new direct-sale prices or
hat reward sources were introduced. New wearables are instance tracked, equipable,
tradeable, vendable and droppable.

## Release evidence

- Client build source: `0f747b510d55c8eed2271598fe59a17551c03ea6`
  (item implementation `97909620`, generated shop odds `0f747b51`).
- Backend: `a4de8670af2a` (catalog `97c1a46`, line-ending normalization `a4de867`).
- Active production release: `20261009-wearables-a4de867`.
- Rollback target: `20261008-mobile-inventory-214da34`.
- Main port 8080 and route ports 18091/18092 all report this release, version
  1.2.21, minimum 1.2.14, PostgreSQL ready and Redis ready.
- Production item database was read back and verified for all 16 requested IDs.
- Production desktop manifest is 1.2.21; a real launcher download, checksum and
  installation test passed for exactly 1.2.21.
- Desktop ZIP SHA-256:
  `f5831dd8f51675ced17de53e970ce108f6b7052311f6277dbbce5607d03fcf84`.

Artifacts and machine-readable evidence are in
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.21-verified/`, including
the desktop ZIP, signed Android APK/AAB, `build-manifest.json`,
`production-desktop-manifest.json` and `release-verification.json`.

Android artifacts are version 1.2.21/code 43. APK and AAB signatures were checked;
the APK is non-debuggable, embeds the correct package/version and uses the same
signing certificate as 1.2.20. These artifacts have not been uploaded to Google
Play. The production Android manifest remains 1.2.6; it was not changed.
Temporary export credentials were removed from both build directories.

## Validation and limits

The full backend `check:security` passed on the isolated committed release, as
did client/server catalog synchronization and Hair Pack probability checks.
The item regression checks all 16 icon/equipped regions, visible artwork,
equipment categories, movement animation sequences and new Hair Pack membership.
Hair Pack artwork/chase-odds and shop disclosure/layout tests passed. The item
regression also passed on the exact isolated client build source.

The Windows release started cleanly and connected to production while rejecting
staging overrides. Hardened export templates disable `--script`, so standalone
item regressions were run on source, not claimed as packaged-script tests.
Normal packaged startup was verified with paced frames (`--max-fps 60`) before
automatic exit. No physical Android-device or authenticated multiplayer
equipment test was performed.

Automatic approval review rejected the staging upload as outside the explicitly
authorized production destination. Production was deployed directly using the
passed local full gate, remote release/item/anti-dupe gates and production smoke
checks. No staging deployment or staging test result is claimed.

Unrelated uncommitted fishing changes and temporary files remain untouched in
the main client/backend workspaces and are excluded from this release.
