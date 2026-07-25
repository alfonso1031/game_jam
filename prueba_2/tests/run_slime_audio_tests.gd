extends SceneTree

const REQUIRED_AUDIO_METHODS: Array[StringName] = [
	&"begin_charge",
	&"update_charge",
	&"charge_full",
	&"fizzle",
	&"launch",
	&"dash",
	&"impact",
	&"recover",
	&"stop_charge",
	&"is_charge_playing",
	&"get_charge_pitch",
]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var temporary_trees: Array[Node] = []
	var audio_script := load("res://actors/player/slime_audio.gd") as Script
	var audio_script_loads: bool = audio_script != null and audio_script.can_instantiate()
	_assert_true(audio_script_loads, "SlimeAudio script loads")
	if not audio_script_loads:
		await _complete_run(temporary_trees)
		audio_script = null
		call_deferred("_finish")
		return

	var scene := load("res://actors/player/slime.tscn") as PackedScene
	_assert_true(scene != null, "active slime scene loads")
	if scene == null:
		await _complete_run(temporary_trees)
		audio_script = null
		call_deferred("_finish")
		return

	await _test_clean_completion_and_charge_reset(scene, temporary_trees)
	await _test_fizzle_stops_charge(scene, temporary_trees)
	await _test_dash_stops_charge(scene, temporary_trees)
	await _test_charging_knockback_stops_charge(scene, temporary_trees)
	await _test_collision_completion(scene, temporary_trees)
	await _complete_run(temporary_trees)
	scene = null
	audio_script = null
	call_deferred("_finish")


func _test_clean_completion_and_charge_reset(
	scene: PackedScene,
	temporary_trees: Array[Node]
) -> void:
	var player := await _spawn_player(scene, temporary_trees)
	var audio := _get_audio(player, "clean-completion slime")
	if audio == null:
		return
	var charge_loop := audio.get_node_or_null("ChargeLoop") as AudioStreamPlayer2D
	_assert_true(charge_loop != null, "active SlimeAudio contains ChargeLoop")

	audio.begin_charge()
	_assert_true(audio.is_charge_playing(), "active charge loop starts")
	_assert_close(audio.get_charge_pitch(), 0.85, "active charge starts at minimum pitch")
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-20.0,
			"active charge starts at minimum volume"
		)
	audio.update_charge(1.0)
	_assert_close(audio.get_charge_pitch(), 1.18, "active full charge reaches maximum pitch")
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-8.0,
			"active full charge reaches maximum volume"
		)
	audio.stop_charge()
	audio.begin_charge()
	_assert_close(
		audio.get_charge_pitch(),
		0.85,
		"active restarted charge resets minimum pitch"
	)
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-20.0,
			"active restarted charge resets minimum volume"
		)
	audio.stop_charge()

	player._begin_charge(Vector2.RIGHT)
	player._update_charge(1.0)
	_assert_equal(audio.last_event, &"charge_full", "active full charge is audible")
	player._release_charge()
	_assert_equal(player._state, player.State.LAUNCHING, "active release enters launch")
	_assert_equal(audio.last_event, &"launch", "active launch is audible")
	_assert_true(not audio.is_charge_playing(), "active launch stops the charge loop")
	_advance_launch_until_recovery(player)
	_assert_equal(
		player._state,
		player.State.RECOVERING,
		"active clean completion enters recovery"
	)
	_assert_equal(audio.last_event, &"recover", "active clean completion plays recover")
	_assert_true(
		not audio.is_charge_playing(),
		"active clean completion leaves the charge loop stopped"
	)


func _test_fizzle_stops_charge(
	scene: PackedScene,
	temporary_trees: Array[Node]
) -> void:
	var player := await _spawn_player(scene, temporary_trees)
	var audio := _get_audio(player, "fizzle slime")
	if audio == null:
		return

	player._begin_charge(Vector2.RIGHT)
	_assert_true(audio.is_charge_playing(), "fizzle setup starts the charge loop")
	player._release_charge()
	_assert_equal(player._state, player.State.RECOVERING, "fizzle enters recovery")
	_assert_equal(audio.last_event, &"fizzle", "short charge fizzles")
	_assert_true(not audio.is_charge_playing(), "fizzle stops the charge loop")


func _test_dash_stops_charge(
	scene: PackedScene,
	temporary_trees: Array[Node]
) -> void:
	var player := await _spawn_player(scene, temporary_trees)
	var audio := _get_audio(player, "dash slime")
	if audio == null:
		return

	player._begin_charge(Vector2.RIGHT)
	_assert_true(audio.is_charge_playing(), "dash setup starts the charge loop")
	player._start_dash()
	_assert_equal(player._state, player.State.DASHING, "DASH enters dashing state")
	_assert_equal(audio.last_event, &"dash", "DASH has distinct audio")
	_assert_true(not audio.is_charge_playing(), "DASH stops the charge loop")


