extends Node2D

const EnemyDB := preload("res://core/enemy_db.gd")
const DoorScene := preload("res://world/props/door.tscn")
const LampScene := preload("res://world/props/lamp.tscn")

const ROOM_CENTER := Vector2(960, 540)
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
