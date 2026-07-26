extends SceneTree

const RunMap := preload("res://core/run_map.gd")
const MapGenerator := preload("res://core/map_generator.gd")

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

	var generator := MapGenerator.new()
	var first: RefCounted = generator.generate(90125)
	var second: RefCounted = generator.generate(90125)
	var different: RefCounted = generator.generate(90126)

	_check(first != null, "genera una seed válida")
	_check(
		first.canonical_snapshot() == second.canonical_snapshot(),
		"la misma seed produce el mismo mapa"
	)
	_check(
		first.canonical_snapshot() != different.canonical_snapshot(),
		"otra seed cambia la topología o contenido"
	)
	_check(first.main_path.size() >= 6 and first.main_path.size() <= 8, "camino de 6 a 8")
	_check(first.rooms.size() <= 12, "respeta máximo de 12")
	_check(first.room(first.main_path[0])["role"] == &"entry", "entrada primero")
	_check(first.room(first.main_path[-2])["role"] == &"preboss", "preboss penúltimo")
	_check(first.room(first.main_path[-1])["role"] == &"boss_choice", "boss al final")
	_check(generator.validate(first).is_empty(), "la propuesta aceptada es válida")
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
