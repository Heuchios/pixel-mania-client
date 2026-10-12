extends SceneTree

func _initialize(): call_deferred("run")
func run():
	var button = preload("res://Scripts/ui/daily_rewards_button.gd").new()
	preload("res://Scripts/ui/pixel_ui_style.gd").apply_atlas_button(button, "pink_button")
	root.add_child(button)
	button.set_process(false)
	assert(button.get_icon_region() == Rect2(288, 128, 32, 32))
	button._process(0.5)
	assert(button.icon_frame == 0, "Unavailable reward remains still")
	button.set_reward_ready(true)
	for frame in 5:
		assert(button.get_icon_region() == Rect2((9 + frame) * 32, 128, 32, 32))
		button._process(0.201)
	assert(button.icon_frame == 0, "Ready animation loops over five gift frames")
	button.set_reward_ready(false)
	assert(button.icon_frame == 0)
	var rewards = preload("res://Scripts/ui/daily_rewards_ui.gd").new()
	rewards.hud_button = button
	rewards.snapshot = {"can_claim": true}
	rewards._update_hud()
	assert(button.reward_ready)
	rewards.snapshot = {"can_claim": false}
	rewards._update_hud(100)
	assert(not button.reward_ready)
	rewards._update_hud(0)
	assert(button.reward_ready, "Daily reset restarts the ready animation")
	rewards.free()
	button.free()
	print("DAILY_REWARDS_BUTTON: PASS")
	quit()
