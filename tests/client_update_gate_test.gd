extends SceneTree

class AndroidGate:
	extends "res://Scripts/ui/client_update_required_overlay.gd"
	var opened: Array[String] = []
	var package_version := "null"
	func _ready() -> void:
		pass
	func _platform_kind() -> String:
		return "android"
	func _android_package_version() -> String:
		return package_version
	func _open_update_url(url: String) -> Error:
		opened.append(url)
		return OK

class NetworkProbe:
	extends RefCounted
	const CLIENT_VERSION := "1.2.2"
	var payloads: Array[Dictionary] = []
	var compare: Callable
	func _compare_client_versions(a: String, b: String) -> int:
		return compare.call(a, b)
	func _store_client_update_payload(payload: Dictionary) -> void:
		payloads.append(payload)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var gate := AndroidGate.new()
	root.add_child(gate)
	var network := NetworkProbe.new()
	network.compare = root.get_node("NetworkManager")._compare_client_versions
	gate._network = network
	for invalid in ["null", "<null>", "", "unknown", "1.2", "1.2.x"]:
		gate.package_version = invalid
		assert(gate._installed_version() == network.CLIENT_VERSION, "Invalid native version must use the build version")
		gate._on_release_checked(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"published":true,"min_client_version":"1.2.1"}).to_utf8_buffer())
	assert(network.payloads.is_empty(), "Null metadata must not force an update on an up-to-date build")
	gate.package_version = "1.2.0"
	gate._on_release_checked(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"published":false,"min_client_version":"1.2.1"}).to_utf8_buffer())
	gate._on_release_checked(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"published":true,"min_client_version":"null"}).to_utf8_buffer())
	assert(network.payloads.is_empty(), "Disabled or malformed manifests must not block players")
	gate._on_release_checked(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"published":true,"min_client_version":"1.2.1"}).to_utf8_buffer())
	assert(network.payloads.size() == 1 and network.payloads[0].client_version == "1.2.0", "A real older version is still detected")
	var payload := {"client_version":"1.0.0", "min_client_version":"1.2.0", "update_url":"https://untrusted.example/play.google.com"}
	gate._on_client_update_required(payload)
	gate._on_client_update_required(payload)
	await process_frame
	assert(gate.opened.size() == 1, "Auto-open only once, including repeated server packets")
	assert(gate.opened[0] == gate.PLAY_STORE_APP_URL)
	assert(gate.is_gate_visible(), "Returning without updating must keep the gate")
	assert(gate._build_update_urls() == [gate.PLAY_STORE_APP_URL, gate.PLAY_STORE_WEB_URL])
	gate._on_update_pressed()
	assert(gate.opened.size() == 2, "The player can retry manually")
	gate.queue_free()
	print("CLIENT_UPDATE_GATE_PASS")
	quit()
