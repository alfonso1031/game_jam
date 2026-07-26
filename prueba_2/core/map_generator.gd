extends RefCounted

const RunMap := preload("res://core/run_map.gd")
const RoomBackgrounds := preload("res://core/room_backgrounds.gd")

const MAX_ATTEMPTS := 128
const MIN_MAIN_PATH := 6
const MAX_MAIN_PATH := 8
const MAX_ROOMS := 12
const RECONNECTION_CHANCE := 0.35
const GRATE_CHANCE := 0.60
const DIRECTIONS: Array[String] = ["N", "E", "S", "O"]
const DELTAS: Dictionary = {
	"N": Vector2i.UP,
	"E": Vector2i.RIGHT,
	"S": Vector2i.DOWN,
	"O": Vector2i.LEFT,
}
const NORMAL_CONTENT: Array = [
	[&"easy", 40],
	[&"hard", 30],
	[&"empty", 20],
	[&"closure", 10],
]
const GRATE_CONTENT: Array = [
	[&"empty", 40],
	[&"combat", 20],
	[&"loot", 40],
]
const FIRST_PART_POOL: Array[String] = [
	"acid_stinger",
	"serrated_jaw",
	"hydraulic_legs",
	"bio_netcaster",
]


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
		elif index == 1:
			role = &"body"
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
	if not _populate_content(run_map, rng, occupied):
		run_map.set_meta("generation_error", "no se pudieron ubicar contenido y rejillas")
	return run_map


