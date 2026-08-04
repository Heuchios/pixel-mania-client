extends SceneTree

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const GlobalFontManagerScript = preload("res://Scripts/ui/global_font_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var body_label := Label.new()
	body_label.name = "StatusLabel"
	body_label.add_theme_font_size_override("font_size", 14)
	PixelUIStyle.apply_global_typography_to_node(body_label)
	assert(body_label.get_theme_font_size("font_size") == 24)

	var subtitle_label := Label.new()
	subtitle_label.name = "SubtitleLabel"
	PixelUIStyle.apply_global_typography_to_node(subtitle_label)
	assert(subtitle_label.get_theme_font_size("font_size") == 24)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.add_theme_font_size_override("font_size", 14)
	PixelUIStyle.apply_global_typography_to_node(title_label)
	assert(title_label.get_theme_font_size("font_size") == 36)

	var authored_header := Label.new()
	authored_header.name = "WorldName"
	authored_header.add_theme_font_size_override("font_size", 44)
	PixelUIStyle.apply_global_typography_to_node(authored_header)
	assert(authored_header.get_theme_font_size("font_size") == 36)

	var settings_label := Label.new()
	settings_label.name = "InfoLabel"
	settings_label.label_settings = LabelSettings.new()
	settings_label.label_settings.font_size = 13
	PixelUIStyle.apply_global_typography_to_node(settings_label)
	assert(settings_label.get_theme_font_size("font_size") == 24)
	assert(settings_label.label_settings.font_size == 24)

	var rich_text := RichTextLabel.new()
	rich_text.name = "Description"
	PixelUIStyle.apply_global_typography_to_node(rich_text)
	assert(rich_text.get_theme_font_size("normal_font_size") == 24)
	assert(rich_text.get_theme_font_size("bold_font_size") == 24)

	var custom_label := Label.new()
	custom_label.name = "CompactCounter"
	custom_label.set_meta(PixelUIStyle.GLOBAL_FONT_SIZE_META, 18)
	PixelUIStyle.apply_global_typography_to_node(custom_label)
	assert(custom_label.get_theme_font_size("font_size") == 18)

	var manager := GlobalFontManagerScript.new()
	var runtime_panel := Control.new()
	var runtime_body := Label.new()
	var runtime_title := Label.new()
	runtime_body.name = "RuntimeBody"
	runtime_title.name = "RuntimeTitle"
	runtime_panel.add_child(runtime_body)
	runtime_panel.add_child(runtime_title)
	manager.apply_to_node_tree(runtime_panel)
	assert(runtime_body.get_theme_font_size("font_size") == 24)
	assert(runtime_title.get_theme_font_size("font_size") == 36)

	body_label.free()
	subtitle_label.free()
	title_label.free()
	authored_header.free()
	settings_label.free()
	rich_text.free()
	custom_label.free()
	runtime_panel.free()
	manager.free()
	print("[global-typography] success")
	quit(0)
