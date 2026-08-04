extends Node

const ACCOUNT_SAVE_PATH = "user://accounts.json"
const LEGACY_PROFILE_PATH = "user://pixelmania_profile.cfg"
const MIN_USERNAME_LENGTH = 3
const MAX_USERNAME_LENGTH = 16
const MIN_PASSWORD_LENGTH = 8

var world = null
var profiles: Array = []
var current_profile: String = ""


func get_network_manager():
	if not is_inside_tree():
		return null

	return get_tree().root.get_node_or_null("NetworkManager")


func setup(world_ref):
	world = world_ref
	load_accounts()


func load_accounts():
	profiles.clear()
	current_profile = ""

	if not FileAccess.file_exists(ACCOUNT_SAVE_PATH):
		migrate_legacy_profile()
		save_accounts()
		return

	var file = FileAccess.open(ACCOUNT_SAVE_PATH, FileAccess.READ)

	if file == null:
		return

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)

	if not (data is Dictionary):
		return

	var saved_profiles = data.get("profiles", [])

	if saved_profiles is Array:
		for profile_data in saved_profiles:
			if not (profile_data is Dictionary):
				continue

			var username = str(profile_data.get("username", "")).strip_edges()

			if username == "":
				continue

			profiles.append({
				"username": username,
				"email": normalize_email(str(profile_data.get("email", ""))),
				"server_account": bool(profile_data.get("server_account", true)),
				"created_at": str(profile_data.get("created_at", "")),
				"last_login_at": str(profile_data.get("last_login_at", ""))
			})

	var session_profile = get_network_session_username()
	if has_profile(session_profile) and is_registered_profile(get_profile_data(session_profile)):
		current_profile = get_stored_username(session_profile)
		return

	var last_profile = str(data.get("last_profile", "")).strip_edges()

	if has_profile(last_profile) and is_registered_profile(get_profile_data(last_profile)):
		current_profile = get_stored_username(last_profile)
	else:
		for profile_data in profiles:
			if is_registered_profile(profile_data):
				current_profile = str(profile_data.get("username", ""))
				break


func save_accounts():
	var data = {
		"version": 2,
		"profiles": profiles,
		"last_profile": current_profile
	}

	var file = FileAccess.open(ACCOUNT_SAVE_PATH, FileAccess.WRITE)

	if file == null:
		print("Could not save local accounts.")
		return

	file.store_string(JSON.stringify(data, "	"))
	file.close()


func get_network_session_username() -> String:
	var network = get_network_manager()
	if network != null and network.has_method("get_active_session_username"):
		return str(network.get_active_session_username()).strip_edges()

	return ""


func migrate_legacy_profile():
	var cfg = ConfigFile.new()
	var err = cfg.load(LEGACY_PROFILE_PATH)

	if err != OK:
		return

	var username = str(cfg.get_value("profile", "username", "")).strip_edges()
	if username == "":
		return

	var validation = validate_username(username)
	if not bool(validation.get("ok", false)):
		return

	profiles.append({
		"username": str(validation.get("username", username)),
		"email": normalize_email(str(cfg.get_value("profile", "email", ""))),
		"server_account": true,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"last_login_at": ""
	})


func validate_username(raw_username: String) -> Dictionary:
	var username = raw_username.strip_edges()

	if username.length() < MIN_USERNAME_LENGTH:
		return {"ok": false, "message": "Username must be at least " + str(MIN_USERNAME_LENGTH) + " characters."}

	if username.length() > MAX_USERNAME_LENGTH:
		return {"ok": false, "message": "Username must be " + str(MAX_USERNAME_LENGTH) + " characters or less."}

	var allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

	for i in range(username.length()):
		var character = username.substr(i, 1)

		if allowed.find(character) == -1:
			return {"ok": false, "message": "Use letters, numbers, and underscore only."}

	return {"ok": true, "message": "OK", "username": username}


func normalize_email(raw_email: String) -> String:
	return raw_email.strip_edges().to_lower()


func validate_email(raw_email: String) -> Dictionary:
	var email = normalize_email(raw_email)

	if email == "":
		return {"ok": false, "message": "Enter an email address."}

	if email.find(" ") != -1:
		return {"ok": false, "message": "Email cannot contain spaces."}

	var at_index = email.find("@")
	if at_index <= 0 or at_index != email.rfind("@"):
		return {"ok": false, "message": "Enter a valid email address."}

	var domain = email.substr(at_index + 1)
	if domain.length() < 3 or domain.find(".") <= 0 or domain.ends_with("."):
		return {"ok": false, "message": "Enter a valid email address."}

	return {"ok": true, "message": "OK", "email": email}


func validate_password(password: String) -> Dictionary:
	if password.length() < MIN_PASSWORD_LENGTH:
		return {"ok": false, "message": "Password must be at least " + str(MIN_PASSWORD_LENGTH) + " characters."}

	return {"ok": true, "message": "OK"}


func username_key(username: String) -> String:
	return username.strip_edges().to_lower()


func has_profile(username: String) -> bool:
	var key = username_key(username)

	if key == "":
		return false

	for profile_data in profiles:
		if username_key(str(profile_data.get("username", ""))) == key:
			return true

	return false


