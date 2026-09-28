extends SceneTree
class FakeWorld extends Node:
	var cctv_state := {"can_view":true,"entries":[],"entry_count":0}
	func can_current_player_view_cctv(): return true
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1440,1000)
	var world = FakeWorld.new()
	root.add_child(world)
	for i in range(11):
		world.cctv_state.entries.append({"player_name":"USO" if i%3 else "A_VERY_LONG_PLAYER_NAME", "event_type":"leave" if i==3 else "enter", "at":"2026-09-20T00:46:00Z"})
	var ui = load("res://Scripts/cctv_ui.gd").new()
	root.add_child(ui)
	ui.setup(world)
	ui.open_cctv(Vector2i.ZERO)
	await create_timer(0.3).timeout
	assert(ui.entries_root.get_child_count()==11)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/cctv-updated.png")
	world.cctv_state.entries=[]
	ui.refresh()
	await process_frame
	assert(ui.entries_root.get_child_count()==1)
	root.size=Vector2i(800,600)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/cctv-empty.png")
	ui.close_button.pressed.emit()
	assert(not ui.is_cctv_open())
	ui.free()
	world.free()
	print("[cctv-preview] passed")
	quit()
