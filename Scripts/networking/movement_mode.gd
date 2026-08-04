extends Node

enum Mode {
	WEBSOCKET,
	NETFOX_TEST,
	NETFOX_REAL,
	CUSTOM_AUTHORITATIVE
}

var current_mode: int = Mode.WEBSOCKET
var dev_test_login_security_reported := false
var backend_dev_login_security_reported := false
var startup_args_logged := false
var disabled_netfox_reported := false
var custom_runtime_disabled_reported := false
var websocket_movement_version := "websocket_v1"
var websocket_movement_debug_enabled := false

const PHASE7_TEST_ARG := "--phase7-test"
const NETFOX_ARCHIVE_TEST_ARG := "--netfox-archive-test"
const NETFOX_REAL_ARG := "--netfox-real"
const NETFOX_SERVER_ARG := "--netfox-server"
const NETFOX_CLIENT_ARG := "--netfox-client"
const WEBSOCKET_MOVEMENT_ARG := "--websocket-movement"
const CUSTOM_MOVEMENT_ARG := "--custom-movement"
const CUSTOM_MOVEMENT_TEST_ARG := "--custom-movement-test"
const CUSTOM_MOVEMENT_BACKEND_ARG := "--custom-movement-backend"
const CUSTOM_MOVEMENT_ACTIONS_ARG := "--custom-actions-enabled"
const MOVEMENT_MODE_ENV := "PIXELMANIA_MOVEMENT_MODE"
const NETFOX_ROLE_ENV := "PIXELMANIA_NETFOX_ROLE"
const MOVEMENT_VERSION_ENV := "MOVEMENT_VERSION"
const MOVEMENT_VERSION_ENV_ALT := "PIXELMANIA_MOVEMENT_VERSION"
const DEV_TOOLS_ENV := "PIXELMANIA_ALLOW_DEV_TOOLS"
const MOVEMENT_DEBUG_ARG := "--movement-debug"
const MOVEMENT_DEBUG_ENV := "PIXELMANIA_MOVEMENT_DEBUG"
const DEFAULT_MOVEMENT_PROJECT_SETTING := "pixelmania/movement/default_mode"
const NETFOX_ROLE_PROJECT_SETTING := "pixelmania/netfox/default_role"
const NETFOX_AUTOLOAD_NAMES := [
	"NetworkTime",
	"NetworkTimeSynchronizer",
	"NetworkRollback",
	"NetworkEvents",
	"NetworkPerformance",
	"RollbackSimulationServer",
	"NetworkHistoryServer",
	"NetworkSynchronizationServer",
	"NetworkIdentityServer",
	"NetworkCommandServer",
	"RollbackLivenessServer",
	"NetworkSimulator",
]


func _ready() -> void:
	log_startup_args()
	current_mode = _resolve_startup_mode()
	websocket_movement_version = _resolve_websocket_movement_version()
	websocket_movement_debug_enabled = is_websocket_movement_debug_enabled()

	if is_custom_movement_launch_requested():
		report_custom_runtime_disabled()

	if is_dev_test_login_requested() and not is_dev_test_login_allowed():
		report_dev_test_login_rejected()
	if is_backend_dev_login_requested() and not is_backend_dev_login_allowed():
		report_backend_dev_login_rejected()

	print("[Movement] Active mode: " + get_mode_name())
	print("[Movement] Active version: " + get_websocket_movement_version())
	call_deferred("enforce_netfox_runtime_state")


func is_websocket() -> bool:
	return current_mode == Mode.WEBSOCKET


func is_netfox_test() -> bool:
	return current_mode == Mode.NETFOX_TEST


func is_netfox_real() -> bool:
	return current_mode == Mode.NETFOX_REAL


func is_custom_authoritative() -> bool:
	return current_mode == Mode.CUSTOM_AUTHORITATIVE


func should_run_websocket_backend() -> bool:
	if is_check_only_launch():
		return false
	if is_netfox_real_server_launch():
		return false
	if is_dev_test_login_active():
		return false
	return current_mode != Mode.NETFOX_TEST


func is_check_only_launch() -> bool:
	return has_launch_arg("--check-only")


