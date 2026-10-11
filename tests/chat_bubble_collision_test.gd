extends SceneTree

const Bubble = preload("res://Scripts/chat_bubble_component.gd")
var checks := 0
var failures := 0

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run():
	for screen in [Vector2i(1280,720), Vector2i(844,390), Vector2i(640,360)]:
		var viewport := SubViewport.new()
		viewport.size = screen
		root.add_child(viewport)
		var bubbles: Array = []
		for index in 3:
			var bubble = Bubble.new()
			viewport.add_child(bubble)
			bubble.show_chat_message(["let me fix that", "wait im not even had an invitation", "One last trade check"][index])
			bubble.set_screen_position(Vector2(110 + index * 35, 70))
			bubbles.append(bubble)
		await process_frame
		Bubble.layout_viewport_bubbles(viewport)
		for i in bubbles.size():
			check(bubbles[i].background.visible, "Three nearby speech bubbles fit the screen")
			check(viewport.get_visible_rect().encloses(bubbles[i].get_rect()), "Bubbles remain inside phone/desktop bounds")
			for j in range(i):
				check(not bubbles[i].get_rect().intersects(bubbles[j].get_rect()), "Local and remote text panels cannot overlap")
		var stable_positions = bubbles.map(func(b): return b.position)
		Bubble.layout_viewport_bubbles(viewport)
		check(bubbles.map(func(b): return b.position) == stable_positions, "Unchanged anchors have stable positions")
		bubbles[0].hide_chat_bubble()
		await process_frame
		check(bubbles[1].position.is_equal_approx(Vector2(145,70)), "Remaining bubble returns to its speaker after a neighbour expires")
		for bubble in bubbles:
			bubble.hide_chat_bubble()
		await process_frame
		viewport.queue_free()
		await process_frame
	var occupied: Array[Rect2] = [Rect2(0,0,200,80)]
	check(not Bubble.find_clear_screen_position(Vector2.ZERO, Vector2(200,80), Rect2(0,0,200,80), occupied).is_finite(), "A full screen defers excess text instead of drawing over another message")
	var small := SubViewport.new()
	small.size = Vector2i(360, 110)
	root.add_child(small)
	var crowded: Array = []
	for i in 3:
		var bubble = Bubble.new()
		small.add_child(bubble)
		bubble.show_chat_message("message one")
		bubble.set_screen_position(Vector2(2,2))
		crowded.append(bubble)
	small.size = Vector2i(ceili(crowded[0].size.x) + 4, ceili(crowded[0].size.y) * 2 + ceili(Bubble.BUBBLE_LAYOUT_GAP) + 4)
	await process_frame
	check(not crowded[2].background.visible and crowded[2].visible, "Overflow hides artwork without stopping the message timer or anchor")
	crowded[0].hide_chat_bubble()
	await process_frame
	check(crowded[2].background.visible, "Deferred text reappears as soon as space becomes available")
	for bubble in crowded:
		bubble.hide_chat_bubble()
	await process_frame
	small.queue_free()
	await process_frame
	print("CHAT_BUBBLE_COLLISIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
