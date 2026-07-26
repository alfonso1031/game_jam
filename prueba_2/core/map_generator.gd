extends RefCounted

const RunMap := preload("res://core/run_map.gd")

const MAX_ATTEMPTS := 128
const MIN_MAIN_PATH := 6
const MAX_MAIN_PATH := 8
const MAX_ROOMS := 12
const RECONNECTION_CHANCE := 0.35
const DIRECTIONS: Array[String] = ["N", "E", "S", "O"]
const DELTAS: Dictionary = {
	"N": Vector2i.UP,
	"E": Vector2i.RIGHT,
	"S": Vector2i.DOWN,
	"O": Vector2i.LEFT,
}


func generate(run_seed: int) -> RefCounted:
	for attempt in range(MAX_ATTEMPTS):
		var candidate: RefCounted = generate_attempt(run_seed, attempt)
		if validate(candidate).is_empty():
			return candidate
	return null


func generate_attempt(run_seed: int, attempt: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mixed_seed(run_seed, attempt)
	var run_map := RunMap.new(run_seed, attempt)
	var target_length: int = rng.randi_range(MIN_MAIN_PATH, MAX_MAIN_PATH)
	var occupied: Dictionary = {}
	var current := Vector2i.ZERO

	for index in range(target_length):
		var room_id := "C_%02d" % index
		var role: StringName = &"normal"
		if index == 0:
			role = &"entry"
		elif index == target_length - 2:
			role = &"preboss"
		elif index == target_length - 1:
			role = &"boss_choice"
		run_map.add_room(room_id, current, role, &"unassigned")
		run_map.main_path.append(room_id)
		occupied[current] = room_id
		if index == target_length - 1:
			break
		var choices: Array[String] = _free_directions(current, occupied, rng)
		if choices.is_empty():
			return run_map
		var direction: String = choices[rng.randi_range(0, choices.size() - 1)]
		current += DELTAS[direction]

	run_map.entry_room_id = run_map.main_path[0]
	run_map.boss_room_id = run_map.main_path[-1]
	for index in range(run_map.main_path.size() - 1):
		var from_id: String = run_map.main_path[index]
		var to_id: String = run_map.main_path[index + 1]
		var from_grid: Vector2i = run_map.room(from_id)["grid"]
		var to_grid: Vector2i = run_map.room(to_id)["grid"]
		run_map.connect_rooms(from_id, to_id, _direction_for(to_grid - from_grid))
	_add_reconnections(run_map, rng)
	return run_map


func validate(run_map: RefCounted) -> PackedStringArray:
	var errors := PackedStringArray()
	if run_map.main_path.size() < MIN_MAIN_PATH or run_map.main_path.size() > MAX_MAIN_PATH:
		errors.append("main_path debe tener 6–8 salas")
	if run_map.rooms.size() > MAX_ROOMS:
		errors.append("el mapa supera 12 salas")
	if run_map.main_path.is_empty():
		errors.append("falta main_path")
		return errors
	if run_map.main_path.size() < 2:
		errors.append("faltan hitos finales")
		return errors
	if run_map.room(run_map.main_path[0])["role"] != &"entry":
		errors.append("la entrada no es el primer hito")
	if run_map.room(run_map.main_path[-2])["role"] != &"preboss":
		errors.append("el preboss no es el penúltimo hito")
	if run_map.room(run_map.main_path[-1])["role"] != &"boss_choice":
		errors.append("el boss no es el último hito")

	var occupied: Dictionary = {}
	for room_id in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var grid: Vector2i = data["grid"]
		if occupied.has(grid):
			errors.append("coordenada repetida: %s" % grid)
		occupied[grid] = room_id
		var doors: Dictionary = data["doors"]
		var one_way: Dictionary = data["one_way"]
		for direction_value: Variant in doors:
			var direction: String = String(direction_value)
			var target_id: String = doors[direction]
			if not run_map.rooms.has(target_id):
				errors.append("%s apunta a %s inexistente" % [room_id, target_id])
				continue
			var target: Dictionary = run_map.room(target_id)
			var target_grid: Vector2i = target["grid"]
			if target_grid - grid != DELTAS[direction]:
				errors.append("%s.%s no coincide con su coordenada" % [room_id, direction])
			if not bool(one_way.get(direction, false)):
				var opposite: String = RunMap.OPPOSITE[direction]
				var target_doors: Dictionary = target["doors"]
				if target_doors.get(opposite, "") != room_id:
					errors.append("%s.%s no tiene retorno" % [room_id, direction])
	return errors


func _mixed_seed(run_seed: int, attempt: int) -> int:
	return int((run_seed * 1103515245 + attempt * 12345) & 0x7fffffff)


func _free_directions(
	grid: Vector2i,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Array[String]:
	var choices: Array[String] = []
	for direction in DIRECTIONS:
		var delta: Vector2i = DELTAS[direction]
		if not occupied.has(grid + delta):
			choices.append(direction)
	for index in range(choices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var current: String = choices[index]
		choices[index] = choices[swap_index]
		choices[swap_index] = current
	return choices


func _direction_for(delta: Vector2i) -> StringName:
	for direction in DIRECTIONS:
		if DELTAS[direction] == delta:
			return StringName(direction)
	return &""


func _add_reconnections(run_map: RefCounted, rng: RandomNumberGenerator) -> void:
	var ids: Array[String] = run_map.room_ids()
	for first_index in range(ids.size()):
		var first_id: String = ids[first_index]
		var first_data: Dictionary = run_map.room(first_id)
		var first_grid: Vector2i = first_data["grid"]
		var first_doors: Dictionary = first_data["doors"]
		for second_index in range(first_index + 1, ids.size()):
			var second_id: String = ids[second_index]
			if first_doors.values().has(second_id):
				continue
			var second_data: Dictionary = run_map.room(second_id)
			var second_grid: Vector2i = second_data["grid"]
			var delta: Vector2i = second_grid - first_grid
			if absi(delta.x) + absi(delta.y) != 1:
				continue
			if rng.randf() < RECONNECTION_CHANCE:
				run_map.connect_rooms(first_id, second_id, _direction_for(delta))
