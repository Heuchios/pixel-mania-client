extends SceneTree

class WorldFixture extends Node:
	var item_database := {"appreciation_wings": {"category": "back"}, "world_lock": {"category": "block"}}

func _initialize(): call_deferred("run")
func run():
	create_timer(15).timeout.connect(func(): quit(1))
	var world := WorldFixture.new()
	var shop = load("res://Scripts/shop_ui.gd").new()
	shop.world = world
	var listing: Dictionary = shop.get_shop_item_entry("appreciation_wings")
	assert(listing.price == 0 and listing.amount == 1 and listing.once_per_account)
	assert(shop.get_featured_shop_entries().any(func(item): return item.get("item_id") == "appreciation_wings"))
	world.set_meta("shop_claims", ["appreciation_wings"])
	assert(shop.get_shop_item_entry("appreciation_wings").is_empty(), "Claimed gift cannot be bought again")
	assert(not shop.get_shop_items_for_category("clothes").has(listing), "Claimed gift disappears from category")
	assert(not shop.get_featured_shop_entries().any(func(item): return item.get("item_id") == "appreciation_wings"), "Claimed gift disappears from featured")
	world.set_meta("shop_claims", [])
	assert(not shop.get_shop_item_entry("appreciation_wings").is_empty(), "Another account can claim its own gift")
	shop.free()
	world.free()
	print("APPRECIATION_SHOP_PASS")
	quit()
