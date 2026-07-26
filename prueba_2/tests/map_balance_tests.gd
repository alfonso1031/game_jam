extends SceneTree

const MapGenerator := preload("res://core/map_generator.gd")

const ATTEMPT_COUNT := 2000
const WEIGHTED_SAMPLE_SIZE := 10000
const WEIGHT_TOLERANCE := 0.02

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator := MapGenerator.new()
	_check(
		MapGenerator.NORMAL_CONTENT == [
			[&"easy", 60],
			[&"hard", 30],
			[&"empty", 10],
		],
		"los pesos normales son exactamente 60/30/10"
	)
	_check_weighted_distribution(generator)
	_check_generated_enemy_ranges(generator)
	_check_determinism(generator)
	_finish()


func _check_weighted_distribution(generator: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260726
	var counts := {"easy": 0, "hard": 0, "empty": 0}
	for _sample in range(WEIGHTED_SAMPLE_SIZE):
		var content: StringName = generator.call(
			"_weighted_choice",
			rng,
			MapGenerator.NORMAL_CONTENT
		)
		counts[String(content)] = int(counts[String(content)]) + 1
	_check(
		_near_ratio(int(counts["easy"]), counts, 0.60),
		"la muestra easy de 10000 queda cerca de 60%"
	)
	_check(
		_near_ratio(int(counts["hard"]), counts, 0.30),
		"la muestra hard de 10000 queda cerca de 30%"
	)
	_check(
		_near_ratio(int(counts["empty"]), counts, 0.10),
		"la muestra empty de 10000 queda cerca de 10%"
	)


func _check_generated_enemy_ranges(generator: RefCounted) -> void:
	var easy_counts: Dictionary = {}
	var hard_counts: Dictionary = {}
	var invalid_easy := false
	var invalid_hard := false
	for attempt in range(ATTEMPT_COUNT):
		var generated: RefCounted = generator.generate_attempt(20260726, attempt)
		for room_id: String in generated.room_ids():
			var data: Dictionary = generated.room(room_id)
			var content: StringName = data.get("content_type", &"")
			var enemy_count := int(data.get("enemy_count", 0))
			if content == &"easy":
				if enemy_count < 1 or enemy_count > 3:
					invalid_easy = true
				easy_counts[enemy_count] = true
			elif content == &"hard":
				if enemy_count < 4 or enemy_count > 7:
					invalid_hard = true
				hard_counts[enemy_count] = true
	_check(not invalid_easy, "2000 intentos mantienen easy entre 1 y 3 enemigos")
	_check(not invalid_hard, "2000 intentos mantienen hard entre 4 y 7 enemigos")
	for enemy_count in range(1, 4):
		_check(easy_counts.has(enemy_count), "easy puede generar %d enemigos" % enemy_count)
	for enemy_count in range(4, 8):
		_check(hard_counts.has(enemy_count), "hard puede generar %d enemigos" % enemy_count)


func _check_determinism(generator: RefCounted) -> void:
	var first: RefCounted = generator.generate_attempt(481516, 97)
	var second: RefCounted = generator.generate_attempt(481516, 97)
	_check(
		first.canonical_snapshot() == second.canonical_snapshot(),
		"la misma seed e intento conservan contenido y cantidades"
	)


func _near_ratio(value: int, counts: Dictionary, expected: float) -> bool:
	var total := 0
	for count_value: Variant in counts.values():
		total += int(count_value)
	if total == 0:
		return false
	return absf(float(value) / float(total) - expected) <= WEIGHT_TOLERANCE


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: map balance")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
