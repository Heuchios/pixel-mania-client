extends SceneTree
func _init():
	call_deferred("run")
func run():
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	var book = load("res://Scenes/ui/recipe_book/RecipeBookScene.tscn").instantiate()
	root.add_child(book)
	book.open()
	for i in range(12):
		print(i, " size=", book.window.size, " scale=", book.window.scale, " alpha=", book.window.modulate.a)
		await process_frame
	book.queue_free()
	quit()