func set_mode(new_mode) -> void:
	var resolved_mode := _resolve_mode(new_mode)
	if resolved_mode == -1:
		push_warning("[Movement] Ignored invalid movement mode: " + str(new_mode))
		return

	if resolved_mode == Mode.NETFOX_TEST and not is_archived_netfox_test_allowed():
		report_netfox_runtime_disabled()
		current_mode = Mode.WEBSOCKET
		print("[Movement] Active mode: " + get_mode_name())
		print("[Movement] Active version: " + get_websocket_movement_version())
		call_deferred("enforce_netfox_runtime_state")
		return
	if resolved_mode == Mode.CUSTOM_AUTHORITATIVE:
		report_custom_runtime_disabled()
		current_mode = Mode.WEBSOCKET
		print("[Movement] Active mode: " + get_mode_name())
		print("[Movement] Active version: " + get_websocket_movement_version())
		call_deferred("enforce_netfox_runtime_state")
		return

	current_mode = resolved_mode
	print("[Movement] Active mode: " + get_mode_name())
	print("[Movement] Active version: " + get_websocket_movement_version())
	call_deferred("enforce_netfox_runtime_state")


func get_mode_name() -> String:
	match current_mode:
		Mode.WEBSOCKET:
			return "WEBSOCKET"
		Mode.NETFOX_TEST:
			return "NETFOX_TEST"
		Mode.NETFOX_REAL:
			return "NETFOX_REAL"
		Mode.CUSTOM_AUTHORITATIVE:
			return "CUSTOM_AUTHORITATIVE"
		_:
			return "UNKNOWN"


func get_websocket_movement_version() -> String:
	return websocket_movement_version


func is_websocket_v2() -> bool:
	return false


func is_websocket_v2_debug_enabled() -> bool:
	return false


func _resolve_mode(value) -> int:
	if value is int:
		if value == Mode.WEBSOCKET or value == Mode.NETFOX_TEST or value == Mode.NETFOX_REAL or value == Mode.CUSTOM_AUTHORITATIVE:
			return int(value)
		return -1

	var mode_name := str(value).strip_edges().to_upper()
	match mode_name:
		"WEBSOCKET":
			return Mode.WEBSOCKET
		"NETFOX_TEST":
			return Mode.NETFOX_TEST
		"NETFOX", "NETFOX_REAL":
			return Mode.NETFOX_REAL
		"CUSTOM_AUTHORITATIVE", "CUSTOM_MOVEMENT", "CUSTOM_ENET":
			return Mode.CUSTOM_AUTHORITATIVE
		_:
			return -1


func _resolve_startup_mode() -> int:
	if is_websocket_movement_launch_requested():
		return Mode.WEBSOCKET

	if _startup_requests_netfox_real():
		return Mode.NETFOX_REAL

	if _has_netfox_test_launch_args() or has_launch_arg(PHASE7_TEST_ARG):
		if is_archived_netfox_test_allowed():
			return Mode.NETFOX_TEST
		report_netfox_runtime_disabled()

	return Mode.WEBSOCKET


func _has_netfox_test_launch_args() -> bool:
	for arg in get_all_cmdline_args():
		if str(arg).find("netfox_test") != -1:
			return true

	return false


func _has_netfox_real_launch_arg() -> bool:
	return has_launch_arg(NETFOX_REAL_ARG)


func is_netfox_real_launch_requested() -> bool:
	return _startup_requests_netfox_real()


func is_netfox_real_server_launch() -> bool:
	return is_netfox_real() and get_netfox_role("") == "server"


func is_netfox_real_client_launch() -> bool:
	return is_netfox_real() and get_netfox_role("") == "client"


func is_websocket_movement_launch_requested() -> bool:
	return has_launch_arg(WEBSOCKET_MOVEMENT_ARG) or _env_requests_websocket_movement()


func is_custom_movement_launch_requested() -> bool:
	if has_launch_arg(CUSTOM_MOVEMENT_ARG):
		return true
	if is_custom_movement_test_launch_requested():
		return true
	return _env_requests_custom_movement()


func is_custom_movement_server_launch() -> bool:
	return is_custom_authoritative() and has_launch_arg("--server") and not has_launch_arg("--client")


func is_custom_movement_client_launch() -> bool:
	return is_custom_authoritative() and has_launch_arg("--client") and not has_launch_arg("--server")


func is_dev_test_login_requested() -> bool:
	return has_launch_arg("--dev-test-login")


func is_backend_dev_login_requested() -> bool:
	return has_launch_arg("--backend-dev-login")


func is_phase7_test_requested() -> bool:
	return false


func is_phase7_backend_dev_login_requested() -> bool:
	return false


func is_dev_test_login_allowed() -> bool:
	if not OS.is_debug_build():
		return false

	return is_archived_netfox_test_allowed()


func is_backend_dev_login_allowed() -> bool:
	if not OS.is_debug_build():
		return false

	return is_archived_netfox_test_allowed() or is_custom_movement_dev_tools_allowed()


func is_dev_test_login_active() -> bool:
	return is_dev_test_login_requested() and is_dev_test_login_allowed()


func is_backend_dev_login_active() -> bool:
	return is_backend_dev_login_requested() and is_backend_dev_login_allowed()


