extends SceneTree
const UI = preload("res://Scripts/ui/fish_monger_ui.gd")
class Market extends RefCounted:
	var pending_transaction := false
	var entries: Array = []
	var sold := []
	func get_sellable_fish_entries(): return entries
	func sell_fish(id, amount): sold.append([id, amount])
	func sell_all_fish(): sold.append(["all"])
class World extends Node:
	var fish_monger_manager = Market.new()
	var currency_textures := {}
	var item_database := {"fish_monger": {"texture": "res://Assets/inventory_icons/fish_monger.png"}}
	func get_currency_display_text(_id): return "9,115,417"
func _init(): call_deferred("run")
func run():
	root.hide()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	for i in range(9):
		world.fish_monger_manager.entries.append({"item_id":"fish_"+str(i), "display_name":"Small Pond Fish" if i%2==0 else "Crystal Fish", "count":12 if i==0 else 1, "sell_value":2 if i%2==0 else 225, "rarity":"common" if i%2==0 else "legendary", "texture":load("res://Assets/items/fish/pond_fish_small.png" if i%2==0 else "res://Assets/items/fish/crystal_fish.png")})
	var ui := UI.new()
	viewport.add_child(ui)
	ui.setup(world, viewport)
	ui.open_fish_monger(Vector2i.ZERO)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/fish-monger-updated.png")
	assert(not ui.panel.has_node("ScrollBack"))
	assert(ui.fish_rows_root.get_child(0).get_node("IconBack").get_theme_stylebox("panel").get_meta("atlas_region") == "inv_slot_normal")
	print("[monger-slots] passed")
	quit()