func validate(run_map: RefCounted) -> PackedStringArray:
	var errors := PackedStringArray()
	if run_map.has_meta("generation_error"):
		errors.append(String(run_map.get_meta("generation_error")))
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
	var body_id: String = run_map.main_path[1]
	var body_data: Dictionary = run_map.room(body_id)
	if body_data["role"] != &"body" or body_data["content_type"] != &"body_reward":
		errors.append("el cuerpo no ocupa el segundo hito")
	if not FIRST_PART_POOL.has(String(body_data["reward_part_id"])):
		errors.append("el cuerpo tiene recompensa inválida")
	if not run_map.room(run_map.main_path[0])["doors"].values().has(body_id):
		errors.append("el tutorial no conecta directamente con el cuerpo")
	if not String(body_data["grate_target"]).is_empty():
		errors.append("el cuerpo no puede originar una rejilla")
	if body_data["doors"].size() != 2:
		errors.append("el cuerpo solo conecta los hitos anterior y siguiente")
	if run_map.room(run_map.main_path[-2])["role"] != &"preboss":
		errors.append("el preboss no es el penúltimo hito")
	if run_map.room(run_map.main_path[-1])["role"] != &"boss_choice":
		errors.append("el boss no es el último hito")

	var occupied: Dictionary = {}
	var grate_targets: Dictionary = {}
	var eligible_combats := 0
	var grate_count := 0
	for room_id in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var grid: Vector2i = data["grid"]
		if occupied.has(grid):
			errors.append("coordenada repetida: %s" % grid)
		occupied[grid] = room_id
		var doors: Dictionary = data["doors"]
		if not RoomBackgrounds.has_template(doors):
			errors.append(
				"%s no tiene fondo para puertas '%s'"
				% [room_id, RoomBackgrounds.key_for(doors)]
			)
		var one_way: Dictionary = data["one_way"]
		for direction_value: Variant in doors:
			var direction: String = String(direction_value)
			if not DELTAS.has(direction):
				errors.append("%s usa dirección inválida %s" % [room_id, direction])
				continue
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

		var role: StringName = data["role"]
		var content: StringName = data["content_type"]
		if role == &"normal" and not content in [&"easy", &"hard", &"empty", &"closure"]:
			errors.append("%s tiene contenido normal inválido" % room_id)
		if content == &"easy" and int(data["enemy_count"]) != 1:
			errors.append("%s fácil debe tener un enemigo" % room_id)
		if content == &"hard":
			var enemy_count: int = data["enemy_count"]
			if enemy_count < 2 or enemy_count > 3:
				errors.append("%s difícil debe tener 2–3 enemigos" % room_id)
		if role != &"grate_destination" and _is_combat(content):
			eligible_combats += 1

		var grate_target: String = data["grate_target"]
		if grate_target != "":
			grate_count += 1
			if not _is_combat(content):
				errors.append("%s tiene rejilla sin ser combate" % room_id)
			if not run_map.rooms.has(grate_target):
				errors.append("%s apunta a rejilla inexistente" % room_id)
			elif grate_targets.has(grate_target):
				errors.append("%s comparte destino de rejilla" % room_id)
			else:
				grate_targets[grate_target] = room_id
				var grate_data: Dictionary = run_map.room(grate_target)
				if grate_data["role"] != &"grate_destination":
					errors.append("%s no apunta a destino de rejilla" % room_id)
				elif String(grate_data["grate_source"]) != room_id:
					errors.append("%s no registra el retorno desde %s" % [grate_target, room_id])

		if role == &"grate_destination":
			var grate_source: String = data["grate_source"]
			if grate_source.is_empty():
				errors.append("%s no registra fuente de rejilla" % room_id)
			elif not run_map.rooms.has(grate_source):
				errors.append("%s registra fuente de rejilla inexistente" % room_id)
			elif run_map.room(grate_source)["grate_target"] != room_id:
				errors.append("%s no coincide con el destino de %s" % [room_id, grate_source])

		if content == &"closure":
			_validate_closure(run_map, room_id, data, errors)
		if role == &"branch" and doors.size() < 2 and grate_target == "":
			errors.append("%s no reconecta ni termina en rejilla" % room_id)

	for path_index in range(run_map.main_path.size() - 1):
		var path_id: String = run_map.main_path[path_index]
		var next_id: String = run_map.main_path[path_index + 1]
		var path_doors: Dictionary = run_map.room(path_id)["doors"]
		if not path_doors.values().has(next_id):
			errors.append("%s no conecta con el siguiente hito" % path_id)
	if eligible_combats > 0 and grate_count == 0:
		errors.append("falta la rejilla mínima")
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
		if first_data["role"] == &"body":
			continue
		var first_grid: Vector2i = first_data["grid"]
		var first_doors: Dictionary = first_data["doors"]
		for second_index in range(first_index + 1, ids.size()):
			var second_id: String = ids[second_index]
			if first_doors.values().has(second_id):
				continue
			var second_data: Dictionary = run_map.room(second_id)
			if second_data["role"] == &"body":
				continue
			var second_grid: Vector2i = second_data["grid"]
			var delta: Vector2i = second_grid - first_grid
			if absi(delta.x) + absi(delta.y) != 1:
				continue
			if rng.randf() < RECONNECTION_CHANCE:
				run_map.connect_rooms(first_id, second_id, _direction_for(delta))


func _populate_content(
	run_map: RefCounted,
	rng: RandomNumberGenerator,
	occupied: Dictionary
) -> bool:
	var entry_data: Dictionary = run_map.room(run_map.entry_room_id)
	entry_data["content_type"] = &"tutorial"
	var body_data: Dictionary = run_map.room(run_map.main_path[1])
	body_data["content_type"] = &"body_reward"
	body_data["reward_part_id"] = FIRST_PART_POOL[
		rng.randi_range(0, FIRST_PART_POOL.size() - 1)
	]
	var preboss_id: String = run_map.main_path[-2]
	var preboss_data: Dictionary = run_map.room(preboss_id)
	preboss_data["content_type"] = &"preboss"
	var boss_data: Dictionary = run_map.room(run_map.boss_room_id)
	boss_data["content_type"] = &"boss_choice"

	var branches_requiring_grate: Array[String] = []
	var branch_index := 0
	for path_index in range(2, run_map.main_path.size() - 2):
		var room_id: String = run_map.main_path[path_index]
		var data: Dictionary = run_map.room(room_id)
		var content: StringName = _weighted_choice(rng, NORMAL_CONTENT)
		data["content_type"] = content
		if content == &"easy":
			data["enemy_count"] = 1
		elif content == &"hard":
			data["enemy_count"] = rng.randi_range(2, 3)
		elif content == &"closure":
			if not _configure_closure(
				run_map,
				rng,
				occupied,
				path_index,
				branch_index,
				branches_requiring_grate
			):
				return false
			branch_index += 1

	return _add_grates(run_map, rng, occupied, branches_requiring_grate)


