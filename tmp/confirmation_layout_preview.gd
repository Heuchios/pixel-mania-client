extends SceneTree
class Manager extends Node:
	var state={"lock_id":"test","lock_type":"big_lock","public_build":false,"ignore_empty_space":false}
	func get_area_lock_for_lock_id(_id): return state
	func can_current_player_manage_area_lock(_lock): return true
	func get_area_lock_info_text(_lock): return "Owner: USO\nProtected tiles: 200\nMode: Trusted only\nShape: Full area"
	func get_area_lock_access_list(_lock): return [{"name":"UCE","role":"builder"},{"name":"Lucifer","role":"admin"}]
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1000,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var manager := Manager.new()
	viewport.add_child(manager)
	var ui=load("res://Scenes/ui/locks/AreaLockGUI.tscn").instantiate()
	ui.set_script(load("res://tmp/area_layout_fixture.gd"))
	viewport.add_child(ui)
	ui.setup(null,manager)
	ui.target_lock_id="test"
	ui.visible=true
	ui.refresh()
	await capture(viewport,"area-lock-updated")
	ui._show_public_build_confirmation(true)
	await capture(viewport,"area-lock-confirm")
	ui.public_build_confirm_panel.get_node("CancelPublicBuildButton").pressed.emit()
	assert(not ui.public_build_check.button_pressed)
	ui._show_ignore_empty_space_confirmation()
	assert(ui.ignore_empty_space_confirm_panel != null)
	ui.clear_ignore_empty_space_confirmation()
	ui._show_remove_access_confirmation("UCE","builder")
	assert(ui.access_remove_confirm_panel != null)
	ui.clear_access_remove_confirmation()
	ui.close()
	var vend=load("res://Scenes/ui/vending/VendingMachineGUI.tscn").instantiate()
	viewport.add_child(vend)
	vend.setup(null,null)
	vend.visible=true
	vend.apply_vend_state({"listing":{"listing_id":"test","item_id":"melter","item_category":"block","stock":100,"amount_per_sale":1,"price_wls":100},"can_manage":false})
	vend.refresh_ui()
	vend.stock_spin.value=100
	vend.stock_spin.get_line_edit().text="100"
	vend._on_buy_pressed()
	assert(vend.purchase_confirmation.visible)
	await capture(viewport,"vending-confirm")
	vend.purchase_confirmation.card.get_node("CancelButton").pressed.emit()
	assert(not vend.purchase_confirmation.visible)
	viewport.size=Vector2i(640,480)
	vend._on_buy_pressed()
	await capture(viewport,"vending-confirm-compact")
	print("Confirmation previews and cancel paths passed.")
	quit()
func capture(viewport,filename):
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
