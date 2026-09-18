# Recipe book and spreadsheet tiers

Implemented against the SPLICING snapshot in `live-recipe-sheet.json`, read September 18, 2026.

- Available spreadsheet recipes use their authored tier on both the client and server, including corresponding seeds. Tiers do not change growth times or drop rules.
- The book contains 149 splicing recipes, 4 crafting-table recipes, and 3 furnace recipes. Red spreadsheet rows appear only under crafting.
- Eight retained splicing recipes without a spreadsheet tier appear under Other. Untiered furnace recipes also use Other.
- The book supports method selection, tier tabs, category filters, ingredient/name search across tiers, clickable ingredient recipes, and Used For navigation across methods. Counts reflect actual results; empty placeholder slots are removed.
- Unavailable and conflicting spreadsheet rows remain documented in `splicing-recipe-report.md`. They are not presented as playable recipes.

Validation: server item-data build, TypeScript checks, recipe uniqueness/source parity audit, Godot recipe-book runtime tests, furniture regression tests, and a rendered recipe-book preview passed. Runtime tests cover authored tiers, method separation, search, recipe links, icons, counts, and repeated tier-tab switching.

Release status is recorded by Git history and the deployment manifests.
