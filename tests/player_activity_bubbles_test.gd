extends SceneTree
class World extends Node:
	var in_world := true
	var current_world_name := "TEST"
	var player: Node2D
	var shop := false
	var trade := false
	var edit := false
	func is_shop_open(): return shop
	func is_trade_open(): return trade
	func is_vending_open(): return edit

func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	world.player = Node2D.new()
	world.add_child(world.player)
	var policy = preload("res://Scripts/player_activity_bubbles.gd").new()
	world.add_child(policy)
	policy.world = world
	policy.set_process(false)
	policy._process(0)
	policy._process(59.9)
	assert(policy.resolve_activity() == "")
	policy._process(0.2)
	assert(world.player.get_meta("activity_bubble") == "afk")
	for event in [InputEventKey.new(), InputEventMouseButton.new(), InputEventScreenTouch.new(), InputEventScreenDrag.new(), InputEventJoypadButton.new()]:
		policy.idle_seconds = 61
		policy._input(event)
		assert(policy.idle_seconds == 0)
	policy.idle_seconds = 61
	world.player.position.x += 1
	policy._process(0.1)
	assert(policy.resolve_activity() == "")
	world.edit = true
	assert(policy.resolve_activity() == "edit")
	world.shop = true
	assert(policy.resolve_activity() == "shop")
	world.trade = true
	assert(policy.resolve_activity() == "trade")
	world.trade = false
	world.shop = false
	world.edit = false
	assert(policy.resolve_activity() == "")
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	world.player.add_child(visual)
	var head := Node2D.new()
	head.name = "Head"
	visual.add_child(head)
	var animator = load("res://Scripts/player_animation_manager.gd").new()
	world.player.add_child(animator)
	animator.player = world.player
	animator.world = world
	for mode in policy.CELLS:
		world.player.set_meta("remote_activity_bubble", mode)
		world.player.set_meta("remote_last_receive_msec", Time.get_ticks_msec())
		animator.update_face_expression_animation("idle")
		var indicator: AnimatedSprite2D = head.get_node("ChatTypingIndicator")
		assert(indicator.visible and indicator.animation == mode)
		assert(indicator.sprite_frames.get_frame_count(mode) == 3)
		for i in 3:
			assert(indicator.sprite_frames.get_frame_texture(mode, i).region == Rect2((policy.CELLS[mode] + i) * 32, 64, 32, 32))
	world.player.set_meta("remote_chat_typing", true)
	animator.update_face_expression_animation("idle")
	assert(animator.chat_typing_indicator.animation == "typing")
	world.player.set_meta("remote_chat_typing", false)
	world.player.set_meta("remote_activity_bubble", "")
	animator.update_face_expression_animation("idle")
	assert(not animator.chat_typing_indicator.visible)
	world.player.set_meta("remote_activity_bubble", "shop")
	world.player.set_meta("remote_last_receive_msec", Time.get_ticks_msec() - 16000)
	animator.update_face_expression_animation("idle")
	assert(not animator.chat_typing_indicator.visible)
	world.in_world = false
	policy._process(1)
	assert(world.player.get_meta("activity_bubble") == "")
	world.free()
	print("PLAYER_ACTIVITY_BUBBLES: PASS")
	quit()
