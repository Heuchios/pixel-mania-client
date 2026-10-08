extends SceneTree
const LANDING = preload("res://Scripts/fishing_landing_fx.gd")
var failures := 0
class ObserverWorld extends "res://tests/fixtures/fishing_test_world.gd":
	var celebrations: Array[String] = []
	func spawn_fishing_reward_confetti_particles(_position: Vector2, rarity: String): celebrations.append(rarity)
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _init(): call_deferred("run")
func effects(world: Node) -> Array:
	return world.get_children().filter(func(n): return n.get_script() == LANDING and not n.is_queued_for_deletion())
func run():
	var packet := {"player_id":"angler", "world":"FISHING_TEST", "fishing_active":true, "fishing_target_x":2, "fishing_target_y":1, "fishing_session_id":"cast-1"}
	var reward := {"player_id":"angler", "world":"FISHING_TEST", "session_id":"cast-1", "item_id":"guppy", "item_category":"fish", "rarity":"common", "target_x":2, "target_y":1}
	for late_join in [false, true]:
		var world := ObserverWorld.new()
		root.add_child(world)
		var fishing = load("res://Scripts/fishing_manager.gd").new()
		world.add_child(fishing)
		fishing.world = world
		world.fishing_manager = fishing
		var manager = load("res://Scripts/player_manager.gd").new()
		world.add_child(manager)
		manager.world = world
		var remote := Node2D.new()
		world.add_child(remote)
		manager.remote_players["angler"] = remote
		remote.set_meta("remote_id", "angler")
		if not late_join:
			manager.apply_remote_fishing_presence(remote, packet)
			manager.update_remote_fishing_visual(remote, 0.0)
			var bait = remote.get_meta("remote_fishing_bobber").get_node("Sprite2D").texture
			check(bait != null, "Observer sees bait before hook")
		var hooked := packet.merged({"fishing_hooked_item_id":"guppy", "fishing_hooked_item_category":"fish"}, true)
		manager.apply_remote_fishing_presence(remote, hooked)
		manager.update_remote_fishing_visual(remote, 0.0)
		var bobber = remote.get_meta("remote_fishing_bobber")
		var sprite: Sprite2D = bobber.get_node("Sprite2D")
		check(sprite.texture is AtlasTexture and sprite.texture.atlas == world.fish_textures.guppy, "Observer sees the actual hooked fish, including late joins")
		var same_texture = sprite.texture
		manager.update_remote_fishing_visual(remote, 0.1)
		check(sprite.texture == same_texture, "Repeated snapshots don't rebuild/restart the hook")
		manager.play_remote_fishing_landing(reward.merged({"world":"OTHER"},true))
		check(effects(world).is_empty(), "Other worlds are ignored")
		manager.play_remote_fishing_landing(reward)
		check(effects(world).size() == 1, "Common catch has one landing animation")
		var fx = effects(world)[0]
		check(fx.global_position == Vector2(64,32), "Fish rises from actual water tile")
		check(fx.artwork.atlas == world.fish_textures.guppy, "Landing shows server confirmed fish")
		check(not remote.has_meta("remote_fishing_bobber"), "Old bait/fish is removed during landing")
		manager.play_remote_fishing_landing(reward)
		check(effects(world).size() == 1, "Repeated reward doesn't replay the effect")
		manager.apply_remote_fishing_presence(remote, hooked)
		manager.update_remote_fishing_visual(remote, 0.0)
		check(not remote.has_meta("remote_fishing_bobber"), "Late pre-catch presence cannot resurrect bobber")
		fx.set_process(false)
		fx._process(0.35)
		check(fx.sprite.position.y < -20, "Observer sees fish lift above water")
		fx._process(0.7)
		check(world.celebrations.is_empty(), "Common fish has no rare confetti")
		var next_cast := packet.merged({"fishing_session_id":"cast-2"},true)
		manager.apply_remote_fishing_presence(remote,next_cast)
		manager.update_remote_fishing_visual(remote,0.0)
		check(not remote.get_meta("remote_fishing_bobber").has_meta("hooked_item_id"), "New cast resets to bait")
		manager.play_remote_fishing_landing(reward)
		check(effects(world).is_empty(), "Old rewards cannot interrupt newer casts")
		manager.play_remote_fishing_landing(reward.merged({"session_id":"cast-2","rarity":"legendary"},true))
		var rare_fx = effects(world)[0]
		rare_fx.set_process(false)
		rare_fx._process(1.0)
		check(world.celebrations == ["legendary"], "Observers see rare celebration after landing")
		manager.apply_remote_fishing_presence(remote,packet.merged({"fishing_session_id":"cast-3"},true))
		manager.play_remote_fishing_landing(reward.merged({"session_id":"cast-3","rarity":"epic"},true))
		var cancelled_fx = effects(world)[0]
		world.current_world_name = "OTHER"
		cancelled_fx._process(0.1)
		check(cancelled_fx.is_queued_for_deletion(), "Leaving world removes pending fishing effects")
		check(world.celebrations == ["legendary"], "Leaving world does not play celebration")
		world.free()
	var transport = load("res://tests/fixtures/player_emotes_network_probe.gd").new()
	root.add_child(transport)
	transport.world_entry_active = true
	transport.current_world_name = "FISHING_TEST"
	check(transport.send_fishing_hook("cast-4"), "Hook transition sends while stationary")
	check(transport.sent[0].session_id == "cast-4" and not transport.sent[0].has("item_id"), "Client reports phase only, not reward")
	transport.authenticated = false
	check(not transport.send_fishing_hook("cast-4"), "Unauthenticated hook is blocked")
	transport.free()
	print("REMOTE_FISHING_VISUALS_PASS" if failures == 0 else "REMOTE_FISHING_VISUALS_FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
