extends RefCounted

static func apply(items: Dictionary) -> Dictionary:
	var patches = JSON.parse_string(FileAccess.get_file_as_string("res://Data/items/item_data_overrides.json"))
	assert(patches is Dictionary, "Invalid ITEM DATA overrides")
	for id in patches:
		if not items.has(id) and patches[id].get("category", "") == "seed":
			items[id] = {}
		if items.has(id):
			items[id].merge(patches[id], true)
	return items
