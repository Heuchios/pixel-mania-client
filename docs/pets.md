# Pets

Craft an Incubator at the Crafting Station with 20 Wooden Blocks, 20 Glass and
20 Steel Blocks. Chickens now have a 2% Golden Egg chance, up from 1%.

Insert a Golden Egg into an Incubator. It hovers while incubating, the machine
uses atlas frames (15,16) through (20,16), and hovering displays time remaining.
The output slot displays the completed pet; Claim moves it into inventory.

All pets hatch at level 1. Hatch probabilities are Frog 40%, Blue Slime 25%,
Caveman 18%, Fluffy Puppy 11%, Ladybug 5% and Robot 1%. Ladybug is ultra rare and
Robot is legendary. Each species uses its row in Assets/items/pets.png.

Pets have their own pet inventory and equipment slot in the Gear tab.
Double-click/double-tap a pet in inventory, or use its Equip button. Ground pets
walk, jump and fall behind the player. Ladybugs and robots fly. Pets also animate
when their player punches; robots emit smoke during that animation. Other players
receive the equipped pet through the existing equipment synchronization.

Local and remote followers render above block visuals, vending/display previews,
fences and water. UI panels remain above pets.

At a Sashimi Table, select a fish and the number of chunks to chop. Each chunk
consumes exactly 50 kg (500 inventory tenths). Partial kilograms are preserved.
Fish Chunks stack to 10,000.

Insert a pet into an Incubator, add chunks and press Upgrade. Level 1 to 2 costs
250 chunks; level 2 to 3 costs 750. Level 3 is the maximum. Before starting an
upgrade, Remove refunds the pet and stored chunks. Running incubation must finish
before claiming. Only the account that inserted the contents can change them.
An occupied Incubator cannot be broken.

Hatching and upgrading each take one day in production and one minute under the
staging service account. Server timestamps survive offline time and restarts.

An equipped pet encounters one randomly selected item every five minutes:

| Level | Encounter pool |
| --- | --- |
| 1 | Stick |
| 2 | Stick, Earth Fragment |
| 3 | Stick, Earth Fragment, Fly, Sun Fragment, Moon Fragment, Star Fragment |

The initial encounter pools are shared by all six species. Equipping a different
pet does not reset the account cooldown. Offline time stores at most one ready
encounter, and the server grants exactly one item. Sticks and celestial fragments
are no longer extra Wood/Star Block break rewards.

Existing pets in material storage are migrated to equipment without changing their
counts or PM-ITEM identities.

Pet input/output and chunks commit with the world interaction in PostgreSQL.
Inventory and tile locks serialize mutations. Stored pets use an Incubator item
instance location and preserve their PM-ITEM public identity across upgrades and
refunds. Each upgrade leaves an item instance event, and successful/failed economy
actions leave ledger evidence. A failed transaction restores the Incubator.

Validation: `npm run check:pets`, `npm run test:pets-postgres` (with PGlite), the
server security suite, and Godot `res://tests/pets_test.gd`. Pass `--render-pets`
as a user argument to that test for panel screenshots.
