extends Node

const PartsDB := preload("res://core/parts_db.gd")
const SlimeScene := preload("res://actors/player/slime.tscn")
const FRAME_TIME := 1.0 / 60.0

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_inventory_count()
	await _check_slime_mobility()
	Inventory.reset_run()
	_finish()


func _check_inventory_count() -> void:
	Inventory.reset_run()
	_check(
		Inventory.has_method("equipped_count_for_slot"),
		"Inventory expone el conteo por tipo corporal"
	)
	if Inventory.has_method("equipped_count_for_slot"):
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 0,
			"sin piernas el conteo es cero"
		)
		Inventory.slots[0] = "hydraulic_legs"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 1,
			"una parte de pierna cuenta una vez"
		)
		Inventory.slots[1] = "whip_tail"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 2,
			"dos partes de pierna quedan disponibles para reglas futuras"
		)
		Inventory.slots[2] = "serrated_jaw"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 2,
			"una parte de cabeza no altera el conteo de piernas"
		)


func _check_slime_mobility() -> void:
	Inventory.reset_run()
	var player: CharacterBody2D = SlimeScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)

	_check(player.has_method("leg_count"), "el slime expone cuántas piernas tiene")
	_check(
		player.has_method("uses_continuous_movement"),
		"el slime expone el modo de movimiento actual"
	)
	_check(
		player.has_method("_advance_continuous"),
		"el slime implementa el desplazamiento continuo"
	)
	if not (
		player.has_method("leg_count")
		and player.has_method("uses_continuous_movement")
		and player.has_method("_advance_continuous")
	):
		player.queue_free()
		await get_tree().process_frame
		return

	_check(
		not player.call("uses_continuous_movement"),
		"sin piernas conserva el movimiento cargado"
	)
	player.call("_begin_charge", Vector2.RIGHT)
	_check(
		player.get("_state") == player.State.CHARGING,
		"sin piernas mantener dirección inicia la carga"
	)

	Inventory.slots[0] = "hydraulic_legs"
	Inventory.slots_changed.emit()
	_check(player.call("leg_count") == 1, "una pierna llega al controlador")
	_check(player.call("uses_continuous_movement"), "una pierna activa movimiento continuo")
	_check(
		player.get("_state") == player.State.IDLE,
		"equipar una pierna cancela la carga incompleta"
	)

	var before := player.position
	Input.action_press("move_right")
	player.call("_advance_continuous", FRAME_TIME)
	Input.action_release("move_right")
	_check(
		is_equal_approx(player.position.x - before.x, 280.0 * FRAME_TIME),
		"el movimiento continuo avanza a 280 px/s"
	)
	_check(player.aim_direction() == Vector2.RIGHT, "caminar actualiza el apuntado")
	_check(
		player.get("_state") == player.State.IDLE,
		"caminar con pierna no inicia carga ni muestra su barra"
	)

	player.apply_status(PartsDB.STATUS_ROOT, 1.0)
	before = player.position
	Input.action_press("move_right")
	player.call("_advance_continuous", FRAME_TIME)
	Input.action_release("move_right")
	_check(player.position == before, "root bloquea el movimiento continuo")
	player.set("_status", {})

	Inventory.clear_slot(0)
	_check(
		not player.call("uses_continuous_movement"),
		"perder la última pierna restaura la carga"
	)

	player.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: leg mobility" if failures.is_empty() else "FAIL: leg mobility")
	get_tree().quit(0 if failures.is_empty() else 1)
