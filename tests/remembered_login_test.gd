extends Node

const LOGIN_SCREEN_SCRIPT_PATH := "res://Scripts/login_screen.gd"
const NETWORK_MANAGER_SCRIPT_PATH := "res://Scripts/network_manager.gd"
const TEST_PROFILE_PATH := "user://pixelmania_remembered_login_test.cfg"


class LoginScreenHarness:
	extends "res://Scripts/login_screen.gd"

	var captured_session: Dictionary = {}

	func _set_network_session(username: String, email: String, token: String, role: String = "player") -> void:
		captured_session = {
			"username": username,
			"email": email,
			"session_token": token,
			"role": role,
		}


class SavedLoginNetworkMock:
	extends Node

	var refresh_calls: Array[Dictionary] = []
	var session_calls: Array[Dictionary] = []

	func send_account_refresh_token_login(username: String, refresh_token: String) -> String:
		refresh_calls.append({"username": username, "refresh_token": refresh_token})
		return "refresh-request"

	func send_account_token_login(username: String, session_token: String) -> String:
		session_calls.append({"username": username, "session_token": session_token})
		return "session-request"


class NetworkManagerHarness:
	extends "res://Scripts/network_manager.gd"

	var sent_payload: Dictionary = {}

	func is_connected_to_server() -> bool:
		return true

	func send_message(data: Dictionary) -> bool:
		sent_payload = data.duplicate(true)
		return true


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(load(LOGIN_SCREEN_SCRIPT_PATH) is GDScript)
	assert(load(NETWORK_MANAGER_SCRIPT_PATH) is GDScript)
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

	network_mock.free()
	network_manager.free()
	login.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE_PATH))
	print("[remembered-login] success")
	get_tree().quit(0)
