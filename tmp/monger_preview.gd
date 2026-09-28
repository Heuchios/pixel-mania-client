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
	var row = ui.fish_rows_root.get_child(0)
	row.get_node("HalfButton").pressed.emit()
	assert(row.get_node("AmountInput").text == "6")
	row.get_node("AmountPlus").pressed.emit()
	assert(row.get_node("AmountInput").text == "7")
	row.get_node("AmountMinus").pressed.emit()
	assert(row.get_node("AmountInput").text == "6")
	row.get_node("MaxButton").pressed.emit()
	assert(row.get_node("AmountInput").text == "12")
	row.get_node("SellButton").pressed.emit()
	assert(world.fish_monger_manager.sold == [["fish_0", 12.0]])
	ui.sell_all_button.pressed.emit()
	assert(world.fish_monger_manager.sold.size()==2)
	viewport.size = Vector2i(800,600)
	await create_timer(0.3).timeout
	assert(ui.panel.position.x >= 0 and ui.panel.position.y >= 0)
	assert(ui.panel.position.x + ui.panel.size.x * ui.panel.scale.x <= 800)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/fish-monger-compact.png")
	world.fish_monger_manager.pending_transaction = true
	ui.refresh()
	await process_frame
	assert(ui.sell_all_button.disabled)
	assert(ui.fish_rows_root.get_child(0).get_node("SellButton").disabled)
	world.fish_monger_manager.entries.clear()
	ui.refresh()
	assert(ui.empty_label.visible)
	ui.close_fish_monger()
	assert(not ui.visible)
	print("[fish-monger] layout, quantities, sale callbacks, pending and empty states passed")
	quit()
