extends Area2D

const Palette := preload("res://scripts/core/palette.gd")

@export var direction: String = "E"

# Empieza desarmada: si la sala carga con el jugador encima de la puerta
# (viene de la puerta equivalente de la sala anterior) no debe dispararse.
var _armed := false
var _sealed := false

@onready var plate: ColorRect = $Plate

func _ready() -> void:
	body_exited.connect(_on_body_exited)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_armed = get_overlapping_bodies().is_empty()

func set_sealed(value: bool) -> void:
	_sealed = value
	plate.color = Color(Palette.WARM_LIGHT, 0.55) if value else Color(Palette.SLIME_CORE, 0.5)

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
