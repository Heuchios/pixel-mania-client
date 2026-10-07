# Farming drop rates and sheet comparison

The readable report is `docs/farming-guide.html`: all 332 blocks/states, searchable by name/ID and tier, with per-item before/current/source comparisons and review flags.

The authored runtime source is `Data/items/farming_balance.json`. The live reference was read on October 6, 2026 from Google spreadsheet `1PJLhG99ik5hVTQNTC29gizhC1nSvb3enpCMKma2uumU`, tab `ITEM DATA`, columns C–V. Relevant source fields are in `docs/item-sheet-reference.json`; matching decisions are in `docs/item-sheet-matches.json`. Match names and established IDs, never shifted row numbers alone.

## Interpretation confirmed by the user

- Listed block/seed ranges are independent uniform integer rolls for both breaking and harvesting. 0–3 blocks means 25% each for 0, 1, 2, or 3; 0–1 seeds means 50% each. Wagon Wheel uses 0–6 blocks and 0–3 seeds.
- Gem columns give expected gems per number of blocks broken. Integer payouts use the guaranteed floor plus a fractional chance for one extra gem. Sugarcane uses the user-confirmed 2.2 gems/break despite conflicting bulk totals in the sheet.
- Numeric sheet XP applies to block breaks. Harvest XP remains 3 when a mature harvest produces rewards, otherwise zero. Tree gem averages and growth times remain unchanged: the sheet has no separate tree gem/XP columns and this pass updates drops.
- Blank/dash fields and conflicting values are not treated as zero. Existing behavior is retained and flagged. Conflicting gem rows remain for Snow Leaf, Dark Brown Block, and Sun; Dark Brown Block also has conflicting XP.
- Special recovery, unbreakable blocks, water, and event/treasure behavior are preserved pending review. Placed/toggle states inherit their base block's rules and XP.

Uniform block rolls replace the former sustainable-farming probabilities wherever a numeric range is specified. A 0–3 roll averages 1.5 blocks per break, so repeated place/break cycles can increase supply. No finite full-recycling gem/seed expectation is reported when returned block mean is at least one. Older farming profiles remain defaults only for unspecified fields/items.

## Regeneration and verification

From the server repository, `node scripts/import_sheet_drop_rates.cjs` imports the checked-in reference snapshot and confirmed Sugarcane resolution. `npm run build:farming-balance` generates both runtime override copies, the current JSON report, gem-rate report, and HTML guide. `npm run check:farming-balance` checks parity and executes actual server reward rollers to verify zero outcomes, uniform distributions, gem means, XP, inherited variants, and retained special behavior. `node scripts/check_item_gem_rates.cjs` checks integer currency payouts. `tests/farming_balance_test.gd` verifies final Godot definitions after atlas/default merging.

`docs/item-sheet-comparison-baseline.json` is the pre-update snapshot. The legacy `docs/item-data-audit.json` provides historical name-to-ID aliases, not current rates. Do not import old audit rates over this update. Equipment bonuses, event tickets, machine production, and unrelated item properties are outside these baseline tables. Local settings take effect on a server only after deployment.
