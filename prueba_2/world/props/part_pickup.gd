extends Area2D

signal collected(part_id: String)

# Parte soltada por un experimento. Si hay hueco compatible libre se equipa sola
# al pasar por encima; si no, se queda en el suelo hasta que el jugador consume
# una de sus seis partes desde el panel corporal de `TAB`.

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

@export var part_id: String = ""

var _t := 0.0
var _player_inside := false

@onready var glow: Polygon2D = $Glow
@onready var label: Label = $Label
@onready var hint: Label = $Hint

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = PartsDB.display_name(part_id).to_upper()
	glow.color = _slot_color()
	hint.text = ""

func _process(delta: float) -> void:
	_t += delta
	glow.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.14)
	glow.rotation = _t * 0.6

	if not _player_inside:
		return
	# Reintenta cada frame: liberar un hueco desde el mapa corporal recoge la
	# parte sin obligar al jugador a salir y volver a entrar.
	if Inventory.first_free_slot(part_id) >= 0:
		_collect()
		return

	if Inventory.has_part(part_id):
		hint.text = "F · COMER"
	else:
		hint.text = "CUERPO LLENO · [TAB] COME UNA PARTE"


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _player_inside
		or not event.is_action_pressed("consume")
		or not Inventory.consume_loose_duplicate(part_id)
	):
		return
	collected.emit(part_id)
	get_viewport().set_input_as_handled()
	queue_free()


func _collect() -> void:
	if not Inventory.pick_up(part_id):
		return
	collected.emit(part_id)
	queue_free()

func _slot_color() -> Color:
	match PartsDB.slot_of(part_id):
		PartsDB.SLOT_CABEZA:
			return Palette.WARM_LIGHT
		PartsDB.SLOT_BRAZO:
			return Palette.SLIME_CORE
		PartsDB.SLOT_PIERNA:
			return Palette.SLIME_BODY
		_:
			return Palette.WALL

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		hint.text = ""
