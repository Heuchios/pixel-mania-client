extends SceneTree
class World extends Node:
	var saved := []
	func set_sign_text(pos, text): saved.append([pos,text])
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1000,660)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(layer)
	var world := World.new()
	viewport.add_child(world)
	var ui = load("res://Scripts/sign_ui.gd").new()
	layer.add_child(ui)
	ui.setup(world,layer)
	ui.open_sign(Vector2i(3,4),"")
	await capture(viewport,"sign-empty")
	ui.sign_text_edit.text="Welcome to our world!\nVisit the market to trade, or head down to the pond for a little fishing."
	ui.sign_text_edit.text_changed.emit()
	assert(ui.char_count_label.text=="Characters: "+str(ui.sign_text_edit.text.length()))
	await capture(viewport,"sign-updated")
	var text=ui.sign_text_edit.text
	ui.panel.get_node("SaveButton").pressed.emit()
	assert(world.saved.size()==1 and world.saved[0]==[Vector2i(3,4),text])
	assert(not ui.is_sign_open())
	ui.open_sign(Vector2i(3,4),"Saved message")
	ui.sign_text_edit.text="Cancelled edit"
	ui.panel.get_node("CancelButton").pressed.emit()
	assert(world.saved.size()==1 and not ui.is_sign_open())
	ui.open_sign(Vector2i(3,4),text)
	viewport.size=Vector2i(600,400)
	ui.update_panel_position()
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	assert(ui.panel.position+ui.panel.size*ui.panel.scale<=Vector2(600,400))
	await capture(viewport,"sign-compact")
	print("Sign editor: character count, save payload, cancel, and compact fit passed.")
	quit()
func capture(viewport,filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
