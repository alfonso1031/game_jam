extends Node

const RunMap := preload("res://core/run_map.gd")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://ui/grate_cost_overlay.tscn")
	_check(scene != null, "la escena de coste existe")
	if scene == null:
		_finish()
		return

	var overlay: Control = scene.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	_prepare_run()
	var room_host := Node2D.new()
	var player := Node2D.new()
	var fade := ColorRect.new()
	add_child(room_host)
	add_child(player)
	add_child(fade)
	Transition.setup(room_host, player, fade)
	Transition.load_initial("SOURCE")
	Inventory.slots[0] = "serrated_jaw"
	Inventory.slots[2] = "scaled_skin"
	Inventory.slots_changed.emit()

	overlay.open("SOURCE", "TARGET")
	_check(overlay.is_in_group("grate_cost_ui"), "se registra en el grupo de coste")
	_check(get_tree().paused, "abrir pausa la partida")
	_check(overlay.get("options").size() == 3, "muestra solo partes equipadas y medio corazon")
	_check(overlay.get("selected_option") == 0, "abre seleccionando la primera parte")
	_check(overlay.get_node("Options").get_child(0).scale == Vector2(1.08, 1.08), "la tarjeta seleccionada escala 1.08")
	var selected_style := overlay.get_node("Options").get_child(0).get_theme_stylebox("panel") as StyleBoxFlat
	_check(selected_style.border_color.r > selected_style.border_color.g, "la tarjeta seleccionada usa borde calido")

	overlay.call("_unhandled_input", _action_event(&"move_right"))
	_check(overlay.get("selected_option") == 1, "derecha cambia la opcion seleccionada")
	overlay.call("_unhandled_input", _action_event(&"move_left"))
	_check(overlay.get("selected_option") == 0, "izquierda cambia la opcion seleccionada")

	var health_before: int = GameState.health_halves
	var slots_before := Inventory.slots.duplicate()
	overlay.cancel()
	_check(not overlay.visible, "cancelar cierra el selector")
	_check(GameState.health_halves == health_before, "cancelar no muta la vida")
	_check(Inventory.slots == slots_before, "cancelar no muta las partes")
	_check(not get_tree().paused, "cancelar reanuda la partida")

	overlay.open("SOURCE", "TARGET")
	overlay.confirm_selection()
	await get_tree().create_timer(0.6, true, false, true).timeout
	_check(Inventory.is_empty(0), "elegir una parte sacrifica su slot")
	_check(GameState.is_grate_unlocked("SOURCE"), "pagar desbloquea la rejilla de origen")
	_check(GameState.current_room == "TARGET", "pagar una parte viaja por la rejilla")

	get_tree().paused = false
	Inventory.reset_run()
	GameState.reset_run()
	RunManager.active = true
	GameState.current_room = "SOURCE"
	GameState.health_halves = 1
	overlay.open("SOURCE", "TARGET")
	_check(overlay.get("selected_option") == 0, "sin partes selecciona el coste de vida")
	overlay.confirm_selection()
	_check(overlay.get_node("Warning").text.contains("CONFIRMA"), "un coste letal exige segunda confirmacion")
	_check(GameState.health_halves == 1, "la primera confirmacion letal no cobra vida")
	_check(overlay.visible, "la confirmacion letal mantiene el selector abierto")
	overlay.confirm_selection()
	await get_tree().process_frame
	_check(GameState.health_halves == 0, "la segunda confirmacion permite la muerte")
	_check(GameState.current_room == "SOURCE", "la muerte por coste no viaja por la rejilla")
	_check(not overlay.visible, "la muerte cierra el selector")

	overlay.queue_free()
	room_host.queue_free()
	player.queue_free()
	fade.queue_free()
	await get_tree().process_frame
	await _test_main_death_keeps_summary_paused()
	await _test_main_hp_payment_via_grate()
	_finish()


func _prepare_run() -> void:
	get_tree().paused = false
	GameState.reset_run()
	Inventory.reset_run()
	RunManager.parts_sacrificed.clear()
	RunManager.active = true
	var map := RunMap.new(9, 0)
	map.add_room("SOURCE", Vector2i.ZERO, &"normal", &"easy")
	map.add_room("TARGET", Vector2i.RIGHT, &"grate_destination", &"loot")
	map.set_grate("SOURCE", "TARGET")
	RunManager.current_map = map
	GameState.current_room = "SOURCE"


func _test_main_death_keeps_summary_paused() -> void:
	var main := await _mount_main(1)
	var overlay: Control = await _open_grate(main)
	_check(overlay.visible, "interactuar con la rejilla abre el selector integrado")
	overlay.confirm_selection()
	overlay.confirm_selection()
	await get_tree().process_frame
	var summary: Control = main.get_node("SummaryLayer/RunSummary")
	_check(summary.visible, "morir desde la rejilla muestra el resumen")
	_check(get_tree().paused, "morir desde la rejilla deja el arbol pausado")
	_check(not overlay.visible, "morir desde la rejilla oculta el selector")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func _test_main_hp_payment_via_grate() -> void:
	var main := await _mount_main(2)
	var overlay: Control = await _open_grate(main)
	overlay.confirm_selection()
	await get_tree().create_timer(0.6, true, false, true).timeout
	_check(GameState.health_halves == 1, "la rejilla cobra medio corazon no letal")
	_check(GameState.is_grate_unlocked("SOURCE"), "el pago de vida desbloquea el origen")
	_check(GameState.current_room == "TARGET", "el pago de vida viaja al destino")
	_check(not get_tree().paused, "el pago no letal reanuda la partida")
	main.queue_free()
	await get_tree().process_frame


func _mount_main(health_halves: int) -> Node2D:
	get_tree().paused = false
	GameState.reset_run()
	Inventory.reset_run()
	RunManager.parts_sacrificed.clear()
	RunManager.active = true
	RunManager.current_map = _grate_map()
	GameState.health_halves = health_halves
	var scene: PackedScene = load("res://game/main.tscn")
	var main := scene.instantiate() as Node2D
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return main


func _open_grate(main: Node2D) -> Control:
	var grate := main.get_node("RoomHost").get_child(0).get_node("Grate") as Area2D
	grate.body_entered.emit(main.get_node("Player"))
	get_viewport().push_input(_action_event(&"interact"))
	await get_tree().process_frame
	return main.get_node("GrateLayer/GrateCostOverlay") as Control


func _grate_map() -> RefCounted:
	var map := RunMap.new(9, 0)
	map.add_room("SOURCE", Vector2i.ZERO, &"normal", &"easy")
	map.add_room("TARGET", Vector2i.RIGHT, &"grate_destination", &"loot")
	map.set_grate("SOURCE", "TARGET")
	map.entry_room_id = "SOURCE"
	return map


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	get_tree().paused = false
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: grate cost ui")
		get_tree().quit(0)
		return
	get_tree().quit(1)
