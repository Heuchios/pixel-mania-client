# Login latency fixes — 2026-10-12

Deployed to staging as `20261012-login-b8a4133`, with backend `b8a413390ef9`
and client source `7b13dbb1e709`. Both source commits are pushed to staging.
Gameplay, credentials, saved-data formats, database schema, authentication deadlines,
password hashing and rate-limit thresholds are unchanged.

## Reproduced problems and changes

1. A server rate-limit rejection was delivered immediately but ignored by the
   account screen. The real client then waited 20,036 ms and reported a connection
   interruption. Account rate-limit replies now use `account_auth_error` with the
   original request ID, including repeated requests inside the generic warning
   cooldown. The client also recognizes old servers' generic account rejection
   packets, while ignoring unrelated actions and stale request IDs.
2. A successful response arrived in 7 ms, but the client stalled inside the
   synchronous lobby scene load while world resources loaded on worker threads.
   The probe was terminated after 45 seconds. Login now starts loading the lobby
   first and awaits its threaded load before switching scenes. Network polling and
   UI updates continue while loading; double sign-on is blocked during transition.
3. Existing-account sign-on unnecessarily upserted account/player identities,
   potentially contending with gameplay saves. Matching persisted identities now
   use one read; differing or missing legacy identities retain the previous repair
   path. Session rotation uses five SQL statements rather than seven (excluding
   transaction BEGIN/COMMIT). Session inserts, revocation and rollback are preserved.
4. Independent IP/account Redis login-limit checks run concurrently, preserving
   both counters and limits while removing one serial Redis round trip.

Credential-free `LOGIN_AUTH_PROFILE` and `LOGIN_LOBBY_PROFILE` timings distinguish
authentication waits from scene loading in future reports.

## Verification

Actual Godot client, loopback WebSocket server, disposable profiles and synthetic
credentials; these timings are not production-network or physical-phone benchmarks:

| Scenario | Click to result |
| --- | --- |
| Password login to initialized lobby | 540 ms |
| Remembered refresh-token login to initialized lobby | 574 ms |
| Legacy generic rate-limit rejection | 46 ms |
| Correlated account rejection | 39 ms |
| Deliberately delayed 8.2-second success | 8,260 ms, first attempt succeeds |

Each scenario sent credentials exactly once. Full world warmup completed before
test shutdown. Existing remembered-login and connection-health regressions pass,
including disconnect, timeout retirement, delayed replies and stale rejection IDs.

The isolated PostgreSQL/WASM test uses the repository's real security schema and
session methods. It confirms legacy identity creation/repair, unchanged IDs/world,
token rotation/revocation, foreign-account rejection and transaction rollback after
a socket disconnect. Triggers reject all account/player writes during the ordinary
login test, proving those redundant writes are absent. Rate-limit regressions prove
both Redis checks start together and either bucket can still reject the request.

Commands:

- Server: `node scripts/test_login_latency.js` (`GODOT_BIN` and
  `PIXELMANIA_CLIENT_ROOT` may override the adjacent runtime/client).
- Database: `node scripts/test_login_session_postgres.js` with PGlite installed, or
  `QUEST_TEST_PGLITE_PATH` pointing to the existing test runtime.
- Client: Godot headless `res://tests/remembered_login_test.tscn` and
  `--script res://tests/connection_health_test.gd`.

Evidence: `D:/Pixelmania/work/login-isolated-smoke-20261012/results.json` and
`D:/Pixelmania/work/login-latency-probe/` (initial reproduction logs).

## Release verification

The full `npm run check:security` and TypeScript release gate passed. Staging's
deployed router, rate-limit, account-session and account-security regressions passed.
The release manifest identifies the exact backend/client commits above and reports
clean selected client files. Public health confirms PostgreSQL authoritative/ready,
Redis ready, client version 1.2.20 and minimum 1.2.14. The email-verification guard
smoke also passed. Deployment log:
`D:/Pixelmania/work/login-staging-deploy-20261012.log`.

Rollback release: `20261012-multiplayer-17e7b89`. Production remains
`20261010-hand-visuals-33256ff` (client 1.2.24/minimum 1.2.14). No live account
credentials or data were used for the tests. Published Windows/Android binaries
were not rebuilt or distributed: the lobby/client fixes need a restarted local
debug client or a future published build, while staging already runs the backend
fixes. Physical mobile timing and production login latency were not measured.
