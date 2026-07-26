extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var title: Control = load("res://ui/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	_check(title.has_node("BackgroundContained"), "la portada incluye la ilustracion contenida")
	_check(title.has_node("BackgroundEscaped"), "la portada incluye la ilustracion escapada")
	_check(title.has_node("Menu/PlayButton"), "la portada ofrece el boton de jugar")
	_check(title.has_node("Menu/QuitButton"), "la portada ofrece el boton de salir")
	_check(title.has_method("skip_intro"), "la portada permite omitir la introduccion")
	_check(title.has_method("intro_finished"), "la portada expone el estado de introduccion")

	if title.has_method("skip_intro"):
		title.skip_intro()
		await get_tree().process_frame
		_check(title.intro_finished(), "omitir termina la introduccion")
		var menu := title.get_node_or_null("Menu") as Control
		var escaped := title.get_node_or_null("BackgroundEscaped") as TextureRect
		_check(menu != null and menu.visible, "omitir muestra el menu")
		_check(escaped != null and is_equal_approx(escaped.modulate.a, 1.0), "omitir deja visible la ilustracion escapada")

	title.queue_free()
	await get_tree().process_frame
	var title_from_input: Control = load("res://ui/title.tscn").instantiate()
	add_child(title_from_input)
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_A
	title_from_input._unhandled_input(key)
	_check(title_from_input.intro_finished(), "la primera tecla solo omite la introduccion")
	title_from_input.queue_free()
	await get_tree().process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: title intro")
		get_tree().quit(0)
		return
	get_tree().quit(1)
