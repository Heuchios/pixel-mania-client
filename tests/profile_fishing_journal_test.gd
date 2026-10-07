extends SceneTree

class JournalStub:
	extends Node
	var opened := 0
	func open_fishing_journal() -> void:
		opened += 1

class WorldStub:
	extends Node
	var fishing_manager: Node

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var profile = load("res://Scenes/ui/player_profile/PlayerProfileScene.tscn").instantiate()
	root.add_child(profile)
	profile.set_process(false)
	profile.build_menu()
	var world := WorldStub.new()
	world.fishing_manager = JournalStub.new()
	profile.world = world
	profile.profile_mode = "local"
	profile.update_action_buttons()
	assert(profile.fish_journal_button != null and profile.fish_journal_button.visible)
	for button in [profile.recipe_book_button, profile.fish_journal_button, profile.worlds_button]:
		var rect: Rect2 = button.get_parent().get_rect()
		assert(rect.position.x >= 0 and rect.end.x <= profile.action_panel.size.x)
	profile.fish_journal_button.pressed.emit()
	assert(world.fishing_manager.opened == 1 and not profile.is_menu_open)
	profile.profile_mode = "remote"
	profile._on_fish_journal_pressed()
	assert(world.fishing_manager.opened == 1, "Remote profiles must not open a personal journal")
	profile.world = null
	world.fishing_manager.free()
	world.free()
	profile.queue_free()
	await process_frame
	print("[profile-journal] PASS: button fits and opens the personal journal")
	quit()
