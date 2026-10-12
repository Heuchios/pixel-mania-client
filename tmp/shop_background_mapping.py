from pathlib import Path
p=Path('Scripts/UIAtlasDB.gd');s=p.read_text(encoding='utf-8');s=s.replace('const REGIONS := {','''const REGIONS := {
	"shop_card_normal": {"cell": Vector2i(8, 11), "size_in_atlas": Vector2i(3, 3)},
	"shop_card_legendary": {"cell": Vector2i(11, 11), "size_in_atlas": Vector2i(3, 3)},
	"shop_card_special": {"cell": Vector2i(14, 11), "size_in_atlas": Vector2i(3, 3)},''');p.write_text(s,encoding='utf-8')
p=Path('Scripts/shop_ui.gd');s=p.read_text(encoding='utf-8');mark='func bind_item_card(card: Button, item: Dictionary, category_key: String) -> void:'
s=s.replace(mark,'''func _shop_card_background(item: Dictionary, data: Dictionary) -> String:
	# Shop category "special" also contains ordinary tools; it is not exclusivity.
	for source in [item, data]:
		for flag in ["special", "limited", "unique", "exclusive", "is_special", "is_limited", "is_unique", "once_per_account"]:
			if source.get(flag, false) == true:
				return "shop_card_special"
		if str(source.get("rarity", "")).to_lower() in ["special", "limited", "unique"]:
			return "shop_card_special"
	return "shop_card_legendary" if str(data.get("rarity", item.get("rarity", "common"))).to_lower() == "legendary" else "shop_card_normal"


func _apply_shop_card_background(card: Button, region: String) -> void:
	card.set_meta("shop_card_background", region)
	var backdrop := card.get_node_or_null("IconSlot") as TextureRect
	if backdrop != null:
		backdrop.texture = UIAtlasDB.get_texture(region)
		backdrop.modulate = Color.WHITE


'''+mark)
s=s.replace('card.tooltip_text = get_shop_item_description(item)','card.tooltip_text = get_shop_item_description(item)\n\t_apply_shop_card_background(card, _shop_card_background(item, world.item_database.get(item_id, {}) if world != null else {}))')
s=s.replace('card.tooltip_text = edition','card.tooltip_text = edition\n\t_apply_shop_card_background(card, _shop_card_background(pack_data, {}))')
p.write_text(s,encoding='utf-8')
p=Path('Scripts/ui/shop_scene_redesign.gd');s=p.read_text(encoding='utf-8').replace('detail_icon_slot.texture = UIAtlasDB.get_texture("inv_slot_normal")','detail_icon_slot.texture = UIAtlasDB.get_texture(str(card.get_meta("shop_card_background", "shop_card_normal")))');p.write_text(s,encoding='utf-8')