func _configure_closure(
	run_map: RefCounted,
	rng: RandomNumberGenerator,
	occupied: Dictionary,
	path_index: int,
	branch_index: int,
	branches_requiring_grate: Array[String]
) -> bool:
	var room_id: String = run_map.main_path[path_index]
	var data: Dictionary = run_map.room(room_id)
	var doors: Dictionary = data["doors"]
	if doors.size() > 3:
		return false
	if doors.size() < 3:
		if run_map.rooms.size() >= MAX_ROOMS:
			return false
		var grid: Vector2i = data["grid"]
		var free_directions: Array[String] = _free_directions(grid, occupied, rng)
		if free_directions.is_empty():
			return false
		var branch_direction: String = free_directions[0]
		var branch_grid: Vector2i = grid + Vector2i(DELTAS[branch_direction])
		var branch_id := "B_%02d" % branch_index
		run_map.add_room(branch_id, branch_grid, &"branch", &"combat")
		var branch_data: Dictionary = run_map.room(branch_id)
		branch_data["enemy_count"] = rng.randi_range(1, 3)
		run_map.connect_rooms(room_id, branch_id, StringName(branch_direction))
		occupied[branch_grid] = branch_id

		var reconnections: Array[String] = _adjacent_candidates(
			run_map,
			branch_id,
			room_id
		)
		_shuffle_strings(reconnections, rng)
		if reconnections.is_empty():
			branches_requiring_grate.append(branch_id)
		else:
			var target_id: String = reconnections[0]
			var target_grid: Vector2i = run_map.room(target_id)["grid"]
			run_map.connect_rooms(
				branch_id,
				target_id,
				_direction_for(target_grid - branch_grid)
			)

	doors = data["doors"]
	if doors.size() != 3:
		return false
	var next_id: String = run_map.main_path[path_index + 1]
	var keep_direction := _direction_to_target(doors, next_id)
	if keep_direction == "":
		return false
	data["closure_keep_direction"] = keep_direction
	return true


func _add_grates(
	run_map: RefCounted,
	rng: RandomNumberGenerator,
	occupied: Dictionary,
	required_sources: Array[String]
) -> bool:
	var eligible: Array[String] = []
	for room_id in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var role: StringName = data["role"]
		var content: StringName = data["content_type"]
		if role != &"grate_destination" and _is_combat(content):
			eligible.append(room_id)
	if eligible.is_empty():
		return true

	var optional_sources: Array[String] = []
	for source_id in eligible:
		if required_sources.has(source_id):
			continue
		optional_sources.append(source_id)
	_shuffle_strings(optional_sources, rng)

	var capacity: int = MAX_ROOMS - run_map.rooms.size()
	if required_sources.size() > capacity:
		return false
	var selected: Array[String] = required_sources.duplicate()
	if capacity <= 0:
		return false

	# El mínimo de una rejilla sesga hacia arriba un roll independiente cuando
	# hay pocos combates. El redondeo estocástico conserva 60 % en el conjunto,
	# sin perder el mínimo ni las fuentes obligatorias de cierres.
	var exact_target: float = float(eligible.size()) * GRATE_CHANCE
	var target_count: int = floori(exact_target)
	if rng.randf() < exact_target - float(target_count):
		target_count += 1
	target_count = maxi(1, maxi(target_count, required_sources.size()))
	target_count = mini(target_count, mini(capacity, eligible.size()))
	var optional_count: int = target_count - selected.size()
	for index in range(mini(optional_count, optional_sources.size())):
		selected.append(optional_sources[index])

	for grate_index in range(selected.size()):
		var source_id: String = selected[grate_index]
		var source_data: Dictionary = run_map.room(source_id)
		var source_grid: Vector2i = source_data["grid"]
		var grate_grid: Vector2i = _free_grate_grid(source_grid, occupied, rng)
		var grate_id := "G_%02d" % grate_index
		var grate_content: StringName = _weighted_choice(rng, GRATE_CONTENT)
		run_map.add_room(grate_id, grate_grid, &"grate_destination", grate_content)
		var grate_data: Dictionary = run_map.room(grate_id)
		if grate_content == &"combat":
			grate_data["enemy_count"] = rng.randi_range(1, 2)
		run_map.set_grate(source_id, grate_id)
		occupied[grate_grid] = grate_id
	return true


