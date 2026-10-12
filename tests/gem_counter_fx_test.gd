extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Load after autoloads exist, as the HUD depends on MobileUIScale.
	var manager = load("res://Scripts/inventory_manager.gd").new()
	assert(manager != null)
	manager.free()
	var fx = preload("res://Scripts/ui/gem_counter_fx.gd").new()
	root.add_child(fx)
	fx.set_process(false)
	var label := Label.new()
	root.add_child(label)
	fx.label = label
	fx.set_amount(7365)
	assert(label.text == "7,365", "Initial balance must not roll from zero")
	fx.set_amount(7465)
	fx._process(0.1)
	assert(fx.displayed > 7365 and fx.displayed < 7465)
	var previous: float = fx.displayed
	fx.set_amount(8000)
	assert(fx.displayed == previous, "Rapid pickups cannot restart at old balance")
	fx._process(0.1)
	assert(fx.displayed > previous)
	fx._process(2.0)
	assert(label.text == "8,000")
	fx.set_amount(7900)
	assert(label.text == "7,900", "Spending must be reflected immediately")
	fx.pickup()
	assert(fx.burst_age == 0.0 and fx.shine_clock == 0.0)
	fx._process(2.0)
	assert(fx.burst_age == 1.0)
	fx.hide()
	fx.set_amount(9000)
	assert(label.text == "9,000", "Hidden HUD must not queue stale rolls")
	fx.free()
	label.free()
	print("GEM_COUNTER_FX: PASS")
	quit()
