extends Node2D

const EnemyDB := preload("res://core/enemy_db.gd")
const ContainmentPropCatalog := preload("res://core/containment_prop_catalog.gd")
const DoorScene := preload("res://world/props/door.tscn")
const LampScene := preload("res://world/props/lamp.tscn")
const BloodTrailScene := preload("res://world/props/blood_trail.tscn")
const BodySourceScene := preload("res://world/props/body_source.tscn")
const TutorialMuralScene := preload("res://world/props/tutorial_mural.tscn")
const GrateScene := preload("res://world/props/grate.tscn")

const ROOM_CENTER := Vector2(960, 540)
const BODY_POSITION := Vector2(1060, 540)
const INTERIOR_ORIGIN := Vector2(180, 120)
const CELL := 120.0
const DOOR_POSITIONS := {
	"N": Vector2(960, 60),
	"E": Vector2(1800, 540),
	"S": Vector2(960, 1020),
	"O": Vector2(120, 540),
}
const SPAWN_POSITIONS := {
	"N": Vector2(960, 220),
	"E": Vector2(1640, 540),
	"S": Vector2(960, 860),
	"O": Vector2(240, 540),
}
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(4, 2),
	Vector2i(8, 4),
	Vector2i(6, 3),
]
const CONTAINMENT_ENEMIES: Array[String] = ["exp01", "exp02", "exp03"]

var _room_data: Dictionary = {}
var _alive: Array[Node] = []


func configure(room_data: Dictionary) -> void:
	_room_data = room_data.duplicate(true)
	var room_id: String = _room_data["id"]
	name = room_id
	set_meta("room_id", room_id)
	set_meta("content_type", _room_data.get("content_type", &"empty"))
	set_meta("enemy_count", int(_room_data.get("enemy_count", 0)))
	set_meta("room_data", _room_data)
	_build_background()
	_build_walls_and_doors()
	_build_lighting()
	_build_environment_props()
	_build_story_content()
	_build_tutorial_mural()
	_build_grate()


func _ready() -> void:
	add_to_group("room")
	_spawn_enemies()
	if _room_data.get("content_type", &"") == &"closure":
		_apply_closure()


func cell_center(cell: Vector2i) -> Vector2:
	return INTERIOR_ORIGIN + Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


func is_cleared() -> bool:
	return _alive.is_empty()


func _build_background() -> void:
	var doors: Dictionary = _room_data["doors"]
	var directions: Array[String] = []
	directions.assign(doors.keys())
	var template: Dictionary = RoomDB.template_for(directions)
	assert(not template.is_empty(), "No existe fondo para %s" % [directions])
	var background := Sprite2D.new()
	background.name = "Background"
	background.texture = load(template["background"])
	background.flip_h = bool(template.get("flip_h", false))
	background.position = ROOM_CENTER
	background.z_index = -10
	if template.has("virtual_opening"):
		background.set_meta("virtual_opening", template["virtual_opening"])
	add_child(background)


func _build_walls_and_doors() -> void:
	var doors: Dictionary = _room_data["doors"]
	_build_horizontal_wall("N", doors.has("N"))
	_build_horizontal_wall("S", doors.has("S"))
	_build_vertical_wall("O", doors.has("O"))
	_build_vertical_wall("E", doors.has("E"))
	for direction in ["N", "E", "S", "O"]:
		if not doors.has(direction):
			continue
		var door: Area2D = DoorScene.instantiate()
		door.name = "Door%s" % direction
		door.position = DOOR_POSITIONS[direction]
		door.direction = direction
		add_child(door)
		var spawn := Marker2D.new()
		spawn.name = "Spawn%s" % direction
		spawn.position = SPAWN_POSITIONS[direction]
		add_child(spawn)


func _build_horizontal_wall(direction: String, has_door: bool) -> void:
	var y := 60.0 if direction == "N" else 1020.0
	if has_door:
		_add_wall("%sLeft" % direction, Vector2(450, y), Vector2(780, 120))
		_add_wall("%sRight" % direction, Vector2(1470, y), Vector2(780, 120))
	else:
		_add_wall(direction, Vector2(960, y), Vector2(1800, 120))


func _build_vertical_wall(direction: String, has_door: bool) -> void:
	var x := 120.0 if direction == "O" else 1800.0
	if has_door:
		_add_wall("%sUpper" % direction, Vector2(x, 270), Vector2(120, 300))
		_add_wall("%sLower" % direction, Vector2(x, 810), Vector2(120, 300))
	else:
		_add_wall(direction, Vector2(x, 540), Vector2(120, 840))