func _test_charging_knockback_stops_charge(
	scene: PackedScene,
	temporary_trees: Array[Node]
) -> void:
	var player := await _spawn_player(scene, temporary_trees)
	var audio := _get_audio(player, "knockback slime")
	if audio == null:
		return

	player.position = Vector2(700.0, 0.0)
	player._begin_charge(Vector2.RIGHT)
	_assert_true(audio.is_charge_playing(), "knockback setup starts the charge loop")
	player.apply_knockback(player.global_position - Vector2.RIGHT, 620.0)
	_assert_equal(
		player._state,
		player.State.RECOVERING,
		"charging knockback enters recovery"
	)
	_assert_equal(
		audio.last_event,
		&"stop_charge",
		"charging knockback records charge interruption"
	)
	_assert_true(
		not audio.is_charge_playing(),
		"charging knockback stops the charge loop"
	)


func _test_collision_completion(
	scene: PackedScene,
	temporary_trees: Array[Node]
) -> void:
	var player := await _spawn_player(scene, temporary_trees)
	var audio := _get_audio(player, "collision slime")
	if audio == null:
		return
	player.position = Vector2.ZERO

	var wall := StaticBody2D.new()
	wall.position = Vector2(140.0, 0.0)
	wall.collision_layer = 1
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20.0, 400.0)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	root.add_child(wall)
	temporary_trees.append(wall)
	await physics_frame

	player._begin_charge(Vector2.RIGHT)
	player._update_charge(1.0)
	player._release_charge()
	_assert_equal(player._state, player.State.LAUNCHING, "collision setup enters launch")
	_assert_equal(audio.last_event, &"launch", "collision setup plays launch")
	_assert_true(
		not audio.is_charge_playing(),
		"active collision launch stops the charge loop"
	)
	_advance_launch_until_recovery(player)
	_assert_equal(
		player._state,
		player.State.RECOVERING,
		"active collision completion enters recovery"
	)
	_assert_equal(audio.last_event, &"impact", "active collision completion plays impact")
	_assert_true(
		not audio.is_charge_playing(),
		"active collision completion leaves the charge loop stopped"
	)


func _spawn_player(scene: PackedScene, temporary_trees: Array[Node]) -> Node:
	var player := scene.instantiate()
	root.add_child(player)
	temporary_trees.append(player)
	await process_frame
	player.set_physics_process(false)
	return player


func _advance_launch_until_recovery(player: Node) -> void:
	var launch_frames := 0
	while player._state == player.State.LAUNCHING and launch_frames < 240:
		player._advance_launch(1.0 / 60.0)
		launch_frames += 1


func _get_audio(player: Node, label: String) -> Node:
	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "%s contains SlimeAudio" % label)
	if audio == null or not _has_required_audio_contract(audio):
		return null
	return audio


func _has_required_audio_contract(audio: Node) -> bool:
	var has_contract := true
	for method: StringName in REQUIRED_AUDIO_METHODS:
		if not audio.has_method(method):
			has_contract = false
			_assert_true(false, "SlimeAudio exposes %s" % method)
	if not _has_property(audio, &"last_event"):
		has_contract = false
		_assert_true(false, "SlimeAudio exposes last_event")
	return has_contract


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.name == property_name:
			return true
	return false


func _complete_run(temporary_trees: Array[Node]) -> void:
	await _teardown_temporary_trees(temporary_trees)
	await process_frame


func _teardown_temporary_trees(temporary_trees: Array[Node]) -> void:
	for temporary_tree: Node in temporary_trees:
		if not is_instance_valid(temporary_tree):
			continue
		for descendant: Node in temporary_tree.find_children(
			"*",
			"AudioStreamPlayer2D",
			true,
			false
		):
			var audio_player := descendant as AudioStreamPlayer2D
			audio_player.stop()
		temporary_tree.queue_free()

	var cleanup_frames := 0
	while _has_valid_temporary_tree(temporary_trees) and cleanup_frames < 6:
		await process_frame
		cleanup_frames += 1
	_assert_true(
		not _has_valid_temporary_tree(temporary_trees),
		"all temporary player and collision trees are freed"
	)
	for _cleanup_frame in range(8):
		await process_frame
	await create_timer(0.2).timeout
	await process_frame


func _has_valid_temporary_tree(temporary_trees: Array[Node]) -> bool:
	for temporary_tree: Node in temporary_trees:
		if is_instance_valid(temporary_tree):
			return true
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: active slime audio tests")
		quit(0)
	else:
		print("FAIL: %d active slime audio test(s)" % failures)
		quit(failures)


func _assert_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures += 1
		push_error("%s: expected %s, received %s" % [label, expected, actual])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("%s: expected true" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, received %s" % [label, expected, actual])
