extends SceneTree

const ChargeMotion = preload("res://scripts/charge_motion.gd")
const REQUIRED_AUDIO_METHODS := [
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
	var audio_component_ready := await _test_audio_component()
	if audio_component_ready:
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


func _test_audio_component() -> bool:
	var audio_script := load("res://scripts/slime_audio.gd") as Script
	var audio_script_loads := audio_script != null and audio_script.can_instantiate()
	_assert_true(audio_script_loads, "SlimeAudio script loads")
	if not audio_script_loads:
		return false

	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_assert_true(player_scene != null, "player scene with audio loads")
	if player_scene == null:
		return false

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "player contains SlimeAudio")
	if audio == null or not _has_required_audio_contract(audio):
		player.free()
		return false
	var charge_loop := audio.get_node_or_null("ChargeLoop") as AudioStreamPlayer2D
	_assert_true(charge_loop != null, "SlimeAudio contains ChargeLoop")

	audio.begin_charge()
	_assert_true(audio.is_charge_playing(), "charge loop starts")
	_assert_close(audio.get_charge_pitch(), 0.85, "new charge starts at minimum pitch")
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-20.0,
			"new charge starts at minimum volume"
		)
	var effect_a := audio.get_node_or_null("EffectA") as AudioStreamPlayer2D
	var effect_b := audio.get_node_or_null("EffectB") as AudioStreamPlayer2D
	_assert_true(effect_a != null, "full charge uses EffectA")
	_assert_true(effect_b != null, "full charge preserves EffectB")
	audio.update_charge(1.0)
	_assert_equal(audio.last_event, &"charge_full", "full charge fires from power update")
	_assert_close(audio.get_charge_pitch(), 1.18, "full charge reaches maximum pitch")
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-8.0,
			"full charge reaches maximum volume"
		)
	if effect_a != null and effect_b != null:
		_assert_true(effect_a.playing, "full charge plays the first effect")
		audio.update_charge(1.0)
		_assert_true(
			not effect_b.playing,
			"second full power update does not replay the full charge cue"
		)
	audio.stop_charge()
	_assert_true(not audio.is_charge_playing(), "charge loop stops")
	audio.begin_charge()
	_assert_close(audio.get_charge_pitch(), 0.85, "restarted charge resets minimum pitch")
	if charge_loop != null:
		_assert_close(
			charge_loop.volume_db,
			-20.0,
			"restarted charge resets minimum volume"
		)
	audio.stop_charge()
	player.begin_charge(Vector2.RIGHT)
	player.update_charge(Vector2.RIGHT, 0.5)
	_assert_equal(audio.last_event, &"charge", "charging updates audio")
	player.release_charge()
	_assert_equal(audio.last_event, &"launch", "release plays launch")
	_assert_equal(
		player.current_state,
		player.MovementState.LAUNCHING,
		"release keeps controller in launching state"
	)
	_assert_true(
		not audio.is_charge_playing(),
		"prototype launch stops the charge loop"
	)
	player._advance_launch(1.0)
	_assert_equal(
		player.current_state,
		player.MovementState.RECOVERING,
		"clean launch completion enters recovery"
	)
	_assert_equal(audio.last_event, &"recover", "clean launch completion plays recover")
	_assert_true(
		not audio.is_charge_playing(),
		"prototype clean completion leaves the charge loop stopped"
	)
	player.free()
	return true


func _has_required_audio_contract(audio: Node) -> bool:
	var has_contract := true
	for method in REQUIRED_AUDIO_METHODS:
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
	var player: CharacterBody2D = main_instance.get_node("Player")
	player.set_physics_process(false)
	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "main scene player contains SlimeAudio")
	player.position = Vector2(1650.0, 540.0)
	player.begin_charge(Vector2.RIGHT)
	player.update_charge(Vector2.RIGHT, ChargeMotion.MAX_CHARGE_TIME)
	player.release_charge()
	if audio != null:
		_assert_true(
			not audio.is_charge_playing(),
			"prototype collision launch stops the charge loop"
		)
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
	_assert_equal(
		player.current_state,
		player.MovementState.RECOVERING,
		"wall collision enters recovery"
	)
	if audio != null:
		_assert_equal(audio.last_event, &"impact", "wall collision plays impact")
		_assert_true(
			not audio.is_charge_playing(),
			"prototype collision completion leaves the charge loop stopped"
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
