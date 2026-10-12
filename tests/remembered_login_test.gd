extends Node

const LOGIN_SCREEN_SCRIPT_PATH := "res://Scripts/login_screen.gd"
const NETWORK_MANAGER_SCRIPT_PATH := "res://Scripts/network_manager.gd"
const TEST_PROFILE_PATH := "res://tmp/pixelmania_remembered_login_test.cfg"


class LoginScreenHarness:
	extends "res://Scripts/login_screen.gd"

	var captured_session: Dictionary = {}
	var test_network: Node

	func _ready() -> void:
		set_process(false)

	func _get_network_manager():
		return test_network

	func _set_network_session(username: String, email: String, token: String, role: String = "player") -> void:
		captured_session = {
			"username": username,
			"email": email,
			"session_token": token,
			"role": role,
		}


class SavedLoginNetworkMock:
	extends Node

	signal server_auth_finished(data)
	signal server_connection_changed(connected)
	var refresh_calls: Array[Dictionary] = []
	var session_calls: Array[Dictionary] = []
	var connected := true
	var connection_requests: Array[bool] = []
	var auth_canceled := false

	func is_connected_to_server() -> bool:
		return connected

	func request_server_connection(force: bool) -> void:
		connection_requests.append(force)
		connected = true

	func cancel_pending_account_authentication() -> void:
		auth_canceled = true
		connected = false
		server_connection_changed.emit(false)

	func send_account_refresh_token_login(username: String, refresh_token: String) -> String:
		refresh_calls.append({"username": username, "refresh_token": refresh_token})
		return "refresh-request"

	func send_account_token_login(username: String, session_token: String) -> String:
		session_calls.append({"username": username, "session_token": session_token})
		return "session-request"


