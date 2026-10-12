# Combined staging release — 2026-10-12

The user requested committing all pending work and deploying to staging.
Production remains on `20261010-hand-visuals-33256ff`, client version 1.2.24,
minimum 1.2.14. No production data or distribution manifests were changed.

## Active staging release

- Release: `20261012-combined-036f3b0`.
- Backend: `036f3b0c8b4675945cf73b5eb6e24631c74312f6`.
- Client metadata packaged by the backend release:
  `42f642ff12d8416b03d0517855ed88dd89790b2c` (clean).
- API: `https://staging-api.pixelmaniagame.com`.
- WebSocket: `wss://staging-api.pixelmaniagame.com/ws`.
- Current and minimum client version: **1.2.25** on staging only.
- Previous release / rollback: `20261012-login-b8a4133`.
- Rollback command, as the staging account only:
  `bash ~/PixelManiaServer/bin/rollback_release.sh --yes`.

Both repositories' existing staging histories were merged without force pushes.
The combined client includes the earlier trade review, chat layout, warning
visibility, mobile UI, fishing, inventory recovery, item-name and hand-effect
fixes, plus pending login, multiplayer presence/health, pickup performance,
gem HUD, vending, daily rewards, and visual refinements. All project source,
assets, tests and existing scratch source were committed. Generated server test
profiles and logs are ignored, as are existing credential/signing files.

The final client staging commit also includes the roulette polish committed as
`19ce8d23` and the final area-lock animation refinement. These are client-only;
they do not change the deployed backend or its client validation metadata.
Restart the local/editor client to test the current staging client source.
The project already points editor/debug desktop clients at staging. Published
release binaries remain unchanged; the older 1.2.25 release artifacts do not
contain every subsequent client change and must not be described as this build.

## Verification

- Full `npm run check:security` passed on the combined backend. Merging staging
  introduced no further backend content changes. Deployment reused that gate
  with `-Fast`, and ran local/remote release checks and public smoke checks.
- Nineteen targeted Godot suites passed, covering warning-driven UI closure,
  trade review, chat collision/typing, mobile Back, display interaction, hand
  effects, remembered login, vending/layout, gems, pickup performance, activity
  bubbles, health bars, daily rewards, partial player state and area locks.
  The remembered-login suite uses its `.tscn` entry point, not `--script`.
- Daily reward lifecycle: 88 checks. Warning visibility: 29 checks. Remote
  hand visuals: 189 checks. Final roulette and area-lock refinements were rechecked.
- Isolated PostgreSQL login tests passed: existing identity reuse, legacy repair,
  session rotation/revocation, unchanged world/IDs and disconnect rollback.
- Actual local Godot/WebSocket login tests passed for password, saved login,
  generic legacy rejection, correlated rejection and an 8.2-second delayed reply.
- Eight live staging handshake checks passed. Windows and Android-labelled
  requests with 1.2.24, missing versions and malformed versions are rejected;
  1.2.25 passes the version gate. This is protocol verification, not a physical
  mobile-device test.
- Public health confirms the exact release ID, PostgreSQL authoritative/ready
  and Redis ready. A read-only production check confirms its release is unchanged.

Evidence is under `D:/Pixelmania/work/`: `staging-all-20261012-security.log`,
`staging-all-20261012-deploy.log`, `staging-all-version-probe.log`,
`staging-all-login-postgres.log`, `staging-all-login-transport/`, and
`staging-all-client-20261012/`.
