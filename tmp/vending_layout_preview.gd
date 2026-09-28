extends SceneTree
class World extends Node:
	func get_item_display_name(id, _category): return id.capitalize()
	func get_item_texture(_id, _category): return load("res://Assets/items/fish/crystal_fish.png")
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1100,760)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	var ui = load("res://Scenes/ui/vending/VendingMachineGUI.tscn").instantiate()
	viewport.add_child(ui)
	ui.setup(world,viewport)
	ui.visible=true
	var listing={"listing_id":"preview","item_id":"crystal_fish","item_category":"fish","stock":100,"amount_per_sale":1,"price_wls":100}
	ui.apply_vend_state({"listing":listing,"can_manage":true,"pending_wls":125})
	ui.refresh_ui()
	await capture(viewport,"vending-owner")
	ui.apply_vend_state({"listing":listing,"can_manage":false})
	ui.refresh_ui()
	await capture(viewport,"vending-buyer")
	ui.apply_vend_state({"listing":{},"can_manage":true,"pending_wls":0})
	ui.refresh_ui()
	await capture(viewport,"vending-empty")
	viewport.size=Vector2i(800,600)
	ui.update_position()
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	await capture(viewport,"vending-compact")
	quit()
func capture(viewport, filename):
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
