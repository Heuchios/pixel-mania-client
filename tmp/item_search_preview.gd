extends SceneTree
class Catalog extends Node:
	var item_database := {}
	func get_inventory_icon_texture(_id, _category): return load("res://Assets/items/fish/pond_fish_small.png")
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,900)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui = load("res://tmp/dev_layout_fixture.gd").new()
	viewport.add_child(ui)
	var world := Catalog.new()
	viewport.add_child(world)
	world.item_database={"wooden_fishing_rod":{"display_name":"Wooden Fishing Rod","category":"tool","rarity":"common"},"bamboo_fishing_rod":{"display_name":"Bamboo Fishing Rod","category":"tool","rarity":"uncommon"},"platinum_rod":{"display_name":"Platinum Rod","category":"tool","rarity":"epic"},"hidden_rod":{"admin_grantable":false},"legacy_rod":{"legacy_item_id":true}}
	ui.world=world
	ui.build_panel()
	ui.update_layout()
	ui.status_label.text="Role: admin | Server verified"
	ui._on_tab_pressed("items")
	ui.item_search_input.text="rod"
	ui.item_search_input.text_changed.emit("rod")
	assert(ui.item_search_list.get_child_count()==3)
	ui.item_search_list.get_child(0).get_node("SelectItem").pressed.emit()
	assert(not ui.item_input.text.is_empty())
	assert(ui.item_search_list.get_child(0).get_node("SelectItem").text=="SELECTED")
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/item-search-updated.png")
	ui.item_search_input.text="zz_nomatch"
	ui.search_items()
	assert(ui.item_search_list.get_child_count()==1)
	assert(ui.item_search_list.get_child(0) is Label)
	ui.item_search_input.clear()
	ui.search_items()
	assert(ui.item_search_list.get_child_count()==1)
	print("[item-search] live search, selection, hidden items, empty and no-match passed; no admin commands executed")
	quit()