func has_email(email: String) -> bool:
	var clean_email = normalize_email(email)

	if clean_email == "":
		return false

	for profile_data in profiles:
		if normalize_email(str(profile_data.get("email", ""))) == clean_email:
			return true

	return false


func has_email_for_other_profile(email: String, username: String) -> bool:
	var clean_email = normalize_email(email)
	var current_key = username_key(username)

	if clean_email == "":
		return false

	for profile_data in profiles:
		if username_key(str(profile_data.get("username", ""))) == current_key:
			continue

		if normalize_email(str(profile_data.get("email", ""))) == clean_email:
			return true

	return false


func get_profile_data(username: String) -> Dictionary:
	var key = username_key(username)

	if key == "":
		return {}

	for profile_data in profiles:
		var stored_username = str(profile_data.get("username", ""))

		if username_key(stored_username) == key:
			return profile_data

	return {}


func is_registered_profile(profile_data: Dictionary) -> bool:
	if profile_data.is_empty():
		return false

	return normalize_email(str(profile_data.get("email", ""))) != ""


func get_stored_username(username: String) -> String:
	var key = username_key(username)

	for profile_data in profiles:
		var stored_username = str(profile_data.get("username", ""))

		if username_key(stored_username) == key:
			return stored_username

	return ""


func get_email_for_username(username: String) -> String:
	var profile_data = get_profile_data(username)

	if profile_data.is_empty():
		return ""

	return normalize_email(str(profile_data.get("email", "")))


func register_account(_raw_username: String, _raw_email: String, _password: String) -> Dictionary:
	return {"ok": false, "message": "Use server registration from the login screen."}


func authenticate_account(_raw_username: String, _password: String) -> Dictionary:
	return {"ok": false, "message": "Use server sign-on from the login screen."}


func cache_server_account(raw_username: String, raw_email: String) -> Dictionary:
	var username_validation = validate_username(raw_username)

	if not bool(username_validation.get("ok", false)):
		return username_validation

	var username = str(username_validation.get("username", ""))
	var email = normalize_email(raw_email)
	var profile_data = get_profile_data(username)
	var now = Time.get_datetime_string_from_system(false, true)

	if profile_data.is_empty():
		profiles.append({
			"username": username,
			"email": email,
			"server_account": true,
			"created_at": now,
			"last_login_at": now
		})
	else:
		profile_data["username"] = username
		profile_data["email"] = email
		profile_data["server_account"] = true
		profile_data.erase("password_hash")
		if str(profile_data.get("created_at", "")) == "":
			profile_data["created_at"] = now
		profile_data["last_login_at"] = now

	current_profile = get_stored_username(username)
	if current_profile == "":
		current_profile = username

	save_accounts()
	return {"ok": true, "message": "Account cached: " + current_profile, "username": current_profile, "email": email}


func cache_dev_test_account(raw_username: String, raw_email: String) -> Dictionary:
	var username_validation = validate_username(raw_username)

	if not bool(username_validation.get("ok", false)):
		return username_validation

	var email_validation = validate_email(raw_email)

	if not bool(email_validation.get("ok", false)):
		return email_validation

	var username = str(username_validation.get("username", ""))
	var email = normalize_email(str(email_validation.get("email", raw_email)))
	var profile_data = get_profile_data(username)
	var now = Time.get_datetime_string_from_system(false, true)

	if profile_data.is_empty():
		profiles.append({
			"username": username,
			"email": email,
			"server_account": false,
			"created_at": now,
			"last_login_at": now
		})
	else:
		profile_data["username"] = username
		profile_data["email"] = email
		profile_data["server_account"] = false
		if str(profile_data.get("created_at", "")) == "":
			profile_data["created_at"] = now
		profile_data["last_login_at"] = now

	current_profile = get_stored_username(username)
	if current_profile == "":
		current_profile = username

	save_accounts()
	return {"ok": true, "message": "Dev test account cached: " + current_profile, "username": current_profile, "email": email}


func create_or_switch_profile(raw_username: String) -> Dictionary:
	var validation = validate_username(raw_username)

	if not bool(validation.get("ok", false)):
		return validation

	var username = str(validation.get("username", ""))
	var session_profile = get_network_session_username()

	if session_profile == "":
		return {"ok": false, "message": "Sign on from the login screen first."}

	if username_key(session_profile) != username_key(username):
		return {"ok": false, "message": "Sign on as " + username + " from the login screen first."}

	var profile_data = get_profile_data(username)

	if is_registered_profile(profile_data):
		current_profile = get_stored_username(username)
		save_accounts()
		return {"ok": true, "message": "Account selected: " + current_profile, "created": false, "username": current_profile}

	return {"ok": false, "message": "Register this username on the login screen first."}


func has_active_profile() -> bool:
	var session_profile = get_network_session_username()
	return session_profile != "" and username_key(session_profile) == username_key(current_profile) and is_registered_profile(get_profile_data(current_profile))


func get_current_profile_name() -> String:
	var session_profile = get_network_session_username()
	if session_profile != "" and (current_profile == "" or username_key(session_profile) == username_key(current_profile)):
		return session_profile

	return current_profile


func get_current_profile_email() -> String:
	return get_email_for_username(current_profile)


func get_profile_count() -> int:
	return profiles.size()
