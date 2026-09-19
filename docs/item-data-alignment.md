# ITEM DATA alignment

Source: [ITEM DATA](https://docs.google.com/spreadsheets/d/1PJLhG99ik5hVTQNTC29gizhC1nSvb3enpCMKma2uumU/edit#gid=0).

364 named rows mapped (includes visual-state rows and repeated sheet entries); 540 block/item/seed override entries. Hanging Spike uses Spike (`saw_blade`). User-excluded rows are recorded in `item-data-exclusions.json`. Blank cells and dashes are left unspecified. ITEM DATA tiers take priority over older SPLICING tiers. Backgrounds remain on the background layer; BOTH means one-way platform collision.

Gem averages from the bulk columns are applied to 251 block/item states: the integer part is guaranteed and the fractional part is the chance of one extra gem. Block and seed probabilities and special-reward probabilities are preserved. See item-gem-rates.json for the per-item audit. Sun has conflicting duplicate rates (8.5, 9, 9.5) and remains unchanged; the open wooden treasure chest retains its special reward rules. Tree harvest drops are unchanged. Newly registered seeds use existing default growth time when no duration is supplied; no new splicing recipes were invented.

Toxic Barrel scatters up to 20 randomly selected empty, accessible cells in a 10×10 region when broken. Waste is solid, deals Lava-style contact damage, breaks in one hit, drops nothing, and can be removed without world/area access. Spread is recorded in the same world transaction as the barrel break and broadcast only after commit.

## Remaining rows

- Row 362, **Metal gate (open)**: Missing item or visual-state row; requires mapping.
- Row 702, **The girl with pearl earrings**: Missing item or visual-state row; requires mapping.
- Row 752, **Hellbrick wall**: Invalid collision value: Hot brick wall..

Small/Medium/Big/Huge Gem refer to currency denominations rather than four distinct inventory IDs; their gem values were not changed. Names such as Plant 1 are unresolved placeholders. Missing artwork, item IDs, and special-drop probabilities were not invented.
