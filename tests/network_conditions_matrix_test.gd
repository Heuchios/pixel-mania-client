extends SceneTree

const BufferScript = preload("res://Scripts/networking/websocket_snapshot_buffer.gd")
var failures := 0

func _initialize():
	var rows: Array = []
	for rtt in [0, 50, 100, 150, 250]:
		for loss_percent in [0, 1, 3, 5]:
			for fps in [30, 60, 144]:
				rows.append(simulate(rtt, loss_percent, fps))
	var file := FileAccess.open("user://network-matrix.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	print("NETWORK_MATRIX rows=%d failures=%d output=%s" % [rows.size(), failures, ProjectSettings.globalize_path("user://network-matrix.json")])
	quit(1 if failures else 0)

func simulate(rtt: int, loss_percent: int, fps: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2982026
	var packets: Array[Dictionary] = []
	var due := 0.0
	for i in range(401):
		var sent := 1000 + i * 50
		# This tests missing snapshots, not kernel TCP packet loss. Real TCP
		# recovery is additionally modeled as a 300ms ordered delivery stall.
		if rng.randf() * 100 < loss_percent:
			continue
		var arrival := float(sent) + rtt / 2.0 + rng.randf_range(0, 40)
		if i == 140:
			arrival += 300
		due = maxf(due, arrival)
		packets.append({"sent": sent, "due": due, "seq": i + 1, "x": i * 7.5})
	var buffer = BufferScript.new()
	var index := 0
	var previous := 0.0
	var max_step := 0.0
	var squared_error := 0.0
	var frames := 0
	var backwards := 0
	var now := 1000.0
	while now < 21000:
		while index < packets.size() and float(packets[index].due) <= now:
			var packet := packets[index]
			buffer.push_snapshot(int(packet.sent), int(packet.due), int(packet.seq), Vector2(float(packet.x), 0), Vector2(150, 0))
			index += 1
		var sample: Dictionary = buffer.sample(int(now))
		if not sample.is_empty():
			var x: float = sample.position.x
			var step := x - previous
			if now > 2500 and (now < 7800 or now > 9000):
				max_step = maxf(max_step, absf(step))
				squared_error += pow(step - 150.0 / fps, 2)
				frames += 1
				if step < -0.01:
					backwards += 1
			previous = x
		now += 1000.0 / fps
	if max_step > 22 or backwards > 0 or buffer.snapshots.size() > 24:
		failures += 1
	return {"rtt_ms": rtt, "snapshot_loss_percent": loss_percent, "fps": fps, "max_step_px": max_step,
		"step_error_rms_px": sqrt(squared_error / maxi(1, frames)), "backwards": backwards, "buffer_size": buffer.snapshots.size()}
