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
	_check(GameState.health_halves == 5, "inicia con 5 HP")
	_check(Inventory.equipped_ids().is_empty(), "inicia sin partes")

	GameState.damage_halves(2)
	_check(RunManager.complete_floor(&"contencion"), "completa una vez")
	_check(GameState.health_halves == 5, "el piso cura 2 HP")
	_check(not RunManager.complete_floor(&"contencion"), "no repite recompensa")

	Inventory.pick_up("serrated_jaw")
	GameState.health_halves = 3
	_check(Inventory.consume_slot(0), "come parte equipada")
	_check(GameState.health_halves == 4, "comer cura 1 HP")
	_check(Inventory.is_empty(0), "comer libera slot")
	_check(RunManager.parts_consumed == ["serrated_jaw"], "registra la parte comida")

	Inventory.pick_up("serrated_jaw")
	_check(Inventory.lose_slot(0) == "serrated_jaw", "perder devuelve id")
	_check(GameState.health_halves == 4, "perder no cura")
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
