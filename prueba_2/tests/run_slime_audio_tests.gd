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
	var audio_script := load("res://scripts/player/slime_audio.gd") as Script
	var audio_script_loads: bool = audio_script != null and audio_script.can_instantiate()
	_assert_true(audio_script_loads, "SlimeAudio script loads")
	if not audio_script_loads:
		_finish()
		return

	var scene := load("res://scenes/player/slime.tscn") as PackedScene
	_assert_true(scene != null, "active slime scene loads")
	if scene == null:
		_finish()
		return

	var player := scene.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "active slime contains SlimeAudio")
	if audio == null or not _has_required_audio_contract(audio):
		player.free()
		_finish()
		return

	player._begin_charge(Vector2.RIGHT)
	player._update_charge(1.0)
	_assert_equal(audio.last_event, &"charge_full", "full charge is audible")
	player._release_charge()
	_assert_equal(audio.last_event, &"launch", "launch is audible")

	var fizzle_player := scene.instantiate()
	root.add_child(fizzle_player)
	await process_frame
	fizzle_player.set_physics_process(false)
	var fizzle_audio := fizzle_player.get_node_or_null("SlimeAudio")
	_assert_true(fizzle_audio != null, "second active slime contains SlimeAudio")
	if fizzle_audio != null and _has_required_audio_contract(fizzle_audio):
		fizzle_player._begin_charge(Vector2.RIGHT)
		fizzle_player._release_charge()
		_assert_equal(fizzle_audio.last_event, &"fizzle", "short charge fizzles")
	fizzle_player.queue_free()
	await process_frame

	player._start_dash()
	_assert_equal(audio.last_event, &"dash", "dash has distinct audio")

	player.queue_free()
	await process_frame
	_finish()


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


func _finish() -> void:
	if failures == 0:
		print("PASS: active slime audio tests")
		quit(0)
	else:
		print("FAIL: %d active slime audio test(s)" % failures)
		quit(failures)


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("%s: expected true" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, received %s" % [label, expected, actual])
