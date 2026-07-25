extends Area2D

const Palette := preload("res://core/palette.gd")

@export var direction: String = "N"

var _armed := false
var _sealed := false

@onready var plate: ColorRect = $Plate

func _ready() -> void:
	body_exited.connect(_on_body_exited)
	_apply_seal_visual()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_armed = get_overlapping_bodies().is_empty()

func set_sealed(value: bool) -> void:
	_sealed = value
	_apply_seal_visual()

func _apply_seal_visual() -> void:
	# set_sealed() puede llegar desde el boss antes de que corra este _ready.
	if plate == null:
		return
	plate.color = Color(Palette.VOID, 0.8) if _sealed else Color(Palette.WARM_LIGHT, 0.6)

func _on_body_exited(_body: Node) -> void:
	_armed = true

func _on_body_entered(body: Node) -> void:
	if _sealed or not _armed or not body.is_in_group("player"):
		return
	var doors: Dictionary = RoomDB.ROOMS[GameState.current_room]["doors"]
	if not doors.has(direction):
		return
	_armed = false
	Transition.go_to(doors[direction], direction)