func _add_wall(node_name: String, wall_position: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = node_name
	collision.position = wall_position
	collision.shape = shape
	$Walls.add_child(collision)


func _build_lighting() -> void:
	for data_value: Variant in [
		["N", 2, Vector2(420, 60), 0.0],
		["N", 10, Vector2(1380, 60), 0.0],
		["S", 2, Vector2(420, 1020), 0.0],
		["S", 10, Vector2(1380, 1020), 0.0],
	]:
		var data: Array = data_value
		var lamp: Node2D = LampScene.instantiate()
		lamp.name = "Lamp%s%d" % [data[0], data[1]]
		lamp.position = data[2]
		lamp.rotation = float(data[3])
		add_child(lamp)


func _build_environment_props() -> void:
	var placements: Array[Dictionary] = ContainmentPropCatalog.placements_for(_room_data)
	for index: int in range(placements.size()):
		var placement: Dictionary = placements[index]
		var scene: PackedScene = placement["scene"] as PackedScene
		var prop: Node2D = scene.instantiate()
		var prop_id: String = String(placement["id"])
		prop.name = "Prop_%s_%d" % [prop_id, index]
		prop.position = placement["position"] as Vector2
		prop.set_meta("prop_id", prop_id)
		add_child(prop)


func _build_story_content() -> void:
	if RunManager.current_map == null or RunManager.current_map.main_path.size() < 2:
		return
	var role: StringName = _room_data.get("role", &"normal")
	if role == &"entry":
		var body_id: String = RunManager.current_map.main_path[1]
		var direction := _direction_to(body_id)
		if not _require_story_direction(direction, body_id):
			return
		_add_blood(ROOM_CENTER, DOOR_POSITIONS[direction], false)
	elif role == &"body":
		var entry_id: String = RunManager.current_map.main_path[0]
		var direction := _direction_to(entry_id)
		if not _require_story_direction(direction, entry_id):
			return
		_add_blood(DOOR_POSITIONS[direction], BODY_POSITION, true)
		var source: Node2D = BodySourceScene.instantiate()
		source.name = "BodySource"
		source.position = BODY_POSITION
		source.configure(
			String(_room_data["id"]),
			String(_room_data.get("reward_part_id", ""))
		)
		add_child(source)


func _build_grate() -> void:
	var room_id: String = String(_room_data["id"])
	var target_id: String = String(_room_data.get("grate_target", ""))
	var requires_cost := not target_id.is_empty()
	if target_id.is_empty():
		target_id = String(_room_data.get("grate_source", ""))
	if target_id.is_empty():
		return
	var direction: String = String(_room_data.get("grate_direction", ""))
	assert(DOOR_POSITIONS.has(direction), "Rejilla sin pared válida en %s" % room_id)
	assert(
		not _room_data["doors"].has(direction),
		"Rejilla comparte pared en %s" % room_id
	)

	var grate: Area2D = GrateScene.instantiate()
	grate.name = "Grate"
	grate.position = DOOR_POSITIONS[direction]
	grate.configure(room_id, target_id, requires_cost, direction)
	add_child(grate)

	var spawn := Marker2D.new()
	spawn.name = "GrateSpawn"
	spawn.position = SPAWN_POSITIONS[direction]
	add_child(spawn)


func _direction_to(target_id: String) -> String:
	var doors: Dictionary = _room_data.get("doors", {})
	for direction: String in doors:
		if String(doors[direction]) == target_id:
			return direction
	return ""


func _require_story_direction(direction: String, target_id: String) -> bool:
	if not direction.is_empty() and DOOR_POSITIONS.has(direction):
		return true
	push_error(
		"La sala %s no conecta físicamente con el hito %s"
		% [String(_room_data.get("id", "")), target_id]
	)
	return false


func _add_blood(start: Vector2, finish: Vector2, include_pool: bool) -> void:
	var trail: Node2D = BloodTrailScene.instantiate()
	trail.name = "BloodTrail"
	trail.configure(start, finish, include_pool)
	add_child(trail)


func _build_tutorial_mural() -> void:
	if (
		_room_data.get("role", &"normal") != &"entry"
		or _room_data.get("content_type", &"empty") != &"tutorial"
	):
		return
	var doors: Dictionary = _room_data.get("doors", {})
	var mural: Node2D = TutorialMuralScene.instantiate()
	mural.name = "TutorialMural"
	mural.position = Vector2(960, 290) if doors.has("S") else Vector2(960, 790)
	add_child(mural)


func _spawn_enemies() -> void:
	if GameState.is_room_cleared(String(_room_data["id"])):
		return
	var enemy_count: int = int(_room_data.get("enemy_count", 0))
	if _room_data.get("role", &"") == &"preboss" and enemy_count == 0:
		enemy_count = 3
	for index in range(enemy_count):
		var type_index: int = (_stable_room_index() + index) % CONTAINMENT_ENEMIES.size()
		var type_id: String = CONTAINMENT_ENEMIES[type_index]
		var scene: PackedScene = EnemyDB.scene_for(type_id)
		var enemy: Node2D = scene.instantiate()
		enemy.position = cell_center(ENEMY_CELLS[index % ENEMY_CELLS.size()])
		enemy.is_room_leader = index == enemy_count - 1
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		_alive.append(enemy)
	if not _alive.is_empty():
		_seal_doors(true)


func _stable_room_index() -> int:
	var room_id: String = _room_data["id"]
	var total := 0
	for index in range(room_id.length()):
		total += room_id.unicode_at(index) * (index + 1)
	return total


func _on_enemy_died(enemy: Node) -> void:
	_alive.erase(enemy)
	if not _alive.is_empty():
		return
	GameState.mark_room_cleared(String(_room_data["id"]))
	_seal_doors(false)


func _seal_doors(value: bool) -> void:
	for child in get_children():
		if child.has_method("set_sealed"):
			child.set_sealed(value)


func _apply_closure() -> void:
	var keep_direction: String = _room_data.get("closure_keep_direction", "")
	for child in get_children():
		if child.has_method("set_sealed") and child.direction != keep_direction:
			child.set_sealed(true)
