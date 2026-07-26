extends RefCounted

const OPPOSITE: Dictionary = {"N": "S", "S": "N", "E": "O", "O": "E"}

@warning_ignore("shadowed_global_identifier")
var seed: int
var attempt: int
var floor_id: StringName = &"contencion"
var entry_room_id: String = ""
var boss_room_id: String = ""
var main_path: Array[String] = []
var rooms: Dictionary = {}


func _init(seed_value: int, attempt_value: int) -> void:
	seed = seed_value
	attempt = attempt_value


func add_room(
	room_id: String,
	grid: Vector2i,
	role: StringName,
	content_type: StringName
) -> void:
	rooms[room_id] = {
		"id": room_id,
		"grid": grid,
		"template_id": "",
		"role": role,
		"content_type": content_type,
		"enemy_count": 0,
		"doors": {},
		"entrances": {},
		"one_way": {},
		"layer": 0,
		"grate_target": "",
		"grate_source": "",
		"grate_direction": "",
		"grate_arrival_direction": "",
		"closure_keep_direction": "",
		"reward_part_id": "",
	}


func connect_forward(
	from_id: String,
	to_id: String,
	direction: StringName
) -> void:
	var exit_direction := String(direction)
	var entry_direction: String = OPPOSITE[exit_direction]
	rooms[from_id]["doors"][exit_direction] = to_id
	rooms[from_id]["one_way"][exit_direction] = true
	rooms[to_id]["entrances"][entry_direction] = from_id


func connect_rooms(
	from_id: String,
	to_id: String,
	direction: StringName,
	one_way: bool = false
) -> void:
	var dir: String = String(direction)
	var back: String = OPPOSITE[dir]
	var from_doors: Dictionary = rooms[from_id]["doors"]
	var from_one_way: Dictionary = rooms[from_id]["one_way"]
	from_doors[dir] = to_id
	from_one_way[dir] = one_way
	if not one_way:
		var to_doors: Dictionary = rooms[to_id]["doors"]
		var to_one_way: Dictionary = rooms[to_id]["one_way"]
		to_doors[back] = from_id
		to_one_way[back] = false


func set_grate(
	source_id: String,
	target_id: String,
	direction: StringName
) -> void:
	var source_direction := String(direction)
	rooms[source_id]["grate_target"] = target_id
	rooms[source_id]["grate_direction"] = source_direction
	rooms[target_id]["grate_source"] = source_id
	rooms[target_id]["grate_arrival_direction"] = OPPOSITE[source_direction]


func forward_neighbors(room_id: String) -> Array[String]:
	var result: Array[String] = []
	var data := room(room_id)
	for target_value: Variant in data.get("doors", {}).values():
		var target := String(target_value)
		if not result.has(target):
			result.append(target)
	var grate_target := String(data.get("grate_target", ""))
	if not grate_target.is_empty() and not result.has(grate_target):
		result.append(grate_target)
	result.sort()
	return result


func can_reach(from_id: String, target_id: String) -> bool:
	var pending: Array[String] = [from_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if current == target_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		pending.append_array(forward_neighbors(current))
	return false


func room(room_id: String) -> Dictionary:
	return rooms.get(room_id, {})


func room_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(rooms.keys())
	ids.sort()
	return ids


func canonical_snapshot() -> Dictionary:
	var ordered_rooms: Array[Dictionary] = []
	for room_id in room_ids():
		ordered_rooms.append(room(room_id).duplicate(true))
	return {
		"seed": seed,
		"attempt": attempt,
		"floor_id": String(floor_id),
		"entry_room_id": entry_room_id,
		"boss_room_id": boss_room_id,
		"main_path": main_path.duplicate(),
		"rooms": ordered_rooms,
	}
