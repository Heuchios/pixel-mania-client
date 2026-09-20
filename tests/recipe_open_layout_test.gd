extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var failures := 0
	var manager := root.get_node("MobileUIScale")
	for screen in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = screen
		root.content_scale_size = screen
		for ui_scale in [1.0, 1.25]:
			manager.ui_scale = ui_scale
			manager.set_process(true)
			var book = load("res://Scenes/ui/recipe_book/RecipeBookScene.tscn").instantiate()
			root.add_child(book)
			var entries: Array = []
			for i in range(80):
				entries.append({"id": "recipe_%d" % i, "name": "Recipe %d" % i, "category": "blocks", "method": "splicing"})
			book.set_all_recipes({1: entries})
			for opening in range(2):
				book.open()
				var first_size := Vector2.ZERO
				var first_scale := Vector2.ZERO
				for frame in range(25):
					await process_frame
					if book.window.modulate.a > 0.0:
						if first_size == Vector2.ZERO:
							first_size = book.window.size
							first_scale = book.window.scale
						if not book.window.size.is_equal_approx(first_size) or not book.window.scale.is_equal_approx(first_scale):
							push_error("Visible recipe book resized after opening")
							failures += 1
				if first_size == Vector2.ZERO:
					failures += 1
				if screen.x == 1920 and ui_scale == 1.0 and not first_scale.is_equal_approx(Vector2.ONE):
					push_error("Desktop book must open at full size")
					failures += 1
				book.close()
			book.open()
			book.close()
			for frame in range(5):
				await process_frame
			if book.visible:
				failures += 1
			book.queue_free()
			await process_frame
	manager.ui_scale = 1.0
	manager.set_process(manager.is_mobile())
	print("RECIPE_OPEN_LAYOUT: %d failures" % failures)
	quit(1 if failures else 0)
