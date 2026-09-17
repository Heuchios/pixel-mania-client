# Google Play Gem Store

Installed official GodotGooglePlayBilling 3.3.0 (Billing Library 9.1.0), including
debug/release AARs and MIT license. Source and release:
https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0
Release ZIP SHA256: `20D75623D6F337F08D8283C83098B73678D5F575E39247AF5A8EB80588B18568`.
The only vendor-script change removes `class_name BillingClient` to avoid colliding
with PixelMania's autoload of the same name. Keep this change when upgrading.

The editor plugin is enabled in project.godot. The Android preset already uses
Gradle; minimum SDK is now 23. Both Android AAR variants are provided by the
editor export plugin; no legacy .gdap checkbox is needed. Install the matching
Godot Android build template before exporting. Keep the existing package ID
`com.pixelmaniagame.pixelmania`, signing configuration and version settings.

`Scripts/billing_client.gd` starts the native connection, queries INAPP products,
and requires fresh username binding for each checkout. This deliberately preserves
the existing server's username account-binding contract. Do not change to a hash
without coordinating the backend verifier. The shop calls this autoload and
keeps its Stripe path and server-result notifications.

Completed receipts use the existing NetworkManager request with exactly
`pack_id`, `purchase_token`, `product_id` and its generated request ID. Pending,
unknown and malformed products are not submitted. The server remains responsible
for receipt verification, account checks, idempotency, gem ledgers and grants.
Only a matching successful server response permits native consumption, making
packs purchasable again. No client gem balance is changed. Retained purchases
are queried on connection, resume and every 60 seconds for recovery after login
or a lost response. Consumption failures leave purchases available for retry.

## Safe local test

Run from PowerShell:

```powershell
./tests/run_google_play_billing.ps1 -Godot D:/Godot/Godot_v4.7.1-stable_win64_console.exe
```

The runner copies only the necessary scripts to an isolated temporary project.
It does not start game autoloads or connect to a server. It checks all five
`gems_pouch`, `gems_sack`, `gems_chest`, `gems_vault`, `gems_mountain` requests,
INAPP type, account binding, invalid IDs, stale accounts, and consumption gating.
The explicit `purchase(product_id, true)` preview returns/emits the request and
exits before native checkout. It creates no receipt and grants no gems. There is
no persistent test-mode setting that could accidentally ship enabled.

## Device validation still required

Create/activate those exact five one-time products in the Play Console for the
existing package. Use the existing pack prices and quantities; the server owns
the actual awards. Upload a signed AAB to internal testing and install it through
Google Play using a license tester. Confirm each product loads, cancellation and
pending purchases grant nothing, verified purchases update the server balance,
and each pack can be purchased again after consumption. Test app restart and
network loss during verification. Configure the server's Play package and service
account credentials using the existing deployment process; no credentials belong
in this plugin. Local preview checks do not validate Play Console configuration,
Android packaging, or a real Google payment/receipt.
