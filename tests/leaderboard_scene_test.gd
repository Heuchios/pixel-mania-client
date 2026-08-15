extends SceneTree

const LEADERBOARD_SCENE := preload("res://Scenes/ui/leaderboard/LeaderboardScene.tscn")
const LeaderboardEntryData := preload("res://Scripts/ui/leaderboard_entry_data.gd")
const LeaderboardTabData := preload("res://Scripts/ui/leaderboard_tab_data.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var leaderboard := LEADERBOARD_SCENE.instantiate()
	root.add_child(leaderboard)
	await process_frame
	leaderboard.refresh_preview()

	var window := leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow")
	if window == null:
		fail_test("LeaderboardWindow editable node is missing.")
		return
	if leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/HeaderPanel/TitleLabel") == null:
		fail_test("Editable title label node is missing.")
		return
	if not leaderboard.has_signal("close_pressed"):
		fail_test("Missing close_pressed signal.")
		return
	if not leaderboard.has_signal("rewards_pressed"):
		fail_test("Missing rewards_pressed signal.")
		return
	if not leaderboard.has_signal("tab_selected"):
		fail_test("Missing tab_selected signal.")
		return

	var first_row := leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/TablePanel/RowsClip/RowsRoot/LeaderboardRow1")
	if first_row == null:
		fail_test("Sample first row editable node is missing.")
		return
	if first_row.get_node("PlayerName").text != "PixelHero":
		fail_test("Sample first row name did not render.")
		return
	if first_row.get_node("Points").text != "12,450":
		fail_test("Sample first row points were not formatted.")
		return
	if leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/CloseButton") == null:
		fail_test("CloseButton editable node is missing.")
		return
	if leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/RewardsButton") == null:
		fail_test("RewardsButton editable node is missing.")
		return

	var custom_entry: Resource = LeaderboardEntryData.new()
	custom_entry.set("rank", 9)
	custom_entry.set("player_name", "EditMe")
	custom_entry.set("points", 42)
	custom_entry.set("highlighted", true)
	leaderboard.summary_rank_value = "99"
	leaderboard.summary_points_value = 123456
	leaderboard.summary_timer_value = "1H"
	leaderboard.set_entries_from_dictionaries([custom_entry])

	var custom_row := leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/TablePanel/RowsClip/RowsRoot/LeaderboardRow1")
	if custom_row == null:
		fail_test("Custom row editable node is missing.")
		return
	if custom_row.get_node("RankNumber").text != "9":
		fail_test("Custom row rank did not render.")
		return
	if custom_row.get_node("PlayerName").text != "EditMe":
		fail_test("Custom row name did not render.")
		return
	if custom_row.get_node("Points").text != "42":
		fail_test("Custom row points did not render.")
		return
	var custom_points_label := leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/SummaryPanel/YourPointsStat/Value") as Label
	if custom_points_label == null:
		fail_test("Custom points summary editable label is missing.")
		return
	if custom_points_label.text != "123,456":
		fail_test("Custom points summary was not formatted.")
		return

	var custom_tab: Resource = LeaderboardTabData.new()
	custom_tab.set("label", "CUSTOM")
	leaderboard.set_tabs_from_dictionaries([custom_tab])
	leaderboard.select_tab(0)
	var custom_tab_button := leaderboard.get_node_or_null("CenterContainer/LeaderboardWindow/SideColumn/Tabs/TabLandfill") as Button
	if custom_tab_button == null:
		fail_test("Custom tab editable button is missing.")
		return
	if custom_tab_button.text != "CUSTOM":
		fail_test("Custom tab label did not render.")
		return

	leaderboard.free()
	print("[leaderboard-scene] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[leaderboard-scene] " + message)
	quit(1)
