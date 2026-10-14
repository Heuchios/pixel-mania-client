extends Node

const Atlas = preload("res://Scripts/atlas_texture_factory.gd")
const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const Follower = preload("res://Scripts/pet_follower.gd")
var world
var states: Dictionary = {}
var overlays: Dictionary = {}
var followers: Dictionary = {}
var overlay: Control
var panel: PanelContainer
var content: VBoxContainer
var grid := Vector2i.ZERO
var station_type := ""
var title: Label
var status: Label
var input_slot: TextureRect
var output_slot: TextureRect
var chunk_slot: TextureRect
var selection: OptionButton
var count: SpinBox
var insert: Button
var chunks: Button
var upgrade: Button
var claim: Button
var remove: Button
var current: Dictionary = {}
var poll := 0.0
var encounter_poll := 0.0
var clock_offset := 0.0
var last_world := ""
var visual_refresh := 0.0

func _ready() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	last_world = str(network.current_world_name) if network != null else ""

func request(action: String, extra: Dictionary = {}) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	var payload := {"action":action,"x":grid.x,"y":grid.y}
	payload.merge(extra, true)
	var sent: bool = network.send_inventory_transaction_request(payload)
	if not sent and action not in ["incubator_get_state", "pet_encounter"]:
		world.show_notification("Could not send pet request. Check your connection and try again.")
	return sent

func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	Style.apply_blue_button(button)
	button.pressed.connect(action)
	return button

func _slot(label_text: String, row: HBoxContainer) -> TextureRect:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var label := Label.new()
	Style.apply_label_shadow(label)
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(64,64)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(image)
	image.set_meta("label", label)
	return image

