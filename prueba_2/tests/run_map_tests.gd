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

	var normal_counts := {"easy": 0, "hard": 0, "empty": 0, "closure": 0}
	var grate_destinations := {"empty": 0, "combat": 0, "loot": 0}
	var eligible_combats := 0
	var grates := 0
	var unknown_normal_content := false
	var unknown_grate_content := false

	for seed_value in range(1000):
		var generated: RefCounted = generator.generate(seed_value)
		_check(generated != null, "seed %d genera" % seed_value)
		if generated == null:
			continue
		var validation_errors: PackedStringArray = generator.validate(generated)
		_check(validation_errors.is_empty(), "seed %d valida: %s" % [
			seed_value,
			", ".join(validation_errors),
		])
		var seen_grate_targets: Dictionary = {}
		var map_eligible_combats := 0
		var map_grates := 0
		for room_id in generated.room_ids():
			var data: Dictionary = generated.room(room_id)
			var role: StringName = data["role"]
			var content: String = String(data["content_type"])
			if role == &"normal":
				if normal_counts.has(content):
					normal_counts[content] = int(normal_counts[content]) + 1
				else:
					unknown_normal_content = true
			if (
				role != &"grate_destination"
				and (content == "easy" or content == "hard" or content == "combat")
			):
				eligible_combats += 1
				map_eligible_combats += 1
			var grate_target: String = data["grate_target"]
			if grate_target != "":
				grates += 1
				map_grates += 1
				_check(not seen_grate_targets.has(grate_target), "destino único")
				seen_grate_targets[grate_target] = true
				var target_data: Dictionary = generated.room(grate_target)
				var target_content: String = String(target_data["content_type"])
				if grate_destinations.has(target_content):
					grate_destinations[target_content] = int(
						grate_destinations[target_content]
					) + 1
				else:
					unknown_grate_content = true
			if content == "closure":
				var closure_doors: Dictionary = data["doors"]
				var keep_direction: String = data["closure_keep_direction"]
				_check(closure_doors.size() == 3, "cierre tiene tres salidas")
				_check(closure_doors.has(keep_direction), "cierre conserva salida válida")
		if map_eligible_combats > 0:
			_check(map_grates > 0, "seed %d garantiza rejilla" % seed_value)
		_check(generated.rooms.size() <= 12, "seed %d mantiene máximo" % seed_value)

	_check(not unknown_normal_content, "todo contenido normal está reconocido")
	_check(not unknown_grate_content, "todo destino de rejilla está reconocido")
	_check(_near_ratio(int(normal_counts["easy"]), normal_counts, 0.40), "fácil cerca de 40%")
	_check(_near_ratio(int(normal_counts["hard"]), normal_counts, 0.30), "difícil cerca de 30%")
	_check(_near_ratio(int(normal_counts["empty"]), normal_counts, 0.20), "vacía cerca de 20%")
	_check(_near_ratio(int(normal_counts["closure"]), normal_counts, 0.10), "cierre cerca de 10%")
	_check(
		eligible_combats > 0
		and absf(float(grates) / float(eligible_combats) - 0.60) <= 0.05,
		"rejilla cerca de 60%"
	)
	_check(
		_near_ratio(int(grate_destinations["empty"]), grate_destinations, 0.40),
		"destino vacío cerca de 40%"
	)
	_check(
		_near_ratio(int(grate_destinations["combat"]), grate_destinations, 0.20),
		"destino combate cerca de 20%"
	)
	_check(
		_near_ratio(int(grate_destinations["loot"]), grate_destinations, 0.40),
		"destino loot cerca de 40%"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near_ratio(value: int, counts: Dictionary, expected: float) -> bool:
	var total := 0
	for count_value: Variant in counts.values():
		total += int(count_value)
	if total == 0:
		return false
	return absf(float(value) / float(total) - expected) <= 0.05


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: run map model")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
