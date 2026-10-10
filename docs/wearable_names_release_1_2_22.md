# Wearable name corrections — production 1.2.22

Released 2026-10-09. These are display-name changes only; item IDs, owned items,
atlas cells, animations and Hair Pack probabilities are unchanged.

| Previous name | New name | Preserved item ID |
| --- | --- | --- |
| Sunflower Cap | Construction Hat | `sunflower_cap` |
| Ginger Pigtails | Brown Pigtails | `ginger_pigtails` |
| Ginger Ponytail | Brown Ponytail | `ginger_ponytail` |
| Chestnut Curtains | Black Stylish Hair | `chestnut_curtains` |
| Chestnut Bob | Black Mid Hair | `chestnut_bob` |

Client build source: `1a7b34e9af4fda774c3c2c8e073020f0f0a9e69e`.
Backend commit: `6acf01a`. Production release:
`20261009-wearable-names-6acf01a`; rollback target:
`20261009-wearables-a4de867`.

All five names were read back from the production item database. Main port 8080
and routes 18091/18092 report 1.2.22, minimum 1.2.14, and healthy PostgreSQL/Redis.
The full backend security gate, catalog synchronization, exact client/server
display-name check and existing wearable animation regression passed. Packaged
Windows startup connected to production without script/resource-load errors.

Production PC latest version is 1.2.22. Its existing minimum remains 1.2.21:
automatic approval review rejected raising that minimum, so publication preserved
it. The unchanged launcher was verified by SHA-256 and reused. A real launcher
download, checksum verification and installation test passed for exactly 1.2.22.
ZIP SHA-256: `55b61d5c515b9f6590f0d2d748c1141e001d9baf6d100eee239b9b4f321f98e4`.

Artifacts are in `D:/Pixelmania/PixelMania/release_artifacts/client-1.2.22/`.
Signed Android APK/AAB are version 1.2.22/code 44, prepared but not uploaded to
Google Play. Signatures, APK package/version and the unchanged signing certificate
were verified. Temporary signing credentials were removed. The Android manifest
remains 1.2.6. Physical-device testing was not performed.

Unrelated pending fishing changes and temporary files were excluded and remain
in the main workspaces. The complete original item/atlas mapping is recorded in
[the 1.2.21 release note](wearables_release_1_2_21.md).
