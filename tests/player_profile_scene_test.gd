extends SceneTree

const PROFILE_SCENE = preload("res://Scenes/ui/player_profile/PlayerProfileScene.tscn")


class FakeSaveManager extends Node:
	func get_player_save_data() -> Dictionary:
		return {
			"profile_bio": "Building bright little worlds.",
			"player_level": 12,
			"player_xp": 125,
			"player_xp_needed": 500,
			"player_total_xp": 4625,
			"player_title": "Builder"
		}


class FakeFriendsUI extends Node:
	var friends: Array = [{"username": "FriendOne"}, {"username": "FriendTwo"}]


class FakeWorld extends Node:
	var ui_layer: Control = null
	var modal_layer: Control = null
	var player_menu_ui = null
	var save_manager: Node = null
	var friends_ui: Node = null
	var player: Node2D = null
	var player_manager: Node = null
	var player_level := 12
	var player_xp := 125
	var player_xp_needed := 500
	var player_total_xp := 4625
	var player_title := "Builder"
	var current_world_name := "TEST_WORLD"
	var equipped_tool := "wrench"
	var equipped_back_item := ""
	var equipped_hat_item := ""
	var equipped_hair_item := ""
	var equipped_eyewear_item := ""
	var equipped_shirt_item := ""
	var equipped_pants_item := ""
	var item_database := {}
	var entered_world := ""

	func _init() -> void:
		ui_layer = Control.new()
		ui_layer.name = "UI"
		modal_layer = Control.new()
		modal_layer.name = "ModalLayer"
		ui_layer.add_child(modal_layer)
		add_child(ui_layer)
		player = Node2D.new()
		player.name = "Player"
		var player_visual := Node2D.new()
		player_visual.name = "PlayerVisual"
		var body_root := Node2D.new()
		body_root.name = "Body"
		var body := AnimatedSprite2D.new()
		body.name = "BaseBodyAnimated"
		var body_frames := SpriteFrames.new()
		body_frames.add_frame("default", load("res://Assets/player/body_parts/body_idle_1.png"))
		body.sprite_frames = body_frames
		body_root.add_child(body)
		player_visual.add_child(body_root)
		var right_arm := Node2D.new()
		right_arm.name = "RightArm"
		player_visual.add_child(right_arm)
		player.add_child(player_visual)
		add_child(player)
		var remote_root := Node2D.new()
		remote_root.name = "RemotePlayers"
		var remote_player := Node2D.new()
		remote_player.name = "RemotePlayer"
		remote_player.set_meta("remote_id", "remote-player-id")
		remote_player.set_meta("remote_name", "RemotePlayer")
		var remote_visual := player_visual.duplicate()
		remote_visual.name = "PlayerVisual"
		remote_player.add_child(remote_visual)
		remote_root.add_child(remote_player)
		add_child(remote_root)
		save_manager = FakeSaveManager.new()
		friends_ui = FakeFriendsUI.new()
		add_child(save_manager)
		add_child(friends_ui)

	func get_current_profile_name() -> String:
		return "ProfileTester"

	func get_ui_modal_layer() -> Node:
		return modal_layer

	func get_current_world_display_name() -> String:
		return current_world_name

	func get_item_display_name(item_id: String, _category: String) -> String:
		return item_id.replace("_", " ").capitalize()

	func get_friend_status_for_username(_username: String) -> String:
		return "none"

	func has_pending_trade_from_player(_player_data: Dictionary) -> bool:
		return false

	func enter_world_by_name(world_name: String) -> void:
		entered_world = world_name

	func show_notification(_message: String) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var utc_today := Time.get_datetime_dict_from_system(true)
	var today_midnight := int(Time.get_unix_time_from_datetime_dict({
		"year": int(utc_today.get("year", 1970)),
		"month": int(utc_today.get("month", 1)),
		"day": int(utc_today.get("day", 1)),
		"hour": 0,
		"minute": 0,
		"second": 0
	}))
	var created_two_days_ago := Time.get_datetime_string_from_unix_time(today_midnight - 2 * 86400) + ".000Z"
	var created_ten_days_ago := Time.get_datetime_string_from_unix_time(today_midnight - 10 * 86400) + ".000Z"
	var fake_world := FakeWorld.new()
	root.add_child(fake_world)
	var profile = PROFILE_SCENE.instantiate()
	root.add_child(profile)
	profile.setup(fake_world)
	profile.open_menu()
	await process_frame

	assert(profile.scene_file_path == "res://Scenes/ui/player_profile/PlayerProfileScene.tscn")
	assert(profile.has_method("open_remote_profile"))
	assert(profile.has_method("handle_player_state_lookup_result"))
	assert(profile.get_node("%DisplayNameLabel").text == "PROFILETESTER")
	assert(profile.get_node("%LevelValueLabel").text == "12")
	assert(profile.get_node("%XpValueLabel").text == "125 / 500")
	assert(is_equal_approx(profile.get_node("%XpFill").anchor_right, 0.25))
	assert(profile.get_node("%FriendsValueLabel").text == "2")
	assert(profile.get_node("%AchievementsValueLabel").text == "4.6K")
	assert(profile.get_node("%PlayerAgeValueLabel").text == "--")
	assert(profile.get_node("%BioLabel").text == "Building bright little worlds.")
	assert(profile.get_node("%PortraitViewport") is SubViewport)
	assert(profile.get_node("%PortraitViewport").canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert(profile.get_node("%PortraitTexture").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(profile.get_node("%PortraitPreviewRoot").position == Vector2(122.0, 124.0))
	assert(profile.portrait_preview_visual != null)
	assert(profile.portrait_preview_visual.scale.abs() == Vector2(4.0, 4.0))
	assert(profile.portrait_preview_visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(profile.portrait_preview_visual.get_node("Body/BaseBodyAnimated").sprite_frames != null)
	assert(profile.portrait_preview_visual.get_node("Body/BaseBodyAnimated").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(not profile.get_node("CenterContainer/ProfileWindow/PortraitPanel/PortraitFrame/PortraitPlaceholderLabel").visible)
	fake_world.player.get_node("PlayerVisual/RightArm").rotation = 0.5
	profile.update_menu_info()
	assert(is_equal_approx(profile.portrait_preview_visual.get_node("RightArm").rotation, 0.5))
	assert(profile.get_node("%VisitWorldButton").text == "MY WORLDS")
	assert(profile.get_node("%MessageButton").get_parent() is NinePatchRect)
	assert(profile.get_node("%VisitWorldButton").get_parent() is NinePatchRect)
	assert(profile.get_node("%PrimaryActionButton").get_parent() is NinePatchRect)
	assert(profile.get_node("%EditBioButton").get_parent() is NinePatchRect)
	assert(profile.get_node("%BioSaveButton").get_parent() is NinePatchRect)
	assert(profile.get_node("%BioCancelButton").get_parent() is NinePatchRect)
	profile._on_edit_bio_pressed()
	assert(profile.get_node("%BioEditorSkin").visible)
	assert(profile.get_node("%BioTextEdit").text == "Building bright little worlds.")
	assert(profile.get_node_or_null("%ProfileAgeEdit") == null)
	profile._on_bio_cancel_pressed()
	assert(not profile.get_node("%BioEditorSkin").visible)
	profile.editing_bio = true
	profile.bio_save_pending = true
	profile.bio_save_request_id = "bio-save-1"
	profile.handle_player_state_lookup_result("bio-save-1", {
		"type": "player_state",
		"ok": true,
		"message": "Profile saved.",
		"created_at": created_two_days_ago,
		"account": {"created_at": created_two_days_ago},
		"player_data": {
			"profile_bio": "Saved by the authoritative server."
		}
	}, {
		"purpose": "local_player_profile",
		"operation": "save"
	})
	assert(profile.get_node("%BioLabel").text == "Saved by the authoritative server.")
	assert(profile.get_node("%PlayerAgeValueLabel").text == "2 DAYS")
	assert(not profile.get_node("%BioEditorSkin").visible)

	profile.profile_mode = "remote"
	profile.remote_profile_lookup_status = "online"
	profile.remote_profile_data = {
		"username": "RemotePlayer",
		"player_id": "remote-player-id",
		"world": "OTHER_WORLD",
		"online": true,
		"role": "player",
		"created_at": created_ten_days_ago,
		"player_data": {
			"player_data_version": 1,
			"profile_bio": "Remote bio from the server.",
			"player_level": 20,
			"player_xp": 50,
			"player_xp_needed": 200,
			"player_total_xp": 12000,
			"player_title": "Architect"
		}
	}
	profile.update_menu_info()
	assert(profile.get_node("%DisplayNameLabel").text == "REMOTEPLAYER")
	assert(profile.get_node("%LevelValueLabel").text == "20")
	assert(profile.get_node("%TitleValueLabel").text == "ARCHITECT")
	assert(profile.get_node("%PlayerAgeValueLabel").text == "10 DAYS")
	assert(profile.get_node("%BioLabel").text == "Remote bio from the server.")
	assert(profile.portrait_preview_visual != null)
	assert(not profile.get_node("%EditBioButtonSkin").visible)
	assert(profile.get_node("%MessageButton").text == "TRADE")
	assert(profile.get_node("%VisitWorldButton").text == "VISIT WORLD")
	assert(profile.get_node("%PrimaryActionButton").text == "ADD FRIEND")
	assert(profile.get_node("%MessageButton").get_parent().visible)
	assert(profile.get_node("%VisitWorldButton").get_parent().visible)
	assert(profile.get_node("%PrimaryActionButton").get_parent().visible)

	profile._on_profile_world_pressed()
	assert(fake_world.entered_world == "OTHER_WORLD")
	assert(not profile.is_open())

	var remote_root := fake_world.get_node("RemotePlayers")
	var live_remote_player := remote_root.get_child(0)
	remote_root.remove_child(live_remote_player)
	live_remote_player.free()
	profile.open_remote_profile({
		"username": "OfflinePlayer",
		"name": "OfflinePlayer",
		"online": false,
		"lookup_source": "command",
		"equipment_slots": {}
	})
	profile.remote_profile_lookup_status = "offline"
	profile.update_menu_info()
	await process_frame
	assert(profile.get_node("%DisplayNameLabel").text == "OFFLINEPLAYER")
	assert(profile.portrait_preview_visual != null)
	assert(profile.portrait_equipment_manager != null)
	assert(profile.portrait_preview_signature.begins_with("profile:"))
	assert(not profile.get_node("CenterContainer/ProfileWindow/PortraitPanel/PortraitFrame/PortraitPlaceholderLabel").visible)

	profile.queue_free()
	fake_world.queue_free()
	print("[player-profile-scene] success")
	quit(0)
