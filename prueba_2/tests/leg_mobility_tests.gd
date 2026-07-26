extends Node

const PartsDB := preload("res://core/parts_db.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
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
	Inventory.reset_run()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: leg mobility" if failures.is_empty() else "FAIL: leg mobility")
	get_tree().quit(0 if failures.is_empty() else 1)
