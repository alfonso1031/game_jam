extends Node2D

const SlimeScene := preload("res://actors/player/slime.tscn")
const MainScene := preload("res://game/main.tscn")
const FIRST_PARTS: Array[String] = [
	"acid_stinger",
	"serrated_jaw",
	"hydraulic_legs",
	"bio_netcaster",
]

var failures: Array[String] = []


func _ready() -> void:
	add_to_group("room")
	var slime: CharacterBody2D = SlimeScene.instantiate()
	add_child(slime)
	call_deferred("_run")


func _run() -> void:
	for part_id: String in FIRST_PARTS:
		Inventory.reset_run()
		_check(Inventory.pick_up(part_id), "%s entra al slot 1" % part_id)
		_check(Inventory.can_activate(0), "%s se puede activar" % part_id)

		var press := InputEventKey.new()
		press.physical_keycode = KEY_1
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().physics_frame
		_check(
			Inventory.cooldown_left(0) > 0.0,
			"la tecla física 1 activa %s" % part_id
		)

		var release := InputEventKey.new()
		release.physical_keycode = KEY_1
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		await get_tree().process_frame

	Inventory.reset_run()
	_check(Inventory.pick_up("serrated_jaw"), "la prueba de teclado numérico equipa la parte")
	var keypad_press := InputEventKey.new()
	keypad_press.physical_keycode = KEY_KP_1
	keypad_press.pressed = true
	Input.parse_input_event(keypad_press)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(
		Inventory.cooldown_left(0) > 0.0,
		"la tecla 1 del teclado numérico también activa el slot 1"
	)

	await _check_active_game()

	for failure in failures:
		push_error(failure)
	print("PASS: ability number input" if failures.is_empty() else "FAIL: ability number input")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _check_active_game() -> void:
	for child in get_children():
		child.queue_free()
	remove_from_group("room")
	await get_tree().process_frame
	get_tree().paused = false
	RunManager.start_new_run(1785033756)
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	for frame in range(8):
		await get_tree().process_frame

	_check(not get_tree().paused, "la partida real no bloquea el input")
	Inventory.reset_run()
	_check(Inventory.pick_up("serrated_jaw"), "la partida real equipa la parte")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_1
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(
		Inventory.cooldown_left(0) > 0.0,
		"la tecla 1 activa la parte dentro de main.tscn"
	)
