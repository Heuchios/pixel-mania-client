# Farming balance

The authored source is `Data/items/farming_balance.json`. From the server repository, run `npm run build:farming-balance` to generate both copies of `item_data_overrides.json`, the full `farming-balance-report.json`, and the searchable `farming-guide.html`. `npm run check:item-data` checks generated-data parity and executes the real server reward roller in deterministic simulations. `tests/farming_balance_test.gd` verifies the client after legacy defaults, atlas merging, and seed generation.

## Normal farming

| Balance tiers | Block roll on break | Seed roll on break | Harvest blocks | Seed roll on harvest | Seeds per complete cycle |
|---|---|---|---|---|---|
| 1–3 | 30% for 1–3 | 15% for 1 | 1–3, guaranteed | 35% for 1 | 1.10 |
| 4–6 | 25% for 1–3 | 20% for 1 | 1–3, guaranteed | 30% for 1 | 1.10 |
| 7–9 | 20% for 1–3 | 24% for 1 | 1–3, guaranteed | 25% for 1 | 1.05 |
| 10–14 | 15% for 1–3 | 28% for 1 | 1–3, guaranteed | 25% for 1 | 1.05 |

Rolls are independent; quantity ranges are uniform integers. A complete cycle plants one seed, harvests its tree, and repeatedly places and breaks every returned block until none remain. Keep one returned seed to replant. These are long-run averages, not guaranteed returns for one tree: small farms can still lose seeds through bad luck, and splicing consumes extra seeds outside this calculation.

If `B` is mean harvested blocks, `R` is mean returned blocks per break, `S` is mean seeds per break, and `T` is mean tree seeds, expected seeds per cycle are `T + B*S/(1-R)`. Normal break returns average 0.3–0.6 blocks, so the repeated-breaking loop terminates in expectation and cannot print unlimited blocks/gems from a guaranteed block return.

The imported sheet's bulk gem totals are interpreted as expected totals, not probabilities or guarantees. A mean of 0.2 pays 1 gem with 20% probability. A mean of 2.5 pays 2 gems plus an independent 50% chance of 1 extra. Tree gem means are twice their block-break means. The report lists both separately.

## Growth and exceptions

- Preserve existing valid imported item growth durations, including multi-day endgame trees. Fill missing durations using the explicitly recorded tier defaults. Obsidian uses the screenshot's 30 seconds. Balance tiers assigned to previously unranked farmable items do not change their recipe tier or recipes. No current farmable items occupy tier 12.
- Pinball now uses its imported 6h 25m duration. CCTV and Snow Repellent replace generic 150-second placeholders with their 12-hour and 6-hour tier defaults. Other explicitly configured catalog durations are retained and distinguished from imported sheet values in the report.
- Minerals that explicitly suppress seeds when broken retain that behavior. Their trees instead return one guaranteed seed plus a 5–10% chance of another, preserving the same sustainable target.
- Direct inventory-return items give no break gems/seeds. Shifty Block's existing plantable seed harvests one block, one seed, and a 5% chance of an extra seed; it gives no farming gems.
- Death Gate, Display Shelf, and Star Checkpoint still return their block when broken, but no longer also pay repeatable gems. Their old guaranteed block-plus-gem rules allowed unlimited place/break payouts.
- Toggle/placed artwork states copy their base item's reward rules, preventing a better drop rate from an active/open variant. Their reported tree time refers to the base seed, not a new state-specific tree.
- Water has no seed or tree. Bucket placement and scooping produce no rewards. Its old 0.5-gem break entry is explicitly removed so freely reusable water cannot become a gem source. The screenshot's water tree time cannot apply to the current game's non-plantable water.
- Bedrock and the entrance gate remain unbreakable. Non-growable utilities and treasure use explicit existing recovery/loot behavior, with no invented tree times. Existing non-farming material rewards, such as wheat, remain intact.
- Landfill event tickets, equipment boosts, machine production, XP, and any other runtime bonuses are outside the baseline report and are unchanged.
- Already planted trees retain their saved maximum growth time. The new configured duration is used by newly planted trees; there is no live-world tree migration.

The guide and report describe this release's configured baseline. A server must run this release before these values apply there. Previously exported workbooks are snapshots of the balance at the time they were generated.
