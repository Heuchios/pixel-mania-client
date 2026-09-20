extends TextureProgressBar
func _ready() -> void:
	preload("res://Scripts/ui/pixel_ui_style.gd").apply_progress_bar(self)
