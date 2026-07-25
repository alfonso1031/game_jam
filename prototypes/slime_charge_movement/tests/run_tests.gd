extends SceneTree

const ChargeMotion = preload("res://scripts/charge_motion.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_assert_close(
		ChargeMotion.normalized_power(0.5, 1.0),
		0.5,
		"half charge"
	)
	_assert_close(
		ChargeMotion.MAX_CHARGE_TIME,
		1.0,
		"dash definition exposes maximum charge time"
	)
	_assert_close(
		ChargeMotion.MINIMUM_DISTANCE,
		112.0,
		"dash definition exposes minimum distance"
	)
	_assert_close(
		ChargeMotion.MAXIMUM_DISTANCE,
		520.0,
		"dash definition exposes maximum distance"
	)
	_assert_close(
		ChargeMotion.LAUNCH_SPEED,
		1040.0,
		"dash definition exposes launch speed"
	)
	_assert_close(
		ChargeMotion.RECOVERY_TIME,
		0.12,
		"dash definition exposes recovery time"
	)
	_assert_close(
		ChargeMotion.normalized_power(2.0, 1.0),
		1.0,
		"charge clamps at one"
	)
	_assert_close(
		ChargeMotion.normalized_power(0.4, 0.0),
		1.0,
		"zero maximum charge is safe"
	)
	_assert_close(
		ChargeMotion.launch_distance(0.0, 112.0, 520.0),
		112.0,
		"minimum launch distance"
	)
	_assert_close(
		ChargeMotion.launch_distance(0.5, 112.0, 520.0),
		316.0,
		"half-charge launch distance"
	)
	_assert_close(
		ChargeMotion.launch_distance(1.0, 112.0, 520.0),
		520.0,
		"maximum launch distance"
	)
	_assert_close(
		ChargeMotion.safe_direction(Vector2(1.0, 1.0)).length(),
		1.0,
		"diagonal direction is normalized"
	)
	_assert_equal(
		ChargeMotion.safe_direction(Vector2.ZERO),
		Vector2.ZERO,
		"zero direction stays zero"
	)
	_test_player_state_machine()
	_test_feedback_nodes()
	await _test_main_scene()

	if failures == 0:
		print("PASS: all slime movement tests")
	else:
		print("FAIL: %d slime movement test(s)" % failures)
	quit(failures)


func _test_player_state_machine() -> void:
	var player_script := load("res://scripts/player.gd")
	_assert_true(player_script != null, "player controller loads")
	if player_script == null:
		return

	var player = player_script.new()
	player.begin_charge(Vector2.RIGHT)
	_assert_equal(
		player.current_state,
		player.MovementState.CHARGING,
		"begin charge enters charging state"
	)
	player.update_charge(Vector2(1.0, 1.0), 0.5)
	_assert_close(
		player.get_charge_power(),
		0.5,
		"controller reports half charge"
	)
	_assert_close(
		player.charge_direction.length(),
		1.0,
		"controller normalizes changed direction"
	)
	player.release_charge()
	_assert_equal(
		player.current_state,
		player.MovementState.LAUNCHING,
		"release enters launching state"
	)
	_assert_close(
		player.remaining_distance,
		316.0,
		"half charge stores expected launch distance"
	)
	player.free()


func _test_feedback_nodes() -> void:
	var bar_script := load("res://scripts/charge_bar.gd")
	_assert_true(bar_script != null, "charge bar script loads")
	if bar_script != null:
		var bar = bar_script.new()
		bar.set_charge(1.5, true)
		_assert_close(bar.charge_power, 1.0, "charge bar clamps power")
		_assert_true(bar.visible, "charge bar shows while charging")
		bar.set_charge(0.0, false)
		_assert_true(not bar.visible, "charge bar hides outside charging")
		bar.free()

	var visual_script := load("res://scripts/slime_visual.gd")
	_assert_true(visual_script != null, "slime visual script loads")
	if visual_script != null:
		_assert_equal(
			visual_script.feedback_scale(1, 0.5, Vector2.DOWN),
			Vector2(1.06, 0.91),
			"vertical charge compresses the vertical axis"
		)
		_assert_equal(
			visual_script.feedback_scale(2, 1.0, Vector2.RIGHT),
			Vector2(1.28, 0.78),
			"horizontal launch stretches the horizontal axis"
		)
		var visual = visual_script.new()
		visual.set_movement_feedback(1, Vector2.RIGHT, 0.5)
		_assert_close(
			visual.rotation,
			0.0,
			"directional deformation keeps the face upright"
		)
		visual.free()


func _test_main_scene() -> void:
	var main_scene := load("res://scenes/main.tscn")
	_assert_true(main_scene != null, "main scene loads")
	if main_scene == null:
		return

	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)
	await physics_frame
	_assert_true(
		main_instance.get_node_or_null("Player") != null,
		"main scene contains the isolated player"
	)
	_assert_true(
		main_instance.get_node_or_null("Arena") != null,
		"main scene contains the collision arena"
	)
	var player := main_instance.get_node("Player") as SlimePlayer
	player.set_physics_process(false)
	player.position = Vector2(1650.0, 540.0)
	player.begin_charge(Vector2.RIGHT)
	player.update_charge(Vector2.RIGHT, ChargeMotion.MAX_CHARGE_TIME)
	player.release_charge()
	var launch_steps := 0
	while (
		player.current_state == player.MovementState.LAUNCHING
		and launch_steps < 60
	):
		player._physics_process(1.0 / 60.0)
		launch_steps += 1
	_assert_true(
		player.current_state != player.MovementState.LAUNCHING,
		"wall collision ends the launch"
	)
	_assert_true(
		player.position.x <= 1748.5,
		"player collision radius remains inside the right wall"
	)
	main_instance.free()


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
