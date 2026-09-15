# UI and staging role verification — 2026-09-13

The targeted backend role persistence fix was deployed to staging release
`20260914T002855Z-world-lock-role-fix`.
The same targeted backend files were subsequently promoted to production release
`20260915T001951Z-world-lock-role-fix`, with matching SHA-256 hashes. The main
server, both production world servers, and public API passed health checks.
Previous staging release: `20260907T155807Z-e99ccc4a1084`.

The deployed PostgreSQL save and reload paths were exercised in world TEST
(owner USO) for UCE as builder, visitor, admin, and removed member. Each case
passed. All test writes were rolled back; UCE retained its original admin role.
These were database round-trip checks, not an interactive two-client play test.

The fix preserves visitor roles in identity maps, treats legacy member roles
as visitor, and removes stale identity grants when access is removed.

Local checks passed: atlas migration, typography, world-lock layout, compact
inventory/world-lock layout, scene preview synchronization, backend role rules,
and backend role persistence. Client UI edits remain local and need a client
build for device testing. Physical-phone and interactive two-account testing
remain unverified.

Final preview review also corrected trade Cancel buttons being styled as small
icon-only close buttons, and the area-lock runtime override replacing its atlas
background. The area-lock panel and public-building label now allow more room.