func _weighted_choice(rng: RandomNumberGenerator, table: Array) -> StringName:
	var roll: int = rng.randi_range(1, 100)
	var cursor := 0
	for item_value: Variant in table:
		var item: Array = item_value
		cursor += int(item[1])
		if roll <= cursor:
			return item[0]
	var fallback: Array = table[-1]
	return fallback[0]


func _adjacent_candidates(
	run_map: RefCounted,
	source_id: String,
	excluded_id: String
) -> Array[String]:
	var candidates: Array[String] = []
	var source_data: Dictionary = run_map.room(source_id)
	var source_grid: Vector2i = source_data["grid"]
	var source_doors: Dictionary = source_data["doors"]
	for room_id in run_map.room_ids():
		if room_id == source_id or room_id == excluded_id:
			continue
		if run_map.room(room_id)["role"] == &"body":
			continue
		if source_doors.values().has(room_id):
			continue
		var target_grid: Vector2i = run_map.room(room_id)["grid"]
		var delta: Vector2i = target_grid - source_grid
		if absi(delta.x) + absi(delta.y) == 1:
			candidates.append(room_id)
	return candidates


func _free_grate_grid(
	source_grid: Vector2i,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Vector2i:
	var local_choices: Array[String] = _free_directions(source_grid, occupied, rng)
	if not local_choices.is_empty():
		return source_grid + Vector2i(DELTAS[local_choices[0]])
	for radius in range(1, MAX_ROOMS * 2):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var candidate := Vector2i(x, y)
				if not occupied.has(candidate):
					return candidate
	return Vector2i(MAX_ROOMS * 2, MAX_ROOMS * 2)


func _direction_to_target(doors: Dictionary, target_id: String) -> String:
	for direction_value: Variant in doors:
		var direction: String = String(direction_value)
		if doors[direction] == target_id:
			return direction
	return ""


func _shuffle_strings(values: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var current: String = values[index]
		values[index] = values[swap_index]
		values[swap_index] = current


func _is_combat(content: StringName) -> bool:
	return content == &"easy" or content == &"hard" or content == &"combat"


func _validate_closure(
	run_map: RefCounted,
	room_id: String,
	data: Dictionary,
	errors: PackedStringArray
) -> void:
	var doors: Dictionary = data["doors"]
	if doors.size() != 3:
		errors.append("%s cierre debe tener tres salidas" % room_id)
		return
	var keep_direction: String = data["closure_keep_direction"]
	if keep_direction == "" or not doors.has(keep_direction):
		errors.append("%s cierre no define la salida conservada" % room_id)
		return
	var path_index: int = run_map.main_path.find(room_id)
	if path_index < 0 or path_index >= run_map.main_path.size() - 1:
		errors.append("%s cierre no pertenece al camino interno" % room_id)
		return
	var expected_next: String = run_map.main_path[path_index + 1]
	if doors[keep_direction] != expected_next:
		errors.append("%s cierre no conserva el siguiente hito" % room_id)
	if not _boss_reachable_after_closure(run_map, room_id, keep_direction):
		errors.append("%s cierre bloquea el acceso al boss" % room_id)


func _boss_reachable_after_closure(
	run_map: RefCounted,
	closure_id: String,
	keep_direction: String
) -> bool:
	var pending: Array[String] = [closure_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var room_id: String = pending.pop_front()
		if visited.has(room_id):
			continue
		visited[room_id] = true
		if room_id == run_map.boss_room_id:
			return true
		var doors: Dictionary = run_map.room(room_id)["doors"]
		for direction_value: Variant in doors:
			var direction: String = String(direction_value)
			if room_id == closure_id and direction != keep_direction:
				continue
			var target_id: String = doors[direction]
			if not visited.has(target_id):
				pending.append(target_id)
	return false
