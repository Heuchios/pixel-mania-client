extends SceneTree

var longest_frame_ms := 0
var previous_tick := 0

func _initialize():
	call_deferred("run")

func _process(_delta):
	var now := Time.get_ticks_msec()
	if previous_tick > 0:
		longest_frame_ms = maxi(longest_frame_ms, now - previous_tick)
	previous_tick = now
	return false

func run():
	var mode := "password"
	var user_args := OS.get_cmdline_user_args()
	for index in range(user_args.size() - 1):
		if user_args[index] == "--login-smoke-mode":
			mode = user_args[index + 1]
	var login = load("res://Scenes/ui/login/LoginScene.tscn").instantiate()
	root.add_child(login)
	current_scene = login
	login.username_input.text = "LatencyProbe"
	login.email_input.text = "latency@example.invalid"
	login.password_input.text = "TestOnlyPassword123"
	login.remember_password_check.button_pressed = false
	if mode == "saved":
		login.password_input.text = ""
		login.saved_session_username = "LatencyProbe"
		login.saved_session_email = "latency@example.invalid"
		login.saved_refresh_token = "fixture-refresh-token"
	var pressed := Time.get_ticks_msec()
	await login._on_sign_on_pressed()
	var message: String = login.message_label.text
	await process_frame
	await process_frame
	var elapsed := Time.get_ticks_msec() - pressed
	var scene_path := current_scene.scene_file_path
	var succeeded := scene_path == "res://Scenes/ui/lobby/LobbyScene.tscn"
	var expected_success := mode in ["password", "saved", "slow"]
	var passed := succeeded == expected_success
	if not expected_success:
		passed = passed and message == "Fixture rate limit response" and elapsed < 5000
	else:
		passed = passed and elapsed < (14000 if mode == "slow" else 5000)
	print("LOGIN_LATENCY_SMOKE ", JSON.stringify({"mode": mode, "ok": passed, "click_ms": elapsed, "longest_frame_ms": longest_frame_ms, "scene": scene_path}))
	# Do not tear down autoloads while world scripts still compile on workers.
	var preloader = load("res://Scripts/world_scene_preloader.gd")
	var cleanup_deadline := Time.get_ticks_msec() + 20000
	while not preloader.is_fully_warmed() and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	quit(0 if passed else 1)
