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
	var test_mode: Button = panel.get_node_or_null("TestMode") as Button
	_check(test_mode != null, "TAB expone el modo de prueba")
	_check(
		panel.has_method("toggle_infinite_health"),
		"el panel expone el interruptor de vida infinita"
	)
	if test_mode != null and panel.has_method("toggle_infinite_health"):
		test_mode.pressed.emit()
		_check(GameState.infinite_health, "clic activa vida infinita")
		_check(test_mode.text.ends_with("SÍ"), "el texto refleja el modo activo")
		test_mode.pressed.emit()
		_check(not GameState.infinite_health, "un segundo clic lo apaga")
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

	_check(panel.has_method("select_first_equipped"), "expone selección inicial")
	_check(panel.has_method("move_selection"), "expone navegación espacial")
	_check(panel.has_method("consume_selected"), "expone consumo de la selección")
	if (
		panel.has_method("select_first_equipped")
		and panel.has_method("move_selection")
		and panel.has_method("consume_selected")
	):
		await _test_selection_and_consumption(panel)

	panel.queue_free()
	await get_tree().process_frame
	await _test_tooltip_teardown(scene)
	_finish()


func _test_selection_and_consumption(panel: Control) -> void:
	Inventory.reset_run()
	Inventory.slots[0] = "serrated_jaw"
	Inventory.slots[2] = "scaled_skin"
	Inventory.slots_changed.emit()
	await get_tree().process_frame

	panel.call("select_first_equipped")
	_check(panel.get("selected_slot") == 0, "selecciona la primera parte equipada")
	_check(
		panel.get_node("Slots/Slot1").scale.x > 1.0,
		"la tarjeta seleccionada se amplía"
	)
	var selected_curve: PackedVector2Array = panel.call("selected_connection_curve")
	_check(not selected_curve.is_empty(), "la selección expone su conexión resaltada")

	panel.call("move_selection", Vector2.RIGHT)
	_check(panel.get("selected_slot") == 2, "derecha omite huecos vacíos")
	panel.call("move_selection", Vector2.RIGHT)
	_check(panel.get("selected_slot") == 2, "sin candidato conserva la selección")

	GameState.health_halves = GameState.max_health_halves
	_check(not panel.call("consume_selected"), "con vida máxima no consume")
	_check(Inventory.part_at(2) == "scaled_skin", "con vida máxima conserva la parte")

	GameState.health_halves -= 3
	GameState.health_changed.emit(GameState.health_halves)
	var health_before: int = GameState.health_halves
	_check(
		panel.get_node("ConsumeHint").text == "F · COMER",
		"Tab no anuncia cuánto curará"
	)
	_check(panel.call("consume_selected"), "consume la parte seleccionada")
	_check(Inventory.is_empty(2), "consumir libera el slot seleccionado")
	_check(GameState.health_halves == health_before + 2, "consumir cura 2 HP")
	_check(panel.get("selected_slot") == 0, "mueve la selección a la parte restante")

	GameState.health_halves = GameState.max_health_halves - 1
	GameState.health_changed.emit(GameState.health_halves)
	_check(panel.call("consume_selected"), "puede consumir la última parte")
	_check(
		GameState.health_halves == GameState.max_health_halves,
		"curación nunca supera 15 HP"
	)
	_check(panel.get("selected_slot") == -1, "sin partes limpia la selección")


func _test_tooltip_teardown(scene: PackedScene) -> void:
	Inventory.reset_run()
	Inventory.pick_up("serrated_jaw")
	var panel: Control = scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.call("select_first_equipped")
	remove_child(panel)
	panel.call("_hide_slot_tooltip", 0)
	_check(
		not panel.get_node("PartTooltip").visible,
		"al salir del árbol no reabre el tooltip seleccionado"
	)
	panel.free()
	Inventory.reset_run()


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
