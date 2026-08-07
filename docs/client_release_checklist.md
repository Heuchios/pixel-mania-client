# Client release checklist — Windows `.exe` and Android `.aab`

Your presets (`export_presets.cfg`):

| preset | platform | output | notes |
|---|---|---|---|
| `Windows Desktop` | Windows | `../../Test/PixelMania.exe` | custom templates from `G:/PixelMania/Godot/bin/` |
| `com.pixelmania.game` | Android | `../../Test/PixelMania.aab` | `export_format=1` (AAB), **arm64-v8a only**, package `com.pixelmaniagame.pixelmania` |

Both use `export_filter="all_resources"`, so new assets (including `Assets/shaders/`) are
included automatically — no preset change needed when you add art or shaders.

---

## 0. The one that actually matters: Release, not Debug

`network_manager.gd::should_allow_network_override()`:

```gdscript
if OS.has_feature("android") or OS.get_name().to_lower() == "android":
    return false
return OS.has_feature("editor") or OS.has_feature("debug")
```

- **Debug export** → honours `--pixelmania-api-base` / `--pixelmania-ws-url`. Anyone can
  point your shipped client at any server they like.
- **Release export** → override refused. This is what players get.

In the export dialog, **untick "Export With Debug"**. On the command line use
`--export-release`, never `--export-debug`.

Android is hard-blocked either way, but ship release there too — debug builds also enable
`OS.is_debug_build()` paths elsewhere in the client.

### Use a debug export deliberately, to test the packaged build

The editor proves your *code* works against staging. It does not prove the *packaged*
build does — import settings, resource filters and feature tags all differ. So:

```powershell
# Export the Windows preset WITH debug, to a scratch path, then:
.\PixelMania.exe -- --pixelmania-api-base https://staging-api.pixelmaniagame.com --pixelmania-ws-url wss://staging-api.pixelmaniagame.com/ws
```

Same `--` rule as the editor run args. This is the only way to test a real build against
staging — and it does **not** work for Android, so an `.aab` can only ever be tested
against production (use Play's internal testing track).

---

## 1. Pre-flight on the project

- [ ] **`project.godot` → `run/main_scene = "res://Scenes/ui/login/LoginScene.tscn"`.**
      If this is `main.tscn`, the shipped game boots to a grey screen with no errors. This
      broke the editor on 2026-08-06 — do not let it reach an export.
- [ ] **`editor/run/main_run_args` is empty.** Editor-only so it can't affect the export,
      but leaving staging URLs in a tracked file invites confusion.
- [ ] **Decide what ships.** An export packages your *working tree*, not your last commit.
      `git -C G:\PixelMania\pixel-mania status --short` — anything uncommitted (water
      system, wearable work) will be in the build. Commit or stash deliberately.
- [ ] **`export_presets.cfg` is committed** if you changed it.
- [ ] Release keystore configured for Android (Godot 4.4+ keeps credentials in
      `export_credentials.cfg` — that file must stay **out of git**).

## 2. Versions — two different numbers, both matter

**`CLIENT_VERSION` in `Scripts/network_manager.gd`** (currently `1.0.4`) is the protocol
gate the server checks. **`version/name` / `version/code` in the Android preset**
(currently `1.0.9` / `10`) are store metadata. They are unrelated; don't try to keep them
equal.

- [ ] Bump `CLIENT_VERSION` if anything on the wire changed.
- [ ] Bump Android `version/code` — **every** Play upload needs a higher one. `version/name`
      is what players see.

Server-side feature gates read `CLIENT_VERSION`, so it decides which optimisations a
player gets:

```
WORLD_STATE_STREAM_MIN_CLIENT_VERSION=1.0.4
PLAYER_POSITION_BATCH_MIN_CLIENT_VERSION=1.0.3
WORLD_UPDATE_BATCH_MIN_CLIENT_VERSION=1.0.3
```

### Never raise `MIN_CLIENT_VERSION` before players have the build

Production currently advertises `server_client_version 1.0.1` and `min_client_version 1.0.1`
— permissive on purpose. `MIN_CLIENT_VERSION` is a hard lockout: anyone below it cannot
play. Android updates roll out over days and need store review, so:

1. Ship the client. Wait for adoption.
2. **Then** raise the minimum:

```powershell
.\promote_staging_to_production.ps1 -ForceClientUpdate -ClientVersion 1.0.5 -MinClientVersion 1.0.1
```

Raising `-MinClientVersion` to a version most players don't have yet locks them out of your
game. Treat it as a separate, later, deliberate step.

## 3. Order of operations for a release that changes both sides

Server first, client second — an old client must keep working against the new server, which
is why `MIN_CLIENT_VERSION` lags:

1. Server change → staging → test → `promote_staging_to_production.ps1` (see
   `PixelManiaServer/staging/WORKFLOW.md`).
2. Debug export → test the packaged client against **staging**.
3. Release export → test against **production**.
4. Publish (Play internal track first).
5. Later, once adoption is there, raise `MIN_CLIENT_VERSION`.

If a client change needs a *new* item, remember the server-side entry in
`PixelManiaServer/src/server_item_database.ts` plus `npm run build:item-data`, or the
release gate refuses to ship.

## 4. Export

**Windows**

- Export dialog → `Windows Desktop` → **untick Export With Debug** → export to
  `G:\Test\PixelMania.exe`.
- Or headless: `godot --headless --export-release "Windows Desktop" G:\Test\PixelMania.exe`

**Android**

- Export dialog → `com.pixelmania.game` → **untick Export With Debug** → `G:\Test\PixelMania.aab`
- Or headless: `godot --headless --export-release "com.pixelmania.game" G:\Test\PixelMania.aab`
- Only `arm64-v8a` is enabled. That's the right default for the Play Store today, but it
  excludes 32-bit-only devices — enable `armeabi-v7a` if you want them.

## 5. Verify the built artifact before publishing

- [ ] Launch the release `.exe`. It must reach the **login screen**, not a grey window.
- [ ] Confirm it connects to production: `Connecting to PixelMania server: wss://api.pixelmaniagame.com/ws-a`.
- [ ] Confirm the override is dead — launching with
      `-- --pixelmania-api-base https://staging-api.pixelmaniagame.com` must **still** connect
      to production. If it goes to staging, you exported a debug build. Do not publish it.
- [ ] Log in, join a world, place and break a block, rejoin — the same acceptance test used
      for staging.
- [ ] Android: upload to the **internal testing** track and run the same test on a real
      device before any wider rollout.

## 6. Rollback

There is no server-side rollback for a shipped client — once players have it, they have it.
Your levers are:

- Roll back the **server** (`.\rollback_release.ps1 68.183.141.114`) if the server side is
  at fault.
- Publish a fixed client and raise `MIN_CLIENT_VERSION` to force the update, accepting that
  it locks out anyone who hasn't updated.
- `UPDATE_URL` (default `https://pixelmaniagame.com`) is what the client points players at
  when it's below the minimum. Make sure it actually offers the new build before you raise
  the gate.
