extends RefCounted

const RunMap := preload("res://core/run_map.gd")
const RoomBackgrounds := preload("res://core/room_backgrounds.gd")

const MAX_ATTEMPTS := 128
const MIN_MAIN_PATH := 6
const MAX_MAIN_PATH := 8
const MAX_ROOMS := 24
const DIRECTIONS: Array[String] = ["N", "E", "S", "O"]
const DELTAS: Dictionary = {
	"N": Vector2i.UP,
	"E": Vector2i.RIGHT,
	"S": Vector2i.DOWN,
	"O": Vector2i.LEFT,
}
const NORMAL_CONTENT: Array = [
	[&"easy", 50],
	[&"hard", 30],
	[&"empty", 20],
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
	var occupied: Dictionary = {}
	var target_length := rng.randi_range(MIN_MAIN_PATH, MAX_MAIN_PATH)
	var rotation := rng.randi_range(0, 3)
	var mirror := rng.randi_range(0, 1) == 1

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
		var grid := _transform_grid(Vector2i(index, 0), rotation, mirror)
		run_map.add_room(room_id, grid, role, &"unassigned")
		run_map.room(room_id)["layer"] = index * 4
		run_map.main_path.append(room_id)
		occupied[grid] = room_id

	run_map.entry_room_id = run_map.main_path[0]
	run_map.boss_room_id = run_map.main_path[-1]
	for index in range(run_map.main_path.size() - 1):
		_connect_adjacent(
			run_map,
			run_map.main_path[index],
			run_map.main_path[index + 1]
		)

	# La bifurcación empieza después de la sala del cuerpo. La ruta inferior
	# vuelve a converger en C_03 y ambas opciones continúan al mismo jefe.
	var split_id: String = run_map.main_path[2]
	var rejoin_id: String = run_map.main_path[3]
	var branch_a_grid := _transform_grid(Vector2i(2, 1), rotation, mirror)
	var branch_b_grid := _transform_grid(Vector2i(3, 1), rotation, mirror)
	run_map.add_room("B_00", branch_a_grid, &"branch", &"unassigned")
	run_map.add_room("B_01", branch_b_grid, &"branch", &"unassigned")
	run_map.room("B_00")["layer"] = int(run_map.room(split_id)["layer"]) + 1
	run_map.room("B_01")["layer"] = int(run_map.room(split_id)["layer"]) + 2
	occupied[branch_a_grid] = "B_00"
	occupied[branch_b_grid] = "B_01"
	_connect_adjacent(run_map, split_id, "B_00")
	_connect_adjacent(run_map, "B_00", "B_01")
	_connect_adjacent(run_map, "B_01", rejoin_id)

	_populate_content(run_map, rng)
	if not _add_grates(run_map, rng, occupied):
		run_map.set_meta("generation_error", "no se pudieron ubicar todas las rejillas")
	return run_map


func validate(run_map: RefCounted) -> PackedStringArray:
	var errors := PackedStringArray()
	if run_map == null:
		errors.append("el generador devolvió un mapa nulo")
		return errors
	if run_map.has_meta("generation_error"):
		errors.append(String(run_map.get_meta("generation_error")))
	if run_map.main_path.size() < MIN_MAIN_PATH or run_map.main_path.size() > MAX_MAIN_PATH:
		errors.append("main_path debe tener 6-8 salas")
	if run_map.rooms.size() > MAX_ROOMS:
		errors.append("el mapa supera el presupuesto de salas")
	if run_map.main_path.size() < 2:
		errors.append("faltan hitos iniciales")
		return errors

	var entry_data: Dictionary = run_map.room(run_map.entry_room_id)
	var body_data: Dictionary = run_map.room(run_map.main_path[1])
	var boss_data: Dictionary = run_map.room(run_map.boss_room_id)
	if entry_data.get("role", &"") != &"entry" or entry_data["doors"].size() != 1:
		errors.append("la sala inicial debe tener una sola salida")
	if (
		body_data.get("role", &"") != &"body"
		or body_data.get("content_type", &"") != &"body_reward"
		or body_data["entrances"].size() != 1
		or body_data["doors"].size() != 1
	):
		errors.append("la segunda sala debe tener una entrada sellada y una salida")
	if not FIRST_PART_POOL.has(String(body_data.get("reward_part_id", ""))):
		errors.append("la primera recompensa no pertenece al pool")
	if boss_data.get("role", &"") != &"boss_choice":
		errors.append("el jefe debe ser el último hito")
	if not run_map.forward_neighbors(run_map.boss_room_id).is_empty():
		errors.append("el jefe debe ser el único sumidero")

	var occupied: Dictionary = {}
	var branches := 0
	for room_id: String in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var grid: Vector2i = data["grid"]
		if occupied.has(grid):
			errors.append("coordenada repetida: %s" % grid)
		occupied[grid] = room_id

		var openings := _opening_directions(data)
		if not RoomBackgrounds.has_template(openings):
			errors.append("%s no tiene fondo para %s" % [room_id, openings])
		if data["doors"].size() >= 2:
			branches += 1

		for direction_value: Variant in data["doors"]:
			var direction := String(direction_value)
			var target_id := String(data["doors"][direction])
			if not DELTAS.has(direction) or not run_map.rooms.has(target_id):
				errors.append("%s tiene una salida inválida" % room_id)
				continue
			var target: Dictionary = run_map.room(target_id)
			if target["grid"] - grid != Vector2i(DELTAS[direction]):
				errors.append("%s.%s no coincide con la cuadrícula" % [room_id, direction])
			if int(target.get("layer", 0)) <= int(data.get("layer", 0)):
				errors.append("%s conecta hacia una capa no futura" % room_id)

		var role: StringName = data.get("role", &"normal")
		var content: StringName = data.get("content_type", &"empty")
		if role in [&"normal", &"branch"] and not content in [&"easy", &"hard", &"empty"]:
			errors.append("%s tiene contenido normal inválido" % room_id)
		if content == &"easy" and int(data.get("enemy_count", 0)) != 1:
			errors.append("%s fácil necesita un enemigo" % room_id)
		if content == &"hard" and int(data.get("enemy_count", 0)) not in [2, 3]:
			errors.append("%s difícil necesita dos o tres enemigos" % room_id)

		var must_have_grate := (
			role == &"preboss"
			or (
				role in [&"normal", &"branch"]
				and content in [&"easy", &"hard"]
			)
		)
		var grate_target := String(data.get("grate_target", ""))
		if must_have_grate != not grate_target.is_empty():
			errors.append("%s no cumple su regla de rejilla" % room_id)
		if not grate_target.is_empty():
			if not run_map.rooms.has(grate_target):
				errors.append("%s apunta a una rejilla inexistente" % room_id)
			elif String(run_map.room(grate_target).get("grate_source", "")) != room_id:
				errors.append("%s no registra su fuente de rejilla" % grate_target)

		if role == &"grate_destination":
			if not grate_target.is_empty():
				errors.append("%s no puede encadenar otra rejilla" % room_id)
			if data["doors"].is_empty():
				errors.append("%s debe seguir hacia delante" % room_id)
			if content == &"combat" and int(data.get("enemy_count", 0)) <= 0:
				errors.append("%s necesita combate obligatorio" % room_id)
			if content == &"loot" and not FIRST_PART_POOL.has(
				String(data.get("reward_part_id", ""))
			):
				errors.append("%s necesita una parte de loot" % room_id)

		if room_id != run_map.boss_room_id and not run_map.can_reach(
			room_id,
			run_map.boss_room_id
		):
			errors.append("%s no alcanza al jefe" % room_id)

	if branches == 0:
		errors.append("falta una bifurcación real")
	if _has_cycle(run_map):
		errors.append("el mapa dirigido contiene un ciclo")
	return errors


func _populate_content(run_map: RefCounted, rng: RandomNumberGenerator) -> void:
	run_map.room(run_map.entry_room_id)["content_type"] = &"tutorial"
	var body_data: Dictionary = run_map.room(run_map.main_path[1])
	body_data["content_type"] = &"body_reward"
	body_data["reward_part_id"] = _random_part(rng)
	var preboss_data: Dictionary = run_map.room(run_map.main_path[-2])
	preboss_data["content_type"] = &"preboss"
	preboss_data["enemy_count"] = 3
	run_map.room(run_map.boss_room_id)["content_type"] = &"boss_choice"

	for room_id: String in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		if data.get("content_type", &"") != &"unassigned":
			continue
		var content := _weighted_choice(rng, NORMAL_CONTENT)
		data["content_type"] = content
		if content == &"easy":
			data["enemy_count"] = 1
		elif content == &"hard":
			data["enemy_count"] = rng.randi_range(2, 3)


func _add_grates(
	run_map: RefCounted,
	rng: RandomNumberGenerator,
	occupied: Dictionary
) -> bool:
	var sources: Array[String] = []
	for room_id: String in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var role: StringName = data.get("role", &"normal")
		var content: StringName = data.get("content_type", &"empty")
		if (
			role == &"preboss"
			or (
				role in [&"normal", &"branch"]
				and content in [&"easy", &"hard"]
			)
		):
			sources.append(room_id)
	sources.sort_custom(
		func(a: String, b: String) -> bool:
			return int(run_map.room(a)["layer"]) > int(run_map.room(b)["layer"])
	)

	for source_id: String in sources:
		var source_data: Dictionary = run_map.room(source_id)
		var wall_directions := _available_grate_directions(source_data)
		_shuffle_strings(wall_directions, rng)
		if wall_directions.is_empty():
			return false

		var rejoin := _find_grate_rejoin(run_map, source_id, occupied, rng)
		if rejoin.is_empty():
			return false
		var rejoin_id := String(rejoin["room_id"])
		var grate_grid: Vector2i = rejoin["grid"]
		var grate_id := "G_%02d" % _grate_count(run_map)
		var grate_content := _weighted_choice(rng, GRATE_CONTENT)
		run_map.add_room(grate_id, grate_grid, &"grate_destination", grate_content)
		var grate_data: Dictionary = run_map.room(grate_id)
		grate_data["layer"] = int(source_data["layer"]) + 1
		if grate_content == &"combat":
			grate_data["enemy_count"] = rng.randi_range(1, 2)
		elif grate_content == &"loot":
			grate_data["reward_part_id"] = _random_part(rng)
		_connect_adjacent(run_map, grate_id, rejoin_id)
		run_map.set_grate(source_id, grate_id, StringName(wall_directions[0]))
		occupied[grate_grid] = grate_id
	return true


func _find_grate_rejoin(
	run_map: RefCounted,
	source_id: String,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var source_layer := int(run_map.room(source_id)["layer"])
	var candidates: Array[String] = []
	for room_id: String in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		if data.get("role", &"") == &"grate_destination":
			continue
		if int(data.get("layer", 0)) >= source_layer + 2:
			candidates.append(room_id)
	candidates.sort_custom(
		func(a: String, b: String) -> bool:
			return int(run_map.room(a)["layer"]) < int(run_map.room(b)["layer"])
	)
	if run_map.room(source_id).get("role", &"") == &"preboss":
		candidates.assign([run_map.boss_room_id])

	for target_id: String in candidates:
		var target_grid: Vector2i = run_map.room(target_id)["grid"]
		var directions := DIRECTIONS.duplicate()
		_shuffle_strings(directions, rng)
		for direction: String in directions:
			var candidate_grid := target_grid - Vector2i(DELTAS[direction])
			if occupied.has(candidate_grid):
				continue
			return {"room_id": target_id, "grid": candidate_grid}
	return {}


func _available_grate_directions(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var occupied_walls: Dictionary = {}
	for direction: Variant in data.get("doors", {}):
		occupied_walls[String(direction)] = true
	for direction: Variant in data.get("entrances", {}):
		occupied_walls[String(direction)] = true
	for direction: String in DIRECTIONS:
		if not occupied_walls.has(direction):
			result.append(direction)
	return result


func _opening_directions(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for direction: Variant in data.get("doors", {}):
		result[String(direction)] = true
	for direction: Variant in data.get("entrances", {}):
		result[String(direction)] = true
	return result


func _connect_adjacent(run_map: RefCounted, from_id: String, to_id: String) -> void:
	var from_grid: Vector2i = run_map.room(from_id)["grid"]
	var to_grid: Vector2i = run_map.room(to_id)["grid"]
	var direction := _direction_for(to_grid - from_grid)
	assert(direction != &"", "%s y %s no son adyacentes" % [from_id, to_id])
	run_map.connect_forward(from_id, to_id, direction)


func _transform_grid(grid: Vector2i, rotation: int, mirror: bool) -> Vector2i:
	var result := grid
	if mirror:
		result.y = -result.y
	for _step in range(rotation):
		result = Vector2i(-result.y, result.x)
	return result


func _direction_for(delta: Vector2i) -> StringName:
	for direction: String in DIRECTIONS:
		if Vector2i(DELTAS[direction]) == delta:
			return StringName(direction)
	return &""


func _weighted_choice(rng: RandomNumberGenerator, table: Array) -> StringName:
	var roll := rng.randi_range(1, 100)
	var cursor := 0
	for item_value: Variant in table:
		var item: Array = item_value
		cursor += int(item[1])
		if roll <= cursor:
			return item[0]
	var fallback: Array = table[-1]
	return fallback[0]


func _random_part(rng: RandomNumberGenerator) -> String:
	return FIRST_PART_POOL[rng.randi_range(0, FIRST_PART_POOL.size() - 1)]


func _shuffle_strings(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = current


func _grate_count(run_map: RefCounted) -> int:
	var result := 0
	for room_id: String in run_map.room_ids():
		if run_map.room(room_id).get("role", &"") == &"grate_destination":
			result += 1
	return result


func _has_cycle(run_map: RefCounted) -> bool:
	var colors: Dictionary = {}
	for room_id: String in run_map.room_ids():
		if int(colors.get(room_id, 0)) == 0 and _visit_cycle(run_map, room_id, colors):
			return true
	return false


func _visit_cycle(
	run_map: RefCounted,
	room_id: String,
	colors: Dictionary
) -> bool:
	colors[room_id] = 1
	for target_id: String in run_map.forward_neighbors(room_id):
		var color := int(colors.get(target_id, 0))
		if color == 1:
			return true
		if color == 0 and _visit_cycle(run_map, target_id, colors):
			return true
	colors[room_id] = 2
	return false


func _mixed_seed(run_seed: int, attempt: int) -> int:
	return int((run_seed * 1103515245 + attempt * 12345) & 0x7fffffff)
