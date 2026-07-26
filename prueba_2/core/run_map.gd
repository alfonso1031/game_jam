extends RefCounted

const OPPOSITE: Dictionary = {"N": "S", "S": "N", "E": "O", "O": "E"}

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
		"one_way": {},
		"grate_target": "",
		"closure_keep_direction": "",
	}


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


func set_grate(source_id: String, target_id: String) -> void:
	rooms[source_id]["grate_target"] = target_id


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
