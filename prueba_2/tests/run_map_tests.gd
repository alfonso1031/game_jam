extends SceneTree

const RunMap := preload("res://core/run_map.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := RunMap.new(42, 0)
	map.add_room("R0", Vector2i.ZERO, &"entry", &"tutorial")
	map.add_room("R1", Vector2i.RIGHT, &"normal", &"easy")
	map.connect_rooms("R0", "R1", &"E")
	map.set_grate("R1", "RG")
	map.add_room("RG", Vector2i(1, 1), &"grate_destination", &"loot")

	_check(map.seed == 42, "conserva la seed")
	_check(map.room_ids() == ["R0", "R1", "RG"], "ordena ids de forma estable")
	_check(map.room("R0")["doors"]["E"] == "R1", "conecta la ida")
	_check(map.room("R1")["doors"]["O"] == "R0", "conecta la vuelta")
	_check(map.room("R1")["grate_target"] == "RG", "registra la rejilla")
	_check(map.canonical_snapshot()["rooms"].size() == 3, "expone snapshot serializable")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: run map model")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
