# Weekly quest gems

2026-10-12: the daily journal displays the server's 5,000-gem weekly quest
budget plus a 1,000-gem bonus, progress out of 28 claims, and the claimed bonus
state. The final daily claim includes the bonus automatically. Weeks run from
Monday 04:00 UTC to the following Monday 04:00 UTC.

Easy quests pay 100 gems; challenges pay 250 Monday-Saturday and 300 on Sunday.
This gives six 700-gem days plus one 800-gem day. Completing and claiming all
four quests on all seven days gives 6,000 gems total, plus the existing XP.
Storybook rewards remain separate. Existing claimed slots stay claimed;
unclaimed quests retain progress when adopting the new rewards.

The server owns amounts, eligibility and payouts. All currency, quest state,
ledgers and unique daily/weekly receipts commit in one PostgreSQL transaction.
The UI never grants gems. Old server snapshots retain the legacy footer until
the matching backend is deployed.

Validation: quest engine tests cover full and incomplete weeks, reset boundaries,
legacy state and reward-only migration. The isolated SQL suite verifies exactly
6,000 gems and matching ledger totals, rollback, repeat requests and the unique
weekly receipt. The rendered Godot journal test covers weekly progress, claimed
state, combined reward confirmation and narrow layout.

## Staging release

- Active backend release: `20261012-weekly-quests-c81facd`, commit `c81facd051d4`.
- Matching client source: `725f2fe5` (journal and short-screen layout), pushed to staging.
- Previous backend/rollback: `20261012-helmet-cover-72ff82f`.
- Full `npm run check:security`, quest engine/route checks, isolated PostgreSQL
  regression and rendered journal test passed. The deployed engine independently
  returned 5,000 regular gems plus 1,000 bonus; another board read paid zero.
- Public staging smoke passed; PostgreSQL and Redis are ready. Current/minimum
  client versions remain 1.2.25. Production and published binaries are unchanged.
- Evidence: `D:/Pixelmania/work/quest-weekly-security.log`,
  `quest-weekly-staging-deploy.log`, and `quest-weekly-mobile.png` in the same folder.

Restart the updated editor/debug client to load the new journal presentation.
