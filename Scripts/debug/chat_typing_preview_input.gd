extends "res://Scripts/chat_ui.gd"
## Small offline harness using the real chat input activity/focus logic.
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _input(_event: InputEvent) -> void: pass
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		release_chat_focus()

func finish_preview_message(_text: String) -> void:
	get_active_chat_input().clear()
	release_chat_focus()