func report_dev_test_login_rejected() -> void:
	if dev_test_login_security_reported:
		return

	dev_test_login_security_reported = true
	print("[SECURITY] Dev test login is disabled outside development.")


func report_backend_dev_login_rejected() -> void:
	if backend_dev_login_security_reported:
		return

	backend_dev_login_security_reported = true
	print("[SECURITY] Backend dev login is disabled outside development.")


func report_netfox_runtime_disabled() -> void:
	if disabled_netfox_reported:
		return

	disabled_netfox_reported = true
	print("[Movement] Archived Netfox test runtime is disabled. Using WEBSOCKET movement.")


func report_custom_runtime_disabled() -> void:
	if custom_runtime_disabled_reported:
		return

	custom_runtime_disabled_reported = true
	print("[Movement] Custom authoritative movement is disabled. Using WEBSOCKET movement.")


func enforce_netfox_runtime_state() -> void:
	if is_netfox_real() or is_netfox_test():
		return
	shutdown_netfox_autoload_runtime()


func shutdown_netfox_autoload_runtime() -> void:
	var root: Window = null
	if get_tree() != null:
		root = get_tree().root
	if root == null:
		return
	for autoload_name in NETFOX_AUTOLOAD_NAMES:
		var node := root.get_node_or_null(str(autoload_name))
		if node == null:
			continue
		if node.has_method("stop"):
			node.call("stop")
		node.set_process(false)
		node.set_physics_process(false)
		node.set_process_input(false)
		node.set_process_unhandled_input(false)


func get_dev_test_world_name(default_world_name: String = "NETFOX_TEST") -> String:
	var raw_world_name := get_launch_arg_value("--world", default_world_name)
	return _sanitize_launch_world_name(raw_world_name, default_world_name)


func get_dev_profile_name(default_profile_name: String = "DevNetfox") -> String:
	var raw_profile_name := get_launch_arg_value("--dev-profile", "")
	if raw_profile_name.strip_edges() == "":
		var process_suffix: String = str(OS.get_process_id()) if OS.has_method("get_process_id") else str(Time.get_ticks_msec())
		raw_profile_name = "%s_%s" % [default_profile_name, process_suffix]
	return _sanitize_dev_profile_name(raw_profile_name, default_profile_name)


func _is_development_environment() -> bool:
	var environment := OS.get_environment("ENVIRONMENT").strip_edges().to_lower()
	if environment == "development":
		return true

	var node_environment := OS.get_environment("NODE_ENV").strip_edges().to_lower()
	return node_environment == "development"


func is_archived_netfox_test_allowed() -> bool:
	if not has_launch_arg(NETFOX_ARCHIVE_TEST_ARG):
		return false
	if not OS.is_debug_build():
		return false
	if not _is_development_environment():
		return false
	return _is_truthy_env(OS.get_environment(DEV_TOOLS_ENV))


func is_custom_movement_test_launch_requested() -> bool:
	if has_launch_arg(CUSTOM_MOVEMENT_TEST_ARG):
		return true

	for arg in get_all_cmdline_args():
		if str(arg).find("custom_movement_test") != -1:
			return true

	return false


func is_custom_movement_backend_enabled() -> bool:
	return false


func is_custom_movement_dev_tools_allowed() -> bool:
	return false


func _has_netfox_or_test_launch_arg() -> bool:
	return _has_netfox_real_launch_arg() or has_launch_arg(NETFOX_SERVER_ARG) or has_launch_arg(NETFOX_CLIENT_ARG) or _has_netfox_test_launch_args() or has_launch_arg(PHASE7_TEST_ARG)


func _movement_mode_env_value() -> String:
	return OS.get_environment(MOVEMENT_MODE_ENV).strip_edges().to_lower()


func _startup_requests_netfox_real() -> bool:
	if _has_netfox_real_launch_arg() or has_launch_arg(NETFOX_SERVER_ARG) or has_launch_arg(NETFOX_CLIENT_ARG):
		return true
	if _env_requests_netfox_real():
		return true
	return _project_default_requests_netfox_real()


func _env_requests_custom_movement() -> bool:
	var value := _movement_mode_env_value()
	return ["custom", "custom_authoritative", "custom_movement", "custom_enet"].has(value)


func _env_requests_netfox_real() -> bool:
	var value := _movement_mode_env_value()
	return ["netfox", "netfox_real", "netfox-real"].has(value)


func _env_requests_websocket_movement() -> bool:
	var value := _movement_mode_env_value()
	return ["websocket", "ws"].has(value)


