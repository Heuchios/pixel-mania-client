extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1440,1000)
	var ui = load("res://tmp/dev_layout_fixture.gd").new()
	root.add_child(ui)
	ui.build_panel()
	ui.update_layout()
	ui.status_label.text = "Role: admin | Server verified"
	for tab in ["player","items","inventory","monitor","moderation","world","tilemap_audit","debug"]:
		ui._on_tab_pressed(tab)
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/dev-"+tab+".png")
	ui.free()
	print("[dev-layout] all tabs rendered")
	quit()
