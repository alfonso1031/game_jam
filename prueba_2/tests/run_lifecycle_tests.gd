extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RunManager.start_new_run(777)
	_check(RunManager.current_seed == 777, "conserva seed explícita")
	_check(RunManager.current_map != null, "crea mapa")
	_check(GameState.max_health_halves == 15, "máximo son 15 HP")
	_check(GameState.health_halves == 7, "inicia con 7 HP")
	_check(Inventory.equipped_ids().is_empty(), "inicia sin partes")
	GameState.unlock_grate("R1")
	_check(GameState.is_grate_unlocked("R1"), "desbloquea la rejilla de origen")
	RunManager.start_new_run(777)
	_check(not GameState.is_grate_unlocked("R1"), "la nueva run limpia rejillas desbloqueadas")

	GameState.damage_halves(2)
	_check(RunManager.complete_floor(&"contencion"), "completa una vez")
	_check(GameState.health_halves == 7, "el piso cura 2 HP")
	_check(not RunManager.complete_floor(&"contencion"), "no repite recompensa")

	Inventory.pick_up("serrated_jaw")
	GameState.health_halves = 3
	_check(Inventory.consume_slot(0), "come parte equipada")
	_check(GameState.health_halves == 5, "comer cura 2 HP")
	_check(Inventory.is_empty(0), "comer libera slot")
	_check(RunManager.parts_consumed == ["serrated_jaw"], "registra la parte comida")

	Inventory.pick_up("serrated_jaw")
	_check(Inventory.lose_slot(0) == "serrated_jaw", "perder devuelve id")
	_check(GameState.health_halves == 5, "perder no cura")
	_check(Inventory.is_empty(0), "perder libera slot")

	Inventory.pick_up("serrated_jaw")
	_check(RunManager.pay_grate_cost(0, false) == &"part", "rejilla sacrifica parte")
	_check(Inventory.is_empty(0), "sacrificio libera slot")
	_check(
		RunManager.parts_sacrificed == ["serrated_jaw"],
		"registra la parte sacrificada"
	)

	GameState.health_halves = 2
	_check(RunManager.pay_grate_cost(-1, false) == &"hp", "sin parte elegida cuesta HP")
	_check(GameState.health_halves == 1, "cobra exactamente 1 HP")
	_check(
		RunManager.pay_grate_cost(-1, false) == &"confirmation_required",
		"1 HP pide confirmar"
	)
	_check(GameState.health_halves == 1, "pedir confirmación no muta la vida")
	_check(RunManager.pay_grate_cost(-1, true) == &"death", "confirmar permite morir")

	RunManager.start_new_run(777)
	GameState.visited["C_00"] = true
	RunManager.parts_consumed.append("serrated_jaw")
	RunManager.parts_sacrificed.append("scaled_skin")
	var summary: Dictionary = RunManager.end_run(&"death")
	_check(summary["zone"] == "CONTENCIÓN", "resume zona")
	_check(summary["rooms_visited"] == 1, "cuenta salas")
	_check(summary["consumed"] == ["serrated_jaw"], "lista comidas")
	_check(summary["sacrificed"] == ["scaled_skin"], "lista sacrificadas")
	_check(summary["seed"] == 777, "muestra seed")
	_check(not RunManager.active, "terminar desactiva la partida")

	RunManager.start_new_run(777)
	var room_host := Node2D.new()
	var player := Node2D.new()
	var fade := ColorRect.new()
	add_child(room_host)
	add_child(player)
	add_child(fade)
	Transition.setup(room_host, player, fade)
	Transition.load_initial(RunManager.current_map.entry_room_id)
	_check(
		GameState.current_room == RunManager.current_map.entry_room_id,
		"carga entrada procedural"
	)
	var first_data: Dictionary = RunManager.current_map.room(GameState.current_room)
	var first_directions: Array = first_data["doors"].keys()
	var first_direction: String = first_directions[0]
	var first_target: String = first_data["doors"][first_direction]
	await Transition.go_to(first_target, first_direction)
	_check(GameState.current_room == first_target, "cruza a descriptor generado")
	_check(
		room_host.get_child(0).get_meta("room_id") == first_target,
		"ensambla el destino de RunMap"
	)
	var has_respawn := false
	for method: Dictionary in Transition.get_method_list():
		if method["name"] == "respawn":
			has_respawn = true
	_check(not has_respawn, "Transition ya no ofrece respawn")
	room_host.queue_free()
	player.queue_free()
	fade.queue_free()
	await get_tree().process_frame

	var summary_scene: PackedScene = load("res://ui/run_summary.tscn")
	var summary_ui: Control = summary_scene.instantiate()
	add_child(summary_ui)
	RunManager.start_new_run(5150)
	GameState.visited["C_00"] = true
	RunManager.end_run(&"death")
	_check(summary_ui.visible, "el resumen aparece al terminar")
	_check(get_tree().paused, "el resumen pausa la partida")
	_check(
		summary_ui.get_node("Panel/Content/Seed").text == "SEED · 5150",
		"la vista muestra la seed reproducible"
	)
	get_tree().paused = false
	summary_ui.queue_free()
	await get_tree().process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok  %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	print("\n%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: run lifecycle")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)
