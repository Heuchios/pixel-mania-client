extends SceneTree

var failures := 0
var checks := 0

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run():
	var ui = load("res://Scenes/ui/trade/TradeScene.tscn").instantiate()
	root.add_child(ui)
	var local_id = ui.get_local_player_id()
	var state := {"type":"trade_state", "trade_id":"review-test", "status":"final_pending", "requester_player_id":local_id, "target_player_id":"peer", "requester_username":"You", "target_username":"Peer", "offers":{}, "accepted":{}, "final_accepted":{}, "final_confirm_available_at":12345}
	ui.handle_trade_message(state)
	check(ui.final_overlay.visible, "Final review must be visible")
	check(ui.final_confirm_button.disabled, "Final accept starts disabled")
	check(ui.final_confirm_button.text == "Review (5s)", "Final window displays five seconds")
	var button = ui.final_confirm_button
	var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	check(text_width <= button.size.x - 12, "Countdown text fits the final button")
	var original_deadline = ui.final_review_until_msec
	ui.handle_trade_message(state)
	check(ui.final_review_until_msec == original_deadline, "Duplicate final states cannot restart the countdown")
	for remaining in [5000, 4001, 3000, 1, 0]:
		ui.final_review_until_msec = Time.get_ticks_msec() + remaining
		ui.update_final_accept_button()
		check(ui.final_confirm_button.disabled == (remaining > 0), "Accept unlocks only at zero")
	ui.handle_trade_message(state.merged({"final_accepted":{local_id:true}}, true))
	check(ui.final_confirm_button.disabled and ui.final_confirm_button.text == "Accepted", "Acceptance stays disabled after confirmation")
	ui.handle_trade_message(state.merged({"status":"active"}, true))
	check(not ui.final_overlay.visible and ui.final_review_until_msec == 0, "Returning to editing resets review state")
	ui.handle_trade_message(state.merged({"final_confirm_available_at":67890}, true))
	check(ui.get_final_review_seconds() == 5 and ui.final_confirm_button.disabled, "A new final offer requires a complete new review")
	ui.close_trade_ui()
	check(ui.final_review_until_msec == 0 and ui.final_review_key == "", "Cancel clears the review state")
	ui.free()
	print("TRADE_REVIEW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