func build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	world.ui_layer.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.04,0.09,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.premium_panel_style())
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+edge, 20)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	title = Label.new()
	Style.apply_section_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("X", func(): overlay.hide())
	Style.apply_close_button(close)
	header.add_child(close)
	var slots := HBoxContainer.new()
	content.add_child(slots)
	input_slot = _slot("Egg / Pet", slots)
	chunk_slot = _slot("Fish Chunks", slots)
	chunk_slot.texture = Atlas.load_texture(world.item_database.fish_chunk.texture)
	output_slot = _slot("Output", slots)
	status = Label.new()
	Style.apply_label_shadow(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	selection = OptionButton.new()
	selection.custom_minimum_size.y = 42
	selection.clip_text = true
	selection.item_selected.connect(func(_index): refresh_ui())
	content.add_child(selection)
	insert = _button("Insert Egg / Pet", func(): request("incubator_insert", {"item_id":selected_id()}))
	content.add_child(insert)
	var amount_row := HBoxContainer.new()
	content.add_child(amount_row)
	count = SpinBox.new()
	count.min_value = 1
	count.max_value = 10000
	count.value = 1
	count.value_changed.connect(func(_value): refresh_ui())
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.apply_input(count.get_line_edit())
	amount_row.add_child(count)
	chunks = _button("Add Chunks", func(): request("sashimi_chop" if station_type == "sashimi_table" else "incubator_add_chunks", {"item_id":selected_id(),"amount":int(count.value)}))
	amount_row.add_child(chunks)
	upgrade = _button("Upgrade Pet", func(): request("incubator_upgrade"))
	Style.apply_yellow_button(upgrade)
	content.add_child(upgrade)
	claim = _button("Claim Pet", func(): request("incubator_claim"))
	Style.apply_green_button(claim)
	content.add_child(claim)
	remove = _button("Remove Pet & Chunks", func(): request("incubator_remove"))
	content.add_child(remove)
	overlay.hide()

func selected_id() -> String:
	return str(selection.get_item_metadata(selection.selected)) if selection.selected >= 0 else ""

func open_station(position: Vector2i, type: String) -> void:
	if not is_instance_valid(overlay):
		build_ui()
	grid = position
	station_type = type
	current = states.get(grid, {})
	selection.clear()
	var inventory: Dictionary = world.fish_inventory.duplicate() if type == "sashimi_table" else world.pet_inventory.duplicate()
	if type == "incubator":
		inventory["golden_egg"] = int(world.material_inventory.get("golden_egg",0))
	for id in inventory:
		var data: Dictionary = world.item_database.get(id, {})
		if int(inventory[id]) <= 0:
			continue
		if type != "sashimi_table" and id != "golden_egg" and (not data.has("pet_species") or int(data.get("pet_level",3)) >= 3):
			continue
		var label := str(data.get("display_name", id))
		if type == "sashimi_table":
			label += " — %.1f kg" % (float(inventory[id])/10.0)
		selection.add_icon_item(Atlas.load_texture(data.get("inventory_icon",data.get("texture"))),label)
		selection.set_item_metadata(selection.item_count-1, id)
	overlay.show()
	refresh_ui()
	if type == "incubator":
		request("incubator_get_state")

func apply_state(data: Dictionary) -> void:
	var pos := Vector2i(int(data.get("x",0)),int(data.get("y",0)))
	if data.has("server_time_ms"):
		clock_offset = float(data.server_time_ms)/1000.0 - Time.get_unix_time_from_system()
	states[pos] = data.duplicate(true)
	if pos == grid:
		current = data.duplicate(true)
		refresh_ui()

func apply_result(data: Dictionary) -> void:
	var action := str(data.get("action", ""))
	if not action.begins_with("incubator_") and not action.begins_with("pet_") and action != "sashimi_chop":
		return
	if data.get("ok",false):
		if data.has("equipped_pet_item"):
			world.equipped_pet_item = str(data.equipped_pet_item)
		if data.get("incubator") is Dictionary:
			apply_state(data.incubator)
		world.update_all_ui()
	else:
		world.show_notification(str(data.get("message","Could not use this station.")))
	refresh_ui()

func time_left(data: Dictionary) -> int:
	return maxi(0, int(ceil(float(data.get("ready_at_ms",0))/1000.0 - Time.get_unix_time_from_system() - clock_offset)))

func refresh_ui() -> void:
	if not is_instance_valid(status):
		return
	var sashimi := station_type == "sashimi_table"
	title.text = "Sashimi Table" if sashimi else "Pet Incubator"
	insert.visible = not sashimi
	upgrade.visible = not sashimi
	claim.visible = not sashimi
	remove.visible = not sashimi
	chunks.text = "Chop Fish" if sashimi else "Add Chunks"
	var id := str(current.get("input_item",""))
	var busy := int(current.get("ready_at_ms",0)) > 0
	var ready := busy and time_left(current) == 0
	var required := int(current.get("upgrade_cost",0))
	input_slot.texture = Atlas.load_texture(world.item_database.get(id,{}).get("texture"))
	output_slot.texture = Atlas.load_texture(world.item_database.get(str(current.get("output_item","")),{}).get("texture")) if ready else null
	input_slot.get_meta("label").text = "Fish" if sashimi else "Egg / Pet"
	output_slot.get_meta("label").text = "Fish Chunks" if sashimi else "Output"
	chunk_slot.get_parent().visible = not sashimi
	if sashimi:
		input_slot.texture = Atlas.load_texture(world.item_database.get(selected_id(),{}).get("texture"))
		output_slot.texture = Atlas.load_texture(world.item_database.fish_chunk.texture)
	insert.disabled = id != "" or selection.item_count == 0
	chunks.disabled = selection.item_count == 0 if sashimi else (id == "" or id == "golden_egg" or busy)
	upgrade.disabled = required <= 0 or int(current.get("chunks",0)) < required or busy
	claim.disabled = not ready
	remove.disabled = id == "" or busy
	if sashimi:
		status.text = "Choose a fish. Every 50 kg makes 1 Fish Chunk.\nQuantity below is the number of chunks to make."
	elif id == "":
		status.text = "Insert a Golden Egg to hatch a level 1 pet.\nPets upgrade to level 2 for 250 chunks and level 3 for 750."
	elif busy:
		var seconds := time_left(current)
		status.text = "Your pet is ready to claim!" if ready else ("Hatching… %02d:%02d:%02d remaining" if id == "golden_egg" else "Upgrading… %02d:%02d:%02d remaining") % [seconds/3600,(seconds/60)%60,seconds%60]
	else:
		status.text = "%s\nFish Chunks: %d / %d\nStored chunks fill the Incubator. Press Upgrade when full." % [world.item_database.get(id,{}).get("display_name",id),int(current.get("chunks",0)),required]

func _process(delta: float) -> void:
	if world == null:
		return
	var network = get_node_or_null("/root/NetworkManager")
	var world_name := str(network.current_world_name) if network != null else ""
	if world_name != last_world:
		last_world = world_name
		states.clear()
		for visual in overlays.values():
			visual.queue_free()
		overlays.clear()
		if is_open():
			overlay.hide()
	if not world.in_world:
		for follower in followers.values():
			follower.queue_free()
		followers.clear()
		return
	if is_open():
		var viewport := overlay.get_viewport_rect().size
		panel.size = Vector2(minf(620,viewport.x-32),minf(640,viewport.y-32))
		panel.position = (viewport-panel.size)*0.5
		refresh_ui()
		poll -= delta
		if poll <= 0 and station_type == "incubator":
			poll = 2.0
			request("incubator_get_state")
	encounter_poll -= delta
	if encounter_poll <= 0 and world.equipped_pet_item != "":
		encounter_poll = 10.0
		request("pet_encounter")
	visual_refresh -= delta
	if visual_refresh <= 0:
		visual_refresh = 0.1
		update_followers()
		update_incubators()

func update_followers() -> void:
	if world.equipped_pet_item != "" and int(world.pet_inventory.get(world.equipped_pet_item,0)) <= 0:
		world.equipped_pet_item = ""
	var actors: Dictionary = {"local": {"actor":world.player,"item":world.equipped_pet_item}}
	if world.player_manager != null:
		for id in world.player_manager.remote_players:
			var actor = world.player_manager.remote_players[id]
			actors[id] = {"actor":actor,"item":str(actor.get_meta("equipment_slots",{}).get("pet",""))}
	for id in followers.keys():
		if not actors.has(id) or str(actors[id].item) != str(followers[id].get_meta("item_id","")):
			followers[id].queue_free()
			followers.erase(id)
	for id in actors:
		var entry: Dictionary = actors[id]
		var definition: Dictionary = world.item_database.get(str(entry.item),{})
		if not definition.has("pet_species") or not is_instance_valid(entry.actor) or followers.has(id):
			continue
		var follower = Follower.new()
		follower.target = entry.actor
		follower.item = definition
		follower.set_meta("item_id",entry.item)
		world.add_child(follower)
		followers[id] = follower

func update_incubators() -> void:
	for pos in overlays.keys():
		if not world.blocks.has(pos) or world.blocks[pos].get("type","") != "incubator":
			overlays[pos].queue_free()
			overlays.erase(pos)
			states.erase(pos)
	for pos in states:
		if not world.blocks.has(pos) or world.blocks[pos].get("type","") != "incubator":
			continue
		var visual: Sprite2D
		if not overlays.has(pos):
			visual = Sprite2D.new()
			visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			visual.position = world.grid_to_world_center(pos)
			visual.z_index = 5
			world.add_child(visual)
			var input := Sprite2D.new()
			input.name = "Input"
			input.scale = Vector2(0.45,0.45)
			visual.add_child(input)
			overlays[pos] = visual
		visual = overlays[pos]
		var data: Dictionary = states[pos]
		var id := str(data.get("input_item",""))
		var frame := 0
		if id != "":
			frame = 1
			if int(data.get("ready_at_ms",0)) > 0:
				var duration := maxf(1,float(data.ready_at_ms)-float(data.get("started_at_ms",0)))
				frame = 1 + mini(4,int(4*(1-float(time_left(data))*1000/duration)))
			else:
				var required := int(data.get("upgrade_cost",250 if int(world.item_database.get(id,{}).get("pet_level",1)) == 1 else 750))
				frame = 1+mini(4,int(4*float(data.get("chunks",0))/maxi(1,required)))
		visual.texture = Atlas.load_texture({"atlas":"res://image.png","cell":[15+frame,16],"cell_size":[32,32]})
		var input: Sprite2D = visual.get_node("Input")
		input.texture = Atlas.load_texture(world.item_database.get(id,{}).get("texture"))
		input.position.y = -3 + sin(Time.get_ticks_msec()/300.0)*2
		var mouse: Vector2i = world.get_mouse_grid_position()
		if mouse == pos and id != "":
			if not visual.has_node("Timer"):
				var label := Label.new()
				label.name = "Timer"
				label.position = Vector2(-55,-42)
				label.scale = Vector2(0.5,0.5)
				visual.add_child(label)
			visual.get_node("Timer").text = "%ds left" % time_left(data) if int(data.get("ready_at_ms",0)) > 0 and time_left(data)>0 else ("Ready!" if int(data.get("ready_at_ms",0))>0 else "%d chunks" % int(data.get("chunks",0)))
		elif visual.has_node("Timer"):
			visual.get_node("Timer").queue_free()