class NetworkManagerHarness:
	extends "res://Scripts/network_manager.gd"

	var sent_payload: Dictionary = {}
	var send_succeeds := true

	func _ready() -> void:
		set_process(false)

	func is_connected_to_server() -> bool:
		return true

	func send_message(data: Dictionary) -> bool:
		sent_payload = data.duplicate(true)
		return send_succeeds


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# This suite uses only mocks, never the player's live saved login/socket.
	var live_network := get_node_or_null("/root/NetworkManager")
	if live_network != null:
		live_network.set_process(false)
	assert(load(LOGIN_SCREEN_SCRIPT_PATH) is GDScript)
	assert(load(NETWORK_MANAGER_SCRIPT_PATH) is GDScript)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE_PATH))

	var login := LoginScreenHarness.new()
	login.profile_path = TEST_PROFILE_PATH
	login.username_input = LineEdit.new()
	login.email_input = LineEdit.new()
	login.password_input = LineEdit.new()
	login.remember_password_check = CheckBox.new()
	login.add_child(login.username_input)
	login.add_child(login.email_input)
	login.add_child(login.password_input)
	login.add_child(login.remember_password_check)
	login.remember_password_check.button_pressed = true

	login._save_active_account("RememberedUser", "remembered@example.com", "session-one", "player", "refresh-one")
	var saved := ConfigFile.new()
	assert(saved.load(TEST_PROFILE_PATH) == OK)
	assert(bool(saved.get_value("profile", "remember_login", false)))
	assert(str(saved.get_value("profile", "session_token", "")) == "session-one")
	assert(str(saved.get_value("profile", "refresh_token", "")) == "refresh-one")
	assert(str(saved.get_value("profile", "saved_password", "")) == "")
	assert(str(saved.get_value("profile", "password", "")) == "")

	login.saved_session_username = ""
	login.saved_session_email = ""
	login.saved_session_token = ""
	login.saved_refresh_token = ""
	login.username_input.text = ""
	login.email_input.text = ""
	login.password_input.text = "must-not-survive"
	login._load_saved_account()
	assert(login.username_input.text == "RememberedUser")
	assert(login.email_input.text == "remembered@example.com")
	assert(login.password_input.text == "")
	assert(login.password_input.placeholder_text == "Saved login ready")
	assert(login.remember_password_check.button_pressed)
	assert(login.saved_session_token == "session-one")
	assert(login.saved_refresh_token == "refresh-one")

	var network_mock := SavedLoginNetworkMock.new()
	assert(login._send_saved_login_request(network_mock, "RememberedUser") == "refresh-request")
	assert(network_mock.refresh_calls.size() == 1)
	assert(network_mock.session_calls.is_empty())
	assert(str(network_mock.refresh_calls[0].get("refresh_token", "")) == "refresh-one")

	login.saved_refresh_token = ""
	assert(login._send_saved_login_request(network_mock, "RememberedUser") == "session-request")
	assert(network_mock.session_calls.size() == 1)
	assert(login._saved_login_error_requires_clear({"reason": "invalid_or_expired"}))
	assert(not login._saved_login_error_requires_clear({"reason": "rate_limited"}))

	var network_manager := NetworkManagerHarness.new()
	network_manager.profile_path = TEST_PROFILE_PATH
	var refresh_request_id := network_manager.send_account_refresh_token_login("RememberedUser", "refresh-one")
	assert(refresh_request_id != "")
	assert(str(network_manager.sent_payload.get("type", "")) == "account_token_login")
	assert(str(network_manager.sent_payload.get("username", "")) == "RememberedUser")
	assert(str(network_manager.sent_payload.get("refresh_token", "")) == "refresh-one")
	assert(not network_manager.sent_payload.has("session_token"))
	network_manager.send_succeeds = false
	assert(network_manager.send_account_login("TestUser", "test@example.com", "test-password") == "")
	assert(network_manager.send_account_register("TestUser", "test@example.com", "test-password") == "")
	assert(network_manager.send_account_token_login("TestUser", "test-session") == "")
	assert(network_manager.send_account_refresh_token_login("TestUser", "test-refresh") == "")
	network_manager.send_succeeds = true
	network_manager._persist_remembered_session_tokens(
		"RememberedUser",
		"remembered@example.com",
		"session-two",
		"refresh-two",
		"player"
	)
	var rotated := ConfigFile.new()
	assert(rotated.load(TEST_PROFILE_PATH) == OK)
	assert(str(rotated.get_value("profile", "session_token", "")) == "session-two")
	assert(str(rotated.get_value("profile", "refresh_token", "")) == "refresh-two")

	login._load_saved_account()
	assert(login.saved_session_token == "session-two")
	assert(login.saved_refresh_token == "refresh-two")
	login.remember_password_check.button_pressed = false
	login._on_remember_login_toggled(false)
	var forgotten := ConfigFile.new()
	assert(forgotten.load(TEST_PROFILE_PATH) == OK)
	assert(not bool(forgotten.get_value("profile", "remember_login", true)))
	assert(str(forgotten.get_value("profile", "session_token", "")) == "")
	assert(str(forgotten.get_value("profile", "refresh_token", "")) == "")
	assert(login.password_input.placeholder_text == "Password")

	add_child(login)
	login.test_network = network_mock
	login._connect_network_auth_signal()
	network_mock.connected = false
	assert(await login._wait_for_server_connection(0.5))
	assert(network_mock.connection_requests == [false], "Sign On must preserve an opening connection")

	# Reproduce the reported first-attempt failure: success after the old 8s cutoff.
	get_tree().create_timer(8.2).timeout.connect(func():
		network_mock.server_auth_finished.emit({"request_id": "slow-login", "ok": true})
	)
	var delayed: Dictionary = await login._wait_for_auth_response("slow-login")
	assert(bool(delayed.get("ok", false)), "A valid slow first login must succeed without another click")
	assert(not network_mock.auth_canceled)

	get_tree().create_timer(0.02).timeout.connect(func():
		network_mock.server_connection_changed.emit(false)
	)
	var disconnected: Dictionary = await login._wait_for_auth_response("disconnected-login", 1.0)
	assert(disconnected.get("reason") == "connection_lost")
	assert(not login._saved_login_error_requires_clear(disconnected))

	var expired: Dictionary = await login._wait_for_auth_response("expired-login", 0.02)
	assert(expired.get("reason") == "authentication_timeout")
	assert(network_mock.auth_canceled, "An expired attempt must be retired before another can start")
	assert(login.pending_auth_request_id == "" and login.pending_auth_response.is_empty())
	# A late reply to the retired request cannot satisfy a new attempt.
	get_tree().create_timer(0.02).timeout.connect(func():
		network_mock.server_auth_finished.emit({"request_id": "expired-login", "ok": true})
		network_mock.server_auth_finished.emit({"request_id": "current-login", "ok": false, "reason": "invalid_password"})
	)
	var current: Dictionary = await login._wait_for_auth_response("current-login", 1.0)
	assert(current.get("reason") == "invalid_password")

	add_child(network_manager)
	network_manager.connected = true
	network_manager.saved_refresh_login_in_flight = true
	network_manager.connection_health.authenticating(Time.get_ticks_msec())
	var old_generation: int = network_manager.socket_generation
	network_manager.cancel_pending_account_authentication()
	assert(network_manager.socket_generation == old_generation + 1)
	assert(not network_manager.connected and not network_manager.saved_refresh_login_in_flight)
	assert(network_manager.connection_health.phase == "DISCONNECTED")
	network_manager.connection_health.authenticated(Time.get_ticks_msec())
	network_manager.cancel_pending_account_authentication()
	assert(network_manager.socket_generation == old_generation + 1, "Never cancel a completed authentication")

	var rejected_auth: Array[Dictionary] = []
	network_manager.server_auth_finished.connect(func(data): rejected_auth.append(data))
	for auth_type in ["account_login", "account_token_login"]:
		network_manager.pending_account_auth_request_id = "current-request"
		network_manager.pending_account_auth_request_type = auth_type
		network_manager.pending_account_auth_started_ms = Time.get_ticks_msec()
		network_manager.connection_health.authenticating(Time.get_ticks_msec())
		assert(not network_manager._route_rejection_as_account_auth({"type": "rate_limited", "action": "chat"}))
		assert(not network_manager._route_rejection_as_account_auth({"type": "rate_limited", "action": auth_type, "request_id": "retired-request"}))
		# Legacy servers do not echo IDs on these warnings. They must still end
		# this exact account request promptly instead of waiting for a timeout.
		assert(network_manager._route_rejection_as_account_auth({"type": "rate_limited", "action": auth_type, "message": "Slow down a little."}))
		assert(rejected_auth.back().get("request_id") == "current-request")
		assert(rejected_auth.back().get("reason") == "rate_limited")
		assert(not login._saved_login_error_requires_clear(rejected_auth.back()))
		assert(network_manager.connection_health.phase == "FAILED")
		assert(network_manager.pending_account_auth_request_id == "")
		assert(not network_manager._route_rejection_as_account_auth({"type": "rate_limited", "action": auth_type}))
	assert(rejected_auth.size() == 2)

	network_mock.free()
	network_manager.free()
	login.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE_PATH))
	print("[remembered-login] success")
	get_tree().quit(0)
