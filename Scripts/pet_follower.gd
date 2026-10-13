extends CharacterBody2D

const Atlas = preload("res://Scripts/atlas_texture_factory.gd")
var target: Node2D
var item: Dictionary = {}
var sprite := Sprite2D.new()
var age := 0.0
var punch_until := 0.0
var facing := 1.0
var smoke_clock := 0.0
var frames: Array[Texture2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 12)
	shape.shape = box
	shape.position.y = 9
	add_child(shape)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	for frame in range(8 if int(item.get("pet_row",0)) < 4 else (4 if int(item.get("pet_row",0)) == 4 else 5)):
		frames.append(Atlas.load_texture({"atlas":"res://Assets/items/pets.png", "cell":[frame,int(item.get("pet_row",0))], "cell_size":[32,32]}))
	global_position = target.global_position + Vector2(-36, 5)

func punch() -> void:
	punch_until = age + 0.25

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	age += delta
	var flying := bool(item.get("pet_flying", false))
	var direction: float = signf(float(target.velocity.x)) if target is CharacterBody2D else facing
	if direction != 0:
		facing = direction
	var goal := target.global_position + Vector2(-facing * 38, -20 if flying else 7)
	if global_position.distance_to(goal) > 240:
		global_position = goal
	var dx := goal.x - global_position.x
	velocity.x = clampf(dx * 5, -180, 180) if absf(dx) > 8 else 0.0
	if flying:
		global_position = global_position.lerp(goal + Vector2(0, sin(age * 5) * 3), minf(1, delta * 6))
	else:
		velocity.y = minf(velocity.y + 1000 * delta, 520)
		if is_on_floor() and (is_on_wall() or goal.y < global_position.y - 24):
			velocity.y = -360
		move_and_slide()
	sprite.flip_h = facing < 0
	var frame := int(age * 5) % 3
	if flying:
		frame = int(age * 12) % (4 if int(item.get("pet_row", 0)) == 5 else 3)
	elif not is_on_floor():
		frame = 5 if velocity.y < 0 else 6
	elif absf(velocity.x) > 8:
		frame = 3 + int(age * 10) % 4
	if age < punch_until:
		frame = (4 if int(item.get("pet_row", 0)) == 5 else 3) if flying else 7
		if flying:
			sprite.position = Vector2(sin(age * 70) * 3, cos(age * 70) * 2)
			if int(item.get("pet_row", 0)) == 5:
				smoke_clock -= delta
				if smoke_clock <= 0:
					smoke_clock = 0.06
					var smoke := Polygon2D.new()
					smoke.polygon = PackedVector2Array([Vector2(-2,-2), Vector2(2,-2), Vector2(2,2), Vector2(-2,2)])
					get_parent().add_child(smoke)
					smoke.global_position = global_position + Vector2(0, -10)
					smoke.color = Color(0.65,0.7,0.75,0.8)
					var tween := smoke.create_tween().set_parallel()
					tween.tween_property(smoke, "position:y", smoke.position.y - 12, 0.3)
					tween.tween_property(smoke, "modulate:a", 0, 0.3)
					tween.chain().tween_callback(smoke.queue_free)
	else:
		sprite.position = Vector2.ZERO
	sprite.texture = frames[frame]
