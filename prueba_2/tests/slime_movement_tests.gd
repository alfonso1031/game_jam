extends SceneTree

const FRAME_TIME := 1.0 / 60.0
const EXPECTED_STEP := 480.0 / 60.0

var failures := 0
var _temporary_nodes: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://actors/player/slime.tscn") as PackedScene
	_assert_true(scene != null, "la escena activa del slime carga")
	if scene == null:
		_finish()
		return

	var minimum := await _spawn_player(scene)
	minimum.position = Vector2.ZERO
	minimum._begin_charge(Vector2.RIGHT)
	minimum._update_charge(minimum.MIN_CHARGE_TIME)
	minimum._release_charge()
	var minimum_samples := _advance_until_recovery(minimum)
	_assert_close(minimum.position.x, 112.0, 1.0, "la carga mínima recorre 112 px")
	_assert_uniform(minimum_samples, EXPECTED_STEP, 1.0, "la carga mínima avanza uniforme")

	var full := await _spawn_player(scene)
	full.position = Vector2(0, 300)
	full._begin_charge(Vector2.RIGHT)
	full._update_charge(full.MAX_CHARGE_TIME)
	full._release_charge()
	var full_samples := _advance_until_recovery(full)
	_assert_close(full.position.x, 520.0, 1.0, "la carga completa recorre 520 px")
	_assert_uniform(full_samples, EXPECTED_STEP, 1.0, "la carga completa avanza uniforme")
	_assert_true(
		full_samples.size() >= 64 and full_samples.size() <= 66,
		"la carga completa dura cerca de 1.08 s"
	)

	await _cleanup()
	scene = null
	_finish()


func _spawn_player(scene: PackedScene) -> Node:
	var player := scene.instantiate()
	root.add_child(player)
	_temporary_nodes.append(player)
	await process_frame
	player.set_physics_process(false)
	return player


func _advance_until_recovery(player: Node) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	while player._state == player.State.LAUNCHING and samples.size() < 180:
		var before: Vector2 = player.position
		player._advance_launch(FRAME_TIME)
		samples.append(before.distance_to(player.position))
	return samples


func _assert_uniform(
	samples: PackedFloat32Array,
	expected: float,
	tolerance: float,
	label: String
) -> void:
	_assert_true(samples.size() >= 2, "%s produce varias muestras" % label)
	for index in range(maxi(samples.size() - 1, 0)):
		if absf(samples[index] - expected) <= tolerance:
			continue
		failures += 1
		push_error(
			"%s: muestra %d esperaba %.2f y recibió %.2f"
			% [label, index, expected, samples[index]]
		)
		return


func _cleanup() -> void:
	for node in _temporary_nodes:
		if not is_instance_valid(node):
			continue
		for audio_node in node.find_children("*", "AudioStreamPlayer2D", true, false):
			(audio_node as AudioStreamPlayer2D).stop()
		node.queue_free()
	for _frame in range(8):
		await process_frame


func _assert_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		return
	failures += 1
	push_error("%s: esperaba %.2f y recibió %.2f" % [label, expected, actual])


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("%s: esperaba verdadero" % label)


func _finish() -> void:
	if failures == 0:
		print("PASS: slime movement")
		quit(0)
		return
	print("FAIL: %d prueba(s) de movimiento" % failures)
	quit(failures)
