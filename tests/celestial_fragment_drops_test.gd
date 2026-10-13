extends SceneTree
const DB = preload("res://Scripts/item_database.gd")
const Contract = preload("res://Scripts/item_data_contract.gd")
const Gameplay = preload("res://Scripts/item_gameplay_manager.gd")
class DropWorld extends RefCounted:
 const MAX_ITEM_STACK_SIZE = 400
 var item_database: Dictionary
 var drops: Array = []
 func create_item_drop(id, _position, _seed, category, _delay, amount):
  drops.append({"id":id,"category":category,"amount":amount})
func _init():
 var fixture := DropWorld.new()
 fixture.item_database = Contract.apply(DB.ITEMS.duplicate(true))
 var manager := Gameplay.new()
 manager.world = fixture
 var rules: Dictionary = fixture.item_database.star_block.drop_rules.duplicate(true)
 var pool: Dictionary = {}
 for entry in rules.fixed_drops:
  if entry.has("loot_table"): pool = entry
 assert(pool.chance == 0.01 and pool.loot_table.size() == 3)
 # Force each outcome while retaining actual normal break rewards.
 pool.chance = 1.0
 fixture.item_database.star_block.drop_rules = rules
 for selected in ["star_fragment", "sun_fragment", "moon_fragment"]:
  for entry in pool.loot_table: entry.weight = 1 if entry.item_id == selected else 0
  fixture.drops.clear()
  assert(manager.try_drop_fixed_break_drops("star_block", Vector2.ZERO))
  var fragments := fixture.drops.filter(func(d): return d.category == "material")
  assert(fragments.size() == 1 and fragments[0].id == selected and fragments[0].amount == 1)
  assert(fixture.drops.any(func(d): return d.id == "gem"))
 manager.free()
 print("CELESTIAL_DROPS_PASS: one shared pool, all three outcomes, ordinary rewards retained")
 quit()

