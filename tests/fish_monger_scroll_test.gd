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
var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func run():
	Input.emulate_touch_from_mouse = true
	root.content_scale_size = Vector2i.ZERO
	var world := World.new()
	root.add_child(world)
	for i in 12:
		world.fish_monger_manager.entries.append({"item_id":"fish_"+str(i), "display_name":"Fish "+str(i), "count":12, "sell_value":2, "rarity":"common"})
	var ui := UI.new()
	root.add_child(ui)
	ui.setup(world, root)
	ui.open_fish_monger(Vector2i.ZERO)
	for dimensions in [Vector2i(1280,800),Vector2i(640,360),Vector2i(390,844)]:
		root.size = dimensions
		ui.update_panel_position()
		for i in 5: await process_frame
		ui.fish_scroll.scroll_vertical = 0
		await process_frame
		var point: Vector2 = ui.fish_scroll.get_global_transform() * Vector2(190,60)
		var wheel := InputEventMouseButton.new()
		wheel.position = point
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await process_frame
		check(ui.fish_scroll.scroll_vertical > 0,"Monger wheel failed at "+str(dimensions))
		ui.fish_scroll.scroll_vertical = 0
		await process_frame
		var row = ui.fish_rows_root.get_child(0)
		var sell: Button = row.get_node("Sell") if row.has_node("Sell") else row.get_node("SellButton")
		point = sell.get_global_rect().get_center()
		mouse(point,true)
		for i in range(1,5):
			var drag := InputEventMouseMotion.new()
			drag.position = point + Vector2(0,-i*12)
			drag.relative = Vector2(0,-12)
			drag.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(drag,true)
			await process_frame
		mouse(point+Vector2(0,-48),false)
		check(ui.fish_scroll.scroll_vertical > 0,"Monger swipe failed at "+str(dimensions))
		check(world.fish_monger_manager.sold.is_empty(),"Dragging Sell must never submit a sale")
		check(ui.fish_scroll.get_v_scroll_bar().get_theme_stylebox("grabber").get_meta("atlas_region","") == "scroll_handle","Monger must use game scrollbar")
	ui.free()
	world.free()
	print("FISH_MONGER_SCROLL: %d failures" % failures)
	quit(1 if failures else 0)
func mouse(point: Vector2, pressed: bool):
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event,true)
