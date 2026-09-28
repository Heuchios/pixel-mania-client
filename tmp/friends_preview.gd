extends SceneTree
const UI = preload("res://Scripts/friends_ui.gd")
class World extends Node:
	var actions := []
	func accept_friend_request_from(name): actions.append(["accept",name])
	func decline_friend_request_from(name): actions.append(["decline",name])
	func enter_world_by_name(name): actions.append(["warp",name])
	func show_notification(_text): pass
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	var ui := UI.new()
	viewport.add_child(ui)
	ui.setup(world)
	ui.visible=true
	ui.overlay.visible=true
	ui.is_panel_open=true
	ui.apply_friend_state({"friends":[{"username":"Lucifer","online":false},{"username":"UCE","online":true,"world":"START"},{"username":"Mauri","online":false},{"username":"Rayan","online":true,"world":"SHOWCASE"},{"username":"AReallyLongPlayerNameHere","online":true,"world":"A_LONG_WORLD_NAME"}],"pending_incoming":[{"username":"NewFriend"}],"pending_outgoing":[{"username":"Explorer"}]})
	await capture(viewport,"friends-updated")
	assert(ui.rows_root.get_child(0).get_node("Name").text == "AReallyLongPlayerNameHere")
	ui.search_input.text="START"
	ui.search_input.text_changed.emit("START")
	assert(ui.rows_root.get_child_count()==1)
	ui.rows_root.get_child(0).get_node("Button_WARP").pressed.emit()
	assert(world.actions == [["warp","START"]])
	ui.visible=true
	ui.overlay.visible=true
	ui.search_input.text=""
	ui._on_pending_tab_pressed()
	await capture(viewport,"friends-requests")
	ui.rows_root.get_child(0).get_node("Button_ACCEPT").pressed.emit()
	ui.rows_root.get_child(0).get_node("Button_DECLINE").pressed.emit()
	assert(world.actions.size()==3)
	assert(ui.rows_root.get_child(1).get_node("Button_PENDING").disabled)
	viewport.size=Vector2i(800,600)
	ui.update_position()
	await capture(viewport,"friends-compact")
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	ui.search_input.text="no_match"
	ui.refresh()
	assert(ui.empty_label.visible)
	ui.close_panel()
	assert(not ui.is_open())
	print("[friends] search, ordering, tabs, warp, request actions, empty state and resize passed")
	quit()
func capture(viewport, filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
