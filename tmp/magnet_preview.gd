extends SceneTree
class World extends Node:
	var item_database := {"dirt":{"category":"block"},"dirt_seed":{"category":"seed"},"fish":{"category":"fish"}}
	func get_item_display_name(id,_category): return id.capitalize()
	func get_inventory_icon_texture(_id,_category): return load("res://Assets/items/fish/pond_fish_small.png")
	func get_item_count(_id,_category): return 20
class Manager extends RefCounted:
	var states := {}
	var requests := []
	func request(action,grid,extra={}):
		requests.append([action,grid,extra])
		return true
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1100,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	var manager := Manager.new()
	var ui = load("res://Scripts/magnet_machine_ui.gd").new()
	viewport.add_child(ui)
	ui.setup(world,manager)
	ui.open(Vector2i(2,3))
	ui.apply_state({"item_id":"dirt","item_category":"block","count":2350,"building":true,"collecting":true,"can_manage":true},true)
	await capture(viewport,"magnet-updated")
	assert(ui.change.disabled)
	ui.quantity.get_line_edit().text="12"
	ui.deposit.pressed.emit()
	assert(manager.requests[-1][2].amount==12)
	var count=manager.requests.size()
	ui.send("magnet_withdraw",{"amount":2})
	assert(manager.requests.size()==count)
	ui.pending=false
	ui.apply_state({"item_id":"dirt","item_category":"block","count":0,"building":false,"collecting":false,"can_manage":true},true)
	ui._process(0)
	ui.show_picker()
	assert(ui.item_ids.size()==2)
	await capture(viewport,"magnet-picker")
	ui.search.text="dirt_seed"
	ui.fill_choices()
	assert(ui.item_ids==["dirt_seed"])
	ui.choices.item_selected.emit(0)
	assert(manager.requests[-1][0]=="magnet_select")
	ui.pending=false
	ui.apply_state({"item_id":"dirt","count":0,"can_manage":false},true)
	ui._process(0)
	assert(ui.deposit.disabled and ui.update.disabled and ui.change.disabled)
	viewport.size=Vector2i(800,600)
	ui._process(0)
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	await capture(viewport,"magnet-compact")
	print("[magnet] layout, typed quantity, pending guard, picker filtering, selection, permissions and fit passed")
	quit()
func capture(viewport, filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
