extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lobby=load("res://Scenes/ui/lobby/LobbyScene.tscn").instantiate()
	lobby.set_script(load("res://tests/lobby_ui_fixture.gd"))
	viewport.add_child(lobby)
	var tips=lobby.get_node("GameplayTips")
	var seen=[]
	seen.append(tips._last)
	for i in range(tips.TIPS.size()-1):
		tips._next_tip()
		assert(not tips._last in seen)
		seen.append(tips._last)
	var previous=tips._last
	tips._next_tip()
	assert(tips._last!=previous)
	tips._elapsed=8.9
	tips._process(.2)
	assert(tips._elapsed<1.0 and tips.modulate.a<1.0)
	tips._process(.5)
	await create_timer(.5).timeout
	print("TIP_DEBUG ",tips.text," ",tips.get_global_rect()," visible ",tips.is_visible_in_tree()," alpha ",tips.modulate)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/lobby-tips.png")
	print("Lobby tips: shuffled cycle, no boundary repeat, timed rotation and fade passed.")
	quit()
