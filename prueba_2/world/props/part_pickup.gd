extends Area2D

signal collected(part_id: String)

# Parte soltada por un experimento. Si hay hueco compatible libre se equipa sola
# al pasar por encima; si no, se queda en el suelo hasta que el jugador consume
# una de sus seis partes desde el panel corporal de `TAB`.

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

# Caída: la parte salta del cadáver, aterriza y tarda un instante en armarse.
# Sin esa pausa el jugador la absorbe en el mismo frame en que mata al
# experimento y ni se entera de que soltó algo.
const DROP_RISE_TIME := 0.18
const DROP_FALL_TIME := 0.22
const DROP_SQUASH_TIME := 0.08
const DROP_RECOVER_TIME := 0.12
const DROP_ARM_DELAY := 0.25
const DROP_HOP_HEIGHT := 52.0

@export var part_id: String = ""

var _t := 0.0
var _player_inside := false
# Los pickups colocados a mano (recompensa del cuerpo, tests) nacen armados; solo
# `start_drop()` los desarma mientras dura la animación.
var _armed := true

@onready var glow: Polygon2D = $Glow
@onready var light: PointLight2D = $Light
@onready var label: Label = $Label
@onready var hint: Label = $Hint

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = PartsDB.display_name(part_id).to_upper()
	glow.color = _slot_color()
	hint.text = ""

# La llaman los experimentos y el boss al morir, ya con el pickup en el árbol.
func start_drop() -> void:
	_armed = false
	var base_energy: float = light.energy
	glow.position = Vector2.ZERO
	glow.scale = Vector2.ZERO
	light.energy = 0.0
	label.modulate.a = 0.0
	hint.text = ""

	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween.tween_property(glow, "position:y", -DROP_HOP_HEIGHT, DROP_RISE_TIME)
			.set_trans(Tween.TRANS_QUAD)
			.set_ease(Tween.EASE_OUT)
	)
	(
		tween.tween_property(glow, "scale", Vector2(1.15, 1.15), DROP_RISE_TIME)
			.set_trans(Tween.TRANS_BACK)
			.set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(light, "energy", base_energy, DROP_RISE_TIME)
	(
		tween.chain().tween_property(glow, "position:y", 0.0, DROP_FALL_TIME)
			.set_trans(Tween.TRANS_QUAD)
			.set_ease(Tween.EASE_IN)
	)
	(
		tween.chain().tween_property(glow, "scale", Vector2(1.3, 0.7), DROP_SQUASH_TIME)
			.set_trans(Tween.TRANS_QUAD)
			.set_ease(Tween.EASE_OUT)
	)
	(
		tween.chain().tween_property(glow, "scale", Vector2.ONE, DROP_RECOVER_TIME)
			.set_trans(Tween.TRANS_BACK)
			.set_ease(Tween.EASE_OUT)
	)
	tween.chain().tween_property(label, "modulate:a", 1.0, DROP_ARM_DELAY)
	tween.chain().tween_callback(_arm)

func _process(delta: float) -> void:
	# Mientras cae manda el tween: el latido del brillo pisaría su escala.
	if not _armed:
		return

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
		not _armed
		or not _player_inside
		or not event.is_action_pressed("consume")
		or not Inventory.consume_loose_duplicate(part_id)
	):
		return
	collected.emit(part_id)
	get_viewport().set_input_as_handled()
	queue_free()


func _arm() -> void:
	_armed = true
	label.modulate.a = 1.0


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
