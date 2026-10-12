from pathlib import Path
s=Path('D:/Pixelmania/PixelMania/PixelManiaServer');c=s.parent/'pixel-mania'
def edit(p,a,b):
 t=p.read_text();assert a in t,(p,a);p.write_text(t.replace(a,b))
edit(s/'src/server_fish_market.ts','kgToUnits(value: unknown): number','kgToUnits(value: unknown, limit = STACK_LIMIT): number')
edit(s/'src/server_fish_market.ts','units <= STACK_LIMIT','units <= limit')
edit(s/'src/server.ts','FishMarket.kgToUnits(data.weight_kg)','FishMarket.kgToUnits(data.weight_kg, FishMarket.LEGACY_HOLDING_LIMIT)')
edit(s/'src/server.ts','amount > FishMarket.STACK_LIMIT','amount > FishMarket.LEGACY_HOLDING_LIMIT')
edit(s/'src/server.ts','Choose an owned weight in 0.1 kg steps, up to 999 kg.','Choose an owned weight in 0.1 kg steps.')
edit(s/'src/server_fish_market_store.ts','line.amount > Market.STACK_LIMIT','line.amount > Market.LEGACY_HOLDING_LIMIT')
edit(s/'src/postgres_store.ts','[playerId, deltaEntry.item_type, deltaEntry.item_category, afterAmount, stackLimit]','[playerId, deltaEntry.item_type, deltaEntry.item_category, afterAmount, Math.max(stackLimit, afterAmount)]')
edit(s/'scripts/test_fish_market.js','assert.equal(Market.kgToUnits(999), 9990);','assert.equal(Market.kgToUnits(999), 9990);\n  assert.equal(Market.kgToUnits(1500, Market.LEGACY_HOLDING_LIMIT), 15000);\n  assert.equal(Market.mergeSpecies({bass: 15000}).bass, 15000);')
edit(c/'tests/slot_weight_label_test.gd','verify(inventory.slot_nodes["fish:bass"], "Frame")','verify(inventory.slot_nodes["fish:bass"], "Frame")\n\t\tassert(hotbar.get_node("Slot_0/Count").get_theme_font_size("font_size") == inventory.slot_nodes["fish:bass"].get_node("Count").get_theme_font_size("font_size"), "Hotbar weight must match inventory typography")')
p=c/'docs/codex_handoff_status.md'; t=p.read_text(); t=t.replace('## Latest Verified Status','## Latest Verified Status\n\n### Fish stack cap and hotbar quantity consistency (2026-10-07, local)\n\nFish additions now cap at 999 kg (9990 integer tenths) in client, item definitions,\nserver catch/grant capacity and PostgreSQL inventory/pickup transactions. Legacy\nholdings up to the previous 2000 kg ceiling remain readable and sellable; no\nquantity migration or truncation is performed. Decreasing a grandfathered holding\nkeeps its stored constraint at least its remaining amount. Hotbar and inventory\nshare a 24px quantity baseline with measured fitting. Changes are not deployed.\n',1);p.write_text(t)
