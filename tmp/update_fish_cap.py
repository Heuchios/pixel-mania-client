from pathlib import Path
c=Path('D:/Pixelmania/PixelMania/pixel-mania'); s=c.parent/'PixelManiaServer'
def edit(p,a,b):
 t=p.read_text(encoding='utf-8'); assert a in t,(p,a); p.write_text(t.replace(a,b),encoding='utf-8')
edit(c/'Scripts/ui/pixel_ui_style.gd','var base_size := int(label.get_meta("slot_count_base_size", label.get_theme_font_size("font_size")))','var base_size := 24')
for p in [c/'Scripts/item_database.gd',s/'src/server_item_database.ts']:
 import re
 t=p.read_text(); t=re.sub(r'("(?:stack_limit|max_stack)"\s*:\s*)20000',r'\g<1>9990',t);p.write_text(t)
edit(c/'Scripts/world.gd','return 20000 # Exact tenths of a kilogram: 2000 kg.','return 9990 # Exact tenths of a kilogram: 999 kg.')
# Preserve legacy fish holdings when reading authoritative saved data.
edit(c/'Scripts/world.gd','return int(clamp(count, 0, get_stack_limit_for_item(item_type, category)))','return int(clamp(count, 0, 20000 if category == "fish" else get_stack_limit_for_item(item_type, category)))')
edit(c/'Scripts/world.gd','var stack_limit = get_stack_limit_for_item(item_type, category)\n\tvar current_count','var stack_limit = 20000 if category == "fish" else get_stack_limit_for_item(item_type, category)\n\tvar current_count')
edit(c/'Scripts/fishing_manager.gd','owned_before + catch_weight > 2000.0','owned_before + catch_weight > 999.0')
edit(c/'Scripts/fishing_manager.gd','Fish stacks hold 2000 kg.','Fish stacks hold 999 kg.')
edit(c/'Scripts/fishing_manager.gd','mini(20000, current_count + _fish_weight_to_tenths(safe_weight))','mini(9990, current_count + _fish_weight_to_tenths(safe_weight))')
edit(c/'Scripts/ui/inventory_scene.gd','%.1f / 2000 kg','%.1f / 999 kg')
edit(c/'Scripts/inventory_manager.gd','var current_count: int = get_item_weight_tenths(item_id)\n\tworld.fish_inventory[item_id] = current_count + add_count','var current_count: int = get_item_weight_tenths(item_id)\n\tif current_count + add_count > 9990:\n\t\treturn false\n\tworld.fish_inventory[item_id] = current_count + add_count')
edit(s/'src/server_fish_market.ts','export const STACK_LIMIT = 20000;','export const STACK_LIMIT = 9990;\n// Read legacy holdings without truncating them; new additions use STACK_LIMIT.\nexport const LEGACY_HOLDING_LIMIT = 20000;')
edit(s/'src/server_fish_market.ts','amount > STACK_LIMIT','amount > LEGACY_HOLDING_LIMIT')
edit(s/'src/server.ts','Fish stacks hold 2000 kg.','Fish stacks hold 999 kg.')
edit(s/'src/server.ts','up to 2000 kg.','up to 999 kg.')
# Incoming additions must fail rather than clamp away a legacy holding.
edit(s/'src/server.ts','const currentCount = clampInteger(state[inventoryField][cleanItemId] || 0, 0, stackLimit);','const currentCount = getInventoryCount(state, cleanItemId, resolvedCategory);\n  if (resolvedCategory === "fish" && currentCount + Number(amount) > stackLimit) return null;')
p=s/'src/server_player_state_helpers.ts';t=p.read_text();t=t.replace('itemDatabase.getStackLimit(cleanItemId));','(resolvedCategory === "fish" ? FishMarket.LEGACY_HOLDING_LIMIT : itemDatabase.getStackLimit(cleanItemId)));');t=t.replace('safe[itemId] = clampInteger(rawCount || 0, 0, itemDatabase.getStackLimit(itemId));','safe[itemId] = clampInteger(rawCount || 0, 0, resolvedCategory === "fish" ? FishMarket.LEGACY_HOLDING_LIMIT : itemDatabase.getStackLimit(itemId));');p.write_text(t)
# PostgreSQL validates additions using the new cap; existing excess remains removable.
edit(s/'src/postgres_store.ts','const stackLimit = Math.max(existingStackLimit, requestedStackLimit);','const stackLimit = resolveItemCategory(' + 'PLACEHOLDER' + ') === "fish" ? requestedStackLimit : Math.max(existingStackLimit, requestedStackLimit);')
p=s/'src/postgres_store.ts';t=p.read_text();t=t.replace('resolveItemCategory(PLACEHOLDER)', 'resolveItemCategory(deltaEntry.item_type)',1);t=t.replace('resolveItemCategory(PLACEHOLDER)','resolveItemCategory(itemType)');t=t.replace('if (afterAmount > stackLimit) {\n            return InventoryContracts','if (afterAmount > stackLimit && !(deltaEntry.item_category === "fish" && deltaEntry.delta <= 0)) {\n            return InventoryContracts');p.write_text(t)
edit(s/'scripts/test_fish_market.js','Market.kgToUnits(2000), 20000','Market.kgToUnits(999), 9990')
edit(s/'scripts/test_fish_market.js','5.71, 2000.1','5.71, 999.1, 2000.1')
edit(s/'scripts/test_fish_market.js','definition.stack_limit, 20000','definition.stack_limit, 9990')
edit(c/'tests/fish_kilograms_test.gd','2000.0 / 2000 kg','2000.0 / 999 kg')
edit(c/'tests/fish_kilograms_test.gd','== 20000, "real world stack limit supports 2000 kg"','== 9990, "real world stack limit supports 999 kg"')
edit(c/'tests/slot_weight_label_test.gd','[791, 1569, 883, 20000, 1, 791]','[791, 1569, 883, 9990, 20000, 1, 791]')
