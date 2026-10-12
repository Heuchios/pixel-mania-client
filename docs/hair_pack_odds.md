# Hair Pack odds

2026-10-12: Hair Pack awards one hair per purchase. The server owns the roll;
the client catalog and generated shop disclosure use the same probabilities.

| Reward | Chance per pack |
| --- | --- |
| Flaming Hair | 1% |
| Frosty Hair | 1% |
| Supernova Hair | 1% |
| Baby Hair | 0.1% |
| Each of the other fourteen hairs | 6.9214285714% |

The other hairs split the remaining 96.9% equally. All eighteen rewards remain
available. Weights total 14,000: the three 1% hairs each have 140, Baby Hair
has 14, and each common hair has 969.

`scripts/check_hair_pack_odds.js` exhausts all 14,000 integer outcomes through
the compiled server sampler and verifies the requested rates, every reward's
interval and source/runtime parity. The client `hair_pack_catalog_test.gd`
checks equipped art, icons and matching shop odds for all eighteen rewards.

## Verified staging release

- Backend `08f19429999f` is active as `20261012-hair-odds-08f1942`.
- Client catalog/disclosure source `a80a8269` is pushed to staging.
- Full `npm run check:security`, client catalog and generated disclosure checks
  passed. The deployed server independently passed all 14,000 sampler outcomes.
- Public staging smoke and release-ID verification passed. Current/minimum
  client version remains 1.2.25. Published binaries have not changed.
- Rollback release: `20261012-weekly-quests-c81facd`.
- Evidence: `D:/Pixelmania/work/hair-pack-release/security.log`, `deploy.log`,
  and `staging-health.json`.
