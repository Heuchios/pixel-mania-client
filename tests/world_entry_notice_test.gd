extends SceneTree

class NoticeChat extends Node:
	var messages: Array = []
	func add_chat_message(sender: String, message: String, metadata: Dictionary) -> void:
		messages.append({"sender": sender, "message": message, "metadata": metadata})

class NoticeWorld extends Node:
	var world_lock_manager
	var block_manager
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}
	var anti_punch_states: Dictionary = {}
	var anti_talk_states: Dictionary = {}
	var anti_gravity_states: Dictionary = {}
	func handle_network_player_position(_data = {}) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := NoticeWorld.new()
	root.add_child(world)
	current_scene = world
	world.world_lock_manager = load("res://Scripts/world_lock_manager.gd").new()
	world.add_child(world.world_lock_manager)
	var ui := Node.new()
	ui.name = "UI"
	world.add_child(ui)
	var chat := NoticeChat.new()
	chat.name = "ChatUI"
	ui.add_child(chat)
	var network = root.get_node("NetworkManager")
	world.world_lock_manager.is_locked = true
	world.world_lock_manager.owner_name = "Alice"
	assert(network.build_world_presence_message("Uso", "START", true, 1) == "Uso entered, START. This world is locked by Alice, 1 other here.")
	world.world_lock_manager.is_locked = false
	assert(network.build_world_presence_message("Uso", "START", true, 0) == "Uso entered, START. This world is unlocked, 0 others here.")
	# Read the actual block manager's effective states, not just placed devices.
	world.block_manager = load("res://Scripts/block_manager.gd").new()
	world.block_manager.world = world
	world.blocks = {
		Vector2i(1, 1): {"type": "anti_punch"},
		Vector2i(2, 1): {"type": "anti_talk"},
		Vector2i(3, 1): {"type": "anti_gravity"},
	}
	assert(network.get_world_entry_flags("START").is_empty(), "Disabled devices must not be advertised")
	world.anti_punch_states[Vector2i(1, 1)] = {"state": {"enabled": true}}
	world.anti_talk_states[Vector2i(2, 1)] = {"state": {"enabled": true}}
	world.anti_gravity_states[Vector2i(3, 1)] = {"state": {"enabled": true}}
	world.blocks[Vector2i(4, 1)] = {"type": "snow_repellent"}
	assert(network.get_world_entry_flags("START") == PackedStringArray(["NOPUNCH", "NOTALK", "NOGRAVITY", "SNOWREPELLENT"]))
	var flags_message: String = network.build_world_presence_message("Uso", "START", true, 0)
	assert(flags_message.contains("START [NOPUNCH, NOTALK, NOGRAVITY, SNOWREPELLENT]."))
	assert(not network.build_world_presence_message("Uso", "START", false, 0).contains("["))
	assert(network.get_world_entry_flags("OTHER").is_empty(), "Never report the previous world's settings")
	world.anti_talk_states.clear()
	world.blocks.erase(Vector2i(1, 1))
	world.blocks.erase(Vector2i(4, 1))
	assert(network.get_world_entry_flags("START") == PackedStringArray(["NOGRAVITY"]), "Ignore disabled, removed, and stale device states")
	world.block_manager.free()
	world.block_manager = null
	var message := "LongPlayerName entered, LONGWORLDNAME [NOPUNCH, NOTALK, NOGRAVITY] (Honors: #151 today, #309 yesterday, #112 overall). This world is locked by AnotherLongPlayerName. " + "Additional world status. ".repeat(4) + "1 other here."
	assert(message.length() > 220)
	network.handle_chat_message({"type": "chat", "player_id": "system", "name": "System", "world": "START", "message": message})
	assert(chat.messages.size() == 1)
	assert(chat.messages[0].sender == "System")
	assert(chat.messages[0].message == message, "Full honors entry must survive network parsing")
	var chat_script = load("res://Scripts/chat_ui.gd")
	var real_chat = chat_script.new()
	var flags_runs: Array = real_chat.get_world_entry_color_runs(flags_message)
	assert(flags_runs[3].text == " [NOPUNCH, NOTALK, NOGRAVITY, SNOWREPELLENT]")
	assert(flags_runs[3].color == Color("8aef67"))
	assert(real_chat.is_system_chat_message(chat.messages[0].sender, chat.messages[0].metadata))
	var base := "Uso entered, SHOP. This world is locked by LOL, 0 others here."
	var honors := "World Honors for SHOP: Today #1 | Yesterday #309 | Overall #1. Use /honors for rankings."
	var expected := "Uso entered, SHOP (Honors: #1 today, #309 yesterday, #1 overall). This world is locked by LOL, 0 others here."
	for honors_first in [true, false]:
		real_chat.chat_messages.clear()
		real_chat._entry_honors_by_key.clear()
		var metadata := {"type": "chat", "world": "SHOP", "world_entry_key": "SHOP:join1:session1", "player_id": "system"}
		real_chat.add_chat_message("System", honors if honors_first else base, metadata)
		real_chat.add_chat_message("System", base if honors_first else honors, metadata)
		assert(real_chat.chat_messages.size() == 1, "Legacy notices must merge in both arrival orders")
		assert(real_chat.chat_messages[0].message == expected)
		real_chat.add_chat_message("System", base, metadata)
		real_chat.add_chat_message("System", expected, metadata)
		assert(real_chat.chat_messages.size() == 1, "Duplicates must not add entry rows")
		assert(real_chat.chat_messages[0].message == expected, "Fallback must not remove honors")
		metadata["world_entry_key"] = "SHOP:join2:session2"
		real_chat.add_chat_message("System", base, metadata)
		assert(real_chat.chat_messages.size() == 2, "Revisiting a world creates a new entry")
		assert(real_chat.chat_messages[1].message == base, "Revisits must not inherit stale honors")
	var colored := expected.replace("SHOP (", "SHOP [NOPUNCH, NOGRAVITY] (")
	var runs: Array = real_chat.get_world_entry_color_runs(colored)
	var rebuilt := ""
	var colors: Dictionary = {}
	for run in runs:
		rebuilt += str(run.text)
		colors[run.color] = true
	assert(rebuilt == colored, "Color spans must preserve the full message")
	assert(colors.size() >= 6, "Names, flags, honors and counts must have distinct colors")
	assert(real_chat.get_world_entry_color_runs("Chat ready.").is_empty())
	# Use the actual RichTextLabel renderer; BBCode-looking names stay literal.
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = false
	real_chat.append_world_entry_runs(rich, runs)
	assert(rich.get_parsed_text() == "System: " + colored)
	rich.free()
	real_chat.free()
	print("[world-entry-notice] merge order, duplicate suppression, re-entry, rich colors, counts, and long messages passed")
	world.free()
	quit()
