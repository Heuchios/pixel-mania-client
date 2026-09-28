extends SceneTree
class World extends Node:
	var safe_states := {}
	var selecting := false
	func is_safe_item_selecting(): return selecting
	func end_safe_item_select(_close): selecting=false
	func begin_safe_item_select(): selecting=true
	func get_item_display_name(id, _category): return id.capitalize()
	func get_item_texture(_id, _category): return load("res://Assets/items/fish/crystal_fish.png")
	func get_inventory_icon_texture(id, category): return get_item_texture(id, category)
	func show_notification(_text): pass
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	var ui = load("res://tmp/safe_fixture.gd").new()
	viewport.add_child(ui)
	ui.setup(world,viewport)
	ui.open_safe(Vector2i(3,4))
	ui.apply_safe_state({"can_manage":true,"max_slots":10,"slots":[{"item_id":"crystal_fish","item_category":"fish","amount":48},{"item_id":"tail_of_trident","item_category":"fish","amount":2},{"item_id":"a_long_item_display_name","item_category":"material","amount":400}]})
	ui.refresh_ui()
	await capture(viewport,"safe-updated")
	ui.deposit_button.pressed.emit()
	assert(world.selecting)
	ui._on_slot_pressed(0)
	await capture(viewport,"safe-withdraw")
	ui.withdraw_popup.get_node("HALF").pressed.emit()
	assert(ui.get_withdraw_amount()==24)
	ui.withdraw_popup.get_node("MAX").pressed.emit()
	assert(ui.get_withdraw_amount()==48)
	var before=ui.requests.size()
	ui.withdraw_amount_input.text=""
	ui._confirm_safe_withdraw()
	assert(ui.requests.size()==before)
	ui.withdraw_amount_input.text="5"
	ui._confirm_safe_withdraw()
	assert(ui.requests[-1].amount==5 and ui.requests[-1].action=="safe_withdraw")
	ui._on_slot_pressed(0)
	ui.current_state.slots[0].item_id="changed_item"
	before=ui.requests.size()
	ui._confirm_safe_withdraw()
	assert(ui.requests.size()==before)
	ui.current_state.can_manage=false
	ui.refresh_ui()
	assert(ui.deposit_button.disabled and ui.slots_root.get_child(0).disabled)
	viewport.size=Vector2i(800,600)
	ui.update_position()
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	await capture(viewport,"safe-compact")
	ui.close_safe()
	assert(not ui.is_safe_open())
	print("[safe] deposit, quantity shortcuts, invalid input, withdrawal payload, changed slot, owner access and fit passed")
	quit()
func capture(viewport, filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
