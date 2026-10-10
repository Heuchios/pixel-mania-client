# Fishing fixes — production 1.2.23

Released 2026-10-09 local / 2026-10-10 UTC. Backend commit
`5a59e28d118115f6dbcda6ad247783b0bc4e5e0a` and client build source
`654bba8efb448286085628c986a9a6e4c477aa7f` shipped as
`20261010-fishing-5a59e28`. Rollback target:
`20261009-wearable-names-6acf01a`.

Fishing target validation previously read only the saved foreground placement
map. Natural ponds are generated separately, so visible natural water was
rejected. Validation now uses the authoritative effective foreground map.
Player placements, removed water, frozen ponds and cleared worlds override
generation as they do for rendering and collision. Reach checks remain enforced.

Expired server casts now clear before a retry, instead of permanently blocking
new casts until world/session cleanup. Live casts still reject duplicate starts;
bait spending and rewards remain authoritative and transactional. The client
now replaces its casting notification with an explicit cancellation reason when
selection, equipped rod, water, reach, menus or keyboard focus changes while
waiting for an accepted reply. Late replies still cancel only their own session.

## FREEZE investigation

The user identified FREEZE, world FREEZE, wooden fishing rod, Samsung S22.
Read-only on-server checks found valid rod ownership/tracking, usable bait and
a compatible reward pool. The latest recorded client includes the 1.2.20 fixes.
No accepted start or catch appeared in that account's fishing item transactions.
Detailed account records were not exported; automatic review allowed boolean
diagnostic results instead.

Actual FREEZE terrain generation reproduced the natural-water validation bug
in an isolated test before the fix. A replay with the saved production edits
also found its natural water currently replaced by ice, leaving no fishable
water at inspection. No ice, inventory or account state was changed. This is
not proof of the conditions during the reported attempt or a Samsung-specific
failure. An open-water retry in FISHING was requested; physical S22 testing
was unavailable.

## Verification and artifacts

- Full backend `check:security` passed before commit/deployment.
- 33 target checks cover actual generated ponds in FREEZE/FISHING/START/POND,
  removed water, new water, ice, solid replacements, cleared worlds and reach.
- Expired/live start recovery, 80 completion checks and fishing visual sync pass.
  The same regressions passed against the deployed production code.
- 248 isolated client fishing checks, catalog and mobile single-tap checks pass.
  Tests include wooden rod and bait selection on phone viewports, low frame
  rates, viewport changes, cancellations, duplicate/late responses and timeouts.
- Main port 8080 and routes 18091/18092 report 1.2.23 and ready PostgreSQL/Redis.
  Production post-deploy smoke checks pass.
- Packaged Windows normal rendered startup connects without runtime errors.
  Headless dummy-renderer errors also occur in the preceding release; normal
  rendered startup was verified separately.
- The real launcher downloaded, verified and installed exactly 1.2.23.
- Android APK/AAB signatures are verified; APK is non-debuggable, version
  1.2.23/code 45, with the same signing certificate as 1.2.22. Temporary export
  credentials were removed. Android builds have not been uploaded to Google Play.

Artifacts and exact SHA-256 values are under
`D:/Pixelmania/PixelMania/release_artifacts/client-1.2.23/` in
`build-manifest.json` and `release-verification.json`. Windows ZIP SHA-256:
`a488dbeed1b1cc37d7690ad8a2ec58e0c0d8815752658d3e583d2c09509d577b`.

The global minimum remains 1.2.14, desktop minimum 1.2.21, and Android publication
policy remains 1.2.6. This release includes all previous production changes,
including pickup/loadout/mobile UI/music repairs and wearable name corrections.
Unrelated temporary files were excluded. No GitHub push was performed.
