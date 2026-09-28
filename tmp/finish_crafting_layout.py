from pathlib import Path
p=Path('Scripts/crafting_ui.gd');s=p.read_text(encoding='utf-8');s=s.replace('PixelUIStyle.apply_tab_button(all_filter, true, 18)','PixelUIStyle.apply_atlas_button(all_filter, "green_button")');s=s.replace('PixelUIStyle.apply_tab_button(ready_filter, ready_filter.button_pressed, 18)','PixelUIStyle.apply_atlas_button(ready_filter, "green_button" if ready_filter.button_pressed else "pink_button")');s=s.replace('PixelUIStyle.apply_tab_button(all_filter, not ready_filter.button_pressed, 18)','PixelUIStyle.apply_atlas_button(all_filter, "pink_button" if ready_filter.button_pressed else "green_button")');p.write_text(s,encoding='utf-8')
p=Path('tests/crafting_navigation_test.gd');s=p.read_text(encoding='utf-8');s=s.replace('root.size = Vector2i(1280, 800)','''var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 840)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)''').replace('root.add_child(ui)','viewport.add_child(ui)').replace('root.get_texture()','viewport.get_texture()').replace('D:/Pixelmania/crafting-redesign.png','D:/Pixelmania/crafting-updated.png');s=s.replace('\tworld.free()', '''	viewport.size = Vector2i(800, 600)
	craft.update_panel_position()
	assert(craft.panel.position.x >= 0 and craft.panel.position.y >= 0)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/crafting-compact.png")
	world.free()''');Path('tmp/crafting_layout_preview.gd').write_text(s,encoding='utf-8')
