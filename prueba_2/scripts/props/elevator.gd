extends Area2D

@export var direction: String = "N"

var _armed := false

func _ready() -> void:
	body_exited.connect(_on_body_exited)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_armed = get_overlapping_bodies().is_empty()

func _on_body_exited(_body: Node) -> void:
	_armed = true

func _on_body_entered(body: Node) -> void:
	if not _armed or not body is CharacterBody2D:
		return
	var doors: Dictionary = RoomDB.ROOMS[GameState.current_room]["doors"]
	if not doors.has(direction):
		return
	_armed = false
	Transition.go_to(doors[direction], direction)
