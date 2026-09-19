extends SceneTree
func _initialize():
	var atlas := Image.load_from_file("res://image.png")
	var direct = {0:Vector2i(24,2),1:Vector2i(24,3),2:Vector2i(21,4),4:Vector2i(23,2),8:Vector2i(24,4),5:Vector2i(23,3),10:Vector2i(22,4),6:Vector2i(21,2),12:Vector2i(22,2),3:Vector2i(21,3),9:Vector2i(22,3),15:Vector2i(23,4)}
	for mask in range(16):
		var tile := Image.create(32,32,false,Image.FORMAT_RGBA8)
		if direct.has(mask):
			tile.blit_rect(atlas,Rect2i(direct[mask]*32,Vector2i(32,32)),Vector2i.ZERO)
		else:
			for qy in range(2):
				for qx in range(2):
					var vertical = bool(mask & (1 if qy == 0 else 4))
					var horizontal = bool(mask & (8 if qx == 0 else 2))
					var source = Vector2i(23,4) if vertical and horizontal else (Vector2i(23,3) if vertical else (Vector2i(22,4) if horizontal else Vector2i(24,2)))
					var offset = Vector2i(qx*16,qy*16)
					tile.blit_rect(atlas,Rect2i(source*32+offset,Vector2i(16,16)),offset)
		tile.save_png("res://Assets/blocks/cloud_connected/mask_%d.png" % mask)
	quit()
