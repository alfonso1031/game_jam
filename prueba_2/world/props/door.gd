extends Area2D

# Las jambas en embudo están dibujadas mirando al este; la escena se rota para
# que apunten hacia afuera del lado que corresponda.
const OUTWARD_ROTATION := {"E": 0.0, "O": PI, "N": -PI / 2.0, "S": PI / 2.0}

@export var direction: String = "E"

# Empieza desarmada: si la sala carga con el jugador encima de la puerta
# (viene de la puerta equivalente de la sala anterior) no debe dispararse.
var _armed := false
var _sealed := false

@onready var plate: ColorRect = $Plate

func _ready() -> void:
	rotation = OUTWARD_ROTATION.get(direction, 0.0)
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

# El arte de fondo ya dibuja el hueco de la puerta; acá solo se marca el
# bloqueo. Abierta no muestra nada — sellada, una línea blanca cruzando el
# paso. El diseño final del bloqueo lo define el arte más adelante.
func _apply_seal_visual() -> void:
	# set_sealed() puede llegar desde el boss antes de que corra este _ready.
	if plate == null:
		return
	plate.visible = _sealed

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