func _project_default_movement_mode() -> String:
	if not ProjectSettings.has_setting(DEFAULT_MOVEMENT_PROJECT_SETTING):
		return ""
	return str(ProjectSettings.get_setting(DEFAULT_MOVEMENT_PROJECT_SETTING, "")).strip_edges().to_upper()


func _project_default_requests_netfox_real() -> bool:
	var mode_name := _project_default_movement_mode()
	return mode_name == "NETFOX" or mode_name == "NETFOX_REAL"


func get_netfox_role(default_role: String = "standalone") -> String:
	var wants_server: bool = has_launch_arg("--server") or has_launch_arg(NETFOX_SERVER_ARG)
	var wants_client: bool = has_launch_arg("--client") or has_launch_arg(NETFOX_CLIENT_ARG)
	if wants_server and not wants_client:
		return "server"
	if wants_client and not wants_server:
		return "client"

	var launch_role: String = get_launch_arg_value("--netfox-role", "").strip_edges().to_lower()
	if launch_role == "":
		launch_role = get_launch_arg_value("--movement-role", "").strip_edges().to_lower()
	var env_role: String = OS.get_environment(NETFOX_ROLE_ENV).strip_edges().to_lower()
	var project_role: String = ""
	if ProjectSettings.has_setting(NETFOX_ROLE_PROJECT_SETTING):
		project_role = str(ProjectSettings.get_setting(NETFOX_ROLE_PROJECT_SETTING, "")).strip_edges().to_lower()

	for role in [launch_role, env_role, project_role, default_role]:
		var clean_role: String = str(role).strip_edges().to_lower()
		if ["server", "client", "standalone"].has(clean_role):
			return clean_role

	return "standalone"


func _movement_version_env_value() -> String:
	var value := OS.get_environment(MOVEMENT_VERSION_ENV).strip_edges().to_lower()
	if value != "":
		return value
	return OS.get_environment(MOVEMENT_VERSION_ENV_ALT).strip_edges().to_lower()


func _resolve_websocket_movement_version() -> String:
	return "websocket_v1"


func is_websocket_movement_debug_enabled() -> bool:
	if has_launch_arg(MOVEMENT_DEBUG_ARG):
		return true
	return _is_truthy_env(OS.get_environment(MOVEMENT_DEBUG_ENV))


func _is_truthy_env(value: String) -> bool:
	var clean_value := value.strip_edges().to_lower()
	return clean_value == "1" or clean_value == "true" or clean_value == "yes" or clean_value == "on" or clean_value == "enabled"


func get_all_cmdline_args() -> Array:
	var combined: Array = []
	for arg in OS.get_cmdline_args():
		combined.append(str(arg))
	for arg in OS.get_cmdline_user_args():
		var clean_arg := str(arg)
		if not combined.has(clean_arg):
			combined.append(clean_arg)
	return combined


func log_startup_args() -> void:
	if startup_args_logged:
		return

	startup_args_logged = true
	print("[Movement] Raw command-line args: " + str(OS.get_cmdline_args()))
	print("[Movement] Raw user args: " + str(OS.get_cmdline_user_args()))
	print("[Movement] Parsed launch args: " + str(get_all_cmdline_args()))


func has_launch_arg(flag_name: String) -> bool:
	var args := get_all_cmdline_args()
	return args.has(flag_name)


func get_launch_arg_value(flag_name: String, default_value: String = "") -> String:
	var args := get_all_cmdline_args()
	for i in range(args.size()):
		var arg := str(args[i])
		if arg == flag_name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with(flag_name + "="):
			var inline_value := arg.substr(flag_name.length() + 1)
			if inline_value != "":
				return inline_value
			if i + 1 < args.size():
				return str(args[i + 1])
			return ""

	return default_value


func _sanitize_launch_world_name(raw_world_name: String, default_world_name: String) -> String:
	var clean_name := raw_world_name.strip_edges()
	if clean_name == "":
		clean_name = default_world_name.strip_edges()
	if clean_name == "":
		clean_name = "NETFOX_TEST"

	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result := ""
	for i in range(clean_name.length()):
		var character := clean_name.substr(i, 1)
		if allowed.find(character) != -1:
			result += character

	if result == "":
		result = "NETFOX_TEST"

	return result.to_upper()


func _sanitize_dev_profile_name(raw_profile_name: String, default_profile_name: String) -> String:
	var clean_name := raw_profile_name.strip_edges()
	if clean_name == "":
		clean_name = default_profile_name.strip_edges()
	if clean_name == "":
		clean_name = "DevNetfox"

	var result := ""
	for i in range(clean_name.length()):
		var character := clean_name.substr(i, 1)
		var code := clean_name.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or character == "_":
			result += character

	if result == "":
		result = "DevNetfox"
	if result.length() > 24:
		result = result.substr(0, 24)

	return result
