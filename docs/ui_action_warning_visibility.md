# UI action errors and warnings

Prepared on 2026-10-12 for the pending client release; not deployed.

The shared notification path closes gameplay popups when showing an error or
warning. It uses the existing menu close methods so confirmations, selection
modes and keyboard focus are cleaned up. An active trade is canceled before
its local state is dismissed. Daily rewards and emote panels are now included
in the global close path. A player's active chat input/bubble no longer prevents
an action warning from appearing.

Failed inventory results carry an error context through their existing UI
handlers. Action rejections, trade errors and world-lock failures explicitly
request error feedback. Other local notifications use the shared classifier,
with error/warning wording taking priority over words such as trade, gem or
World Lock. Normal success/progress messages retain their existing behavior.
World-lock progress feedback is no longer represented as a failed result.

Validation:

- `ui_action_warning_test.gd`: 29 checks pass, including the actual world-lock
  scene and confirmation, real world/global-close routing, structured failures,
  trade cancellation, selection cleanup, chat suppression and successful shop
  purchases staying open.
- Trade review: 14 checks pass. Chat collision layout: 36 checks pass.
- Existing chat text layout, chat typing, display interaction and mobile Back
  menu checks pass. The older Back-menu fixture was missing the magnet and quest
  visibility methods expected by the existing input manager; its fixture now
  supplies those methods.

Logs: `D:/Pixelmania/work/ui-action-warning.log` and
`D:/Pixelmania/work/ui-warning-*.log`.

This requires a rebuilt client. Previously delivered 1.2.25 binaries predate
this change and have not been overwritten. Production publication and required
version changes remain pending the Android distribution decision.
