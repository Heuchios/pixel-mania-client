# Trade review, chat layout and version enforcement — 1.2.25

Both parties enter a final five-second review after their first trade approvals.
The server sets the deadline and refuses early final accepts from either party;
client-supplied deadlines do not affect it. The final window shows a disabled
countdown button, starting from its actual display time using a monotonic client
clock. Repeated state packets do not restart the timer. Editing/cancelling clears
review state; missing server review state fails closed with a fresh review.

Local and remote chat bubbles now share one screen-space placement pass. Whole
panels avoid each other, preferring space above or beside their speakers and
remaining within the viewport. Overflow artwork is temporarily suppressed while
its lifetime and anchor remain active, then restored when room becomes available.
The existing text wrapping and camera-position stability remain in use.

Older releases were admitted by outdated compatibility minimums, rather than a
missing version check: production server minimum 1.2.14, desktop manifest 1.2.21,
Android manifest 1.2.6, with current server/desktop at 1.2.24. The server already
checks versions before authenticated actions. Malformed numeric version cores
now fail closed as well. Release minimums must be raised alongside distribution
of the installable update; a platform label alone must never bypass the server
minimum.

Android's existing update screen opens Google Play. Its public release manifest
still advertises 1.2.6. Availability of a newer Play release has been requested
from the user and has not yet been confirmed. Do not claim Play availability or
pass `play_available=yes` without that confirmation. This request explicitly
supersedes earlier instructions to preserve old compatibility floors, once the
update distribution target is known.

## Validation

- Server review tests reject both parties at 0, 1000 and 4999 ms, ignore forged
  deadlines, preserve the original deadline on retries, and accept at 5000 ms.
- Client trade review: 14 checks, including countdown text fitting the button,
  duplicate state, acceptance, editing, restarting and cancellation.
- Chat collision layout: 36 checks across desktop/phone viewport sizes, edge
  placement, stable positions, expiry, crowded-screen suppression and recovery.
- Existing chat text layout, update gate, 189 remote-hand checks and partial
  player-state regressions pass.
- Actual phone-sized chat and trade panels were rendered and visually inspected.
- Full backend `npm run check:security` passed.

Release source version is 1.2.25 / Android code 47. Deployment and final artifact
verification are recorded after completion; this document is not evidence that
production has been updated.
