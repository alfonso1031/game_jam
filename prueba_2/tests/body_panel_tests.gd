extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	Inventory.reset_run()
	var scene: PackedScene = load("res://ui/body_panel.tscn")
	_check(scene != null, "la escena de cuerpo existe")
	if scene == null:
		_finish()
		return

	var panel: Control = scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	Inventory.pick_up("serrated_jaw")
	await get_tree().process_frame

	var points: PackedVector2Array = panel.connection_curve(0)
	_check(points.size() >= 8, "la curva tiene muestras suaves")
	if not points.is_empty():
		_check(panel.slime_rect().has_point(points[0]), "nace dentro del slime")
		_check(panel.slot_rect(0).has_point(points[-1]), "termina dentro de la tarjeta")
	_check(panel.get_node("Slots/Slot1").visible, "la tarjeta equipada aparece")

	Inventory.consume_slot(0)
	await get_tree().process_frame
	_check(panel.connection_curve(0).is_empty(), "el slot libre elimina la conexión")
	_check(not panel.get_node("Slots/Slot1").visible, "el slot libre elimina la tarjeta")

	GameState.gain_ability("dash")
	await get_tree().process_frame
	_check(panel.ability_connection_curve().size() >= 8, "la habilidad también se conecta")

	panel.queue_free()
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
		print("PASS: organic body panel")
		get_tree().quit(0)
		return
	get_tree().quit(1)
