extends SceneTree


const VENDING_SCENE_PATH := "res://Scenes/ui/vending/VendingMachineGUI.tscn"
const STYLE_DIRECTORY := "res://Scenes/ui/vending/styles/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(VENDING_SCENE_PATH) as PackedScene
	if packed_scene == null:
		fail_test("Could not load the vending scene.")
		return

	var vending_ui := packed_scene.instantiate()
	var checks: Array[Dictionary] = [
		{"node": "VendingPanel/StatusBack/Status", "style": "normal"},
		{"node": "VendingPanel/CloseButton", "style": "normal"},
		{"node": "VendingPanel/CloseButton", "style": "pressed"},
		{"node": "VendingPanel/CloseButton", "style": "hover"},
		{"node": "VendingPanel/CloseButton", "style": "focus"},
		{"node": "VendingPanel/ItemCard/ItemSlot", "style": "normal"},
		{"node": "VendingPanel/ItemCard/ItemSlot", "style": "pressed"},
		{"node": "VendingPanel/ItemCard/ItemSlot", "style": "hover"},
		{"node": "VendingPanel/ListButton", "style": "normal"},
		{"node": "VendingPanel/ListButton", "style": "pressed"},
		{"node": "VendingPanel/ListButton", "style": "hover"},
		{"node": "VendingPanel/BuyButton", "style": "normal"},
		{"node": "VendingPanel/CollectButton", "style": "normal"},
		{"node": "VendingPanel/LogButton", "style": "normal"},
		{"node": "VendingPanel/LogButton", "style": "pressed"},
		{"node": "VendingPanel/LogButton", "style": "hover"},
		{"node": "VendingPanel/CancelListingButton", "style": "normal"},
		{"node": "VendingPanel/CancelListingButton", "style": "pressed"},
		{"node": "VendingPanel/CancelListingButton", "style": "hover"},
		{"node": "VendingPanel/VendingLogOverlay/CloseButton", "style": "normal"},
	]

	for check: Dictionary in checks:
		var node_path := String(check.get("node", ""))
		var style_name := String(check.get("style", ""))
		var control := vending_ui.get_node_or_null(node_path) as Control
		if control == null:
			vending_ui.free()
			fail_test("Missing control: " + node_path)
			return
		var style_box := control.get_theme_stylebox(style_name)
		if style_box == null:
			vending_ui.free()
			fail_test("Missing style %s on %s." % [style_name, node_path])
			return
		if not style_box.resource_path.begins_with(STYLE_DIRECTORY):
			var resource_path := style_box.resource_path
			vending_ui.free()
			fail_test(
				"Style %s on %s is not external: %s" % [
					style_name,
					node_path,
					resource_path,
				]
			)
			return

	vending_ui.free()
	print("[vending-ui-external-styles] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[vending-ui-external-styles] " + message)
	quit(1)
