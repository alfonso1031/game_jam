extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_scene: PackedScene = load("res://ui/floor_route_overlay.tscn")
	_check(route_scene != null, "la escena de ruta existe")
	if route_scene == null:
		_finish()
		return

	var route: Control = route_scene.instantiate()
	add_child(route)
	await get_tree().process_frame
	RunManager.floor_completed.emit(&"contencion", 2)
	await get_tree().process_frame
	_check(route.visible, "aparece al completar Contención")
	_check(
		route.floor_order() == [&"surface", &"maintenance", &"biolabs", &"contencion"],
		"la superficie queda arriba y Contención abajo"
	)
	_check(route.generated_room_count() == 0, "la ruta no dibuja habitaciones")
	_check(is_equal_approx(route.DISPLAY_DURATION, 3.0), "dura tres segundos")
	_check(get_tree().paused, "pausa la partida durante la transición")
	_check(route.get_node("Panel/Status").text.contains("+2 HP"), "muestra la curación obtenida")

	route.dismiss()
	await get_tree().process_frame
	_check(not route.visible, "se puede continuar antes")
	_check(not get_tree().paused, "continuar devuelve el control")
	route.queue_free()
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
		print("PASS: floor route overlay")
		get_tree().quit(0)
		return
	get_tree().paused = false
	get_tree().quit(1)
