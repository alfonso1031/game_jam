extends Area2D

# Caída: misma ceremonia que `part_pickup.gd`. La habilidad salta del boss,
# aterriza y solo entonces se puede recoger.
const DROP_RISE_TIME := 0.18
const DROP_FALL_TIME := 0.22
const DROP_SQUASH_TIME := 0.08
const DROP_RECOVER_TIME := 0.12
const DROP_ARM_DELAY := 0.25
const DROP_HOP_HEIGHT := 52.0

@export var ability_id: String = "dash"

var _t := 0.0
var _player_inside := false
var _armed := true

@onready var glow: Polygon2D = $Glow
@onready var light: PointLight2D = $Light
@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = ability_id.to_upper()

# La llama el boss al morir, ya con el pickup en el árbol.
func start_drop() -> void:
	_armed = false
	var base_energy: float = light.energy
	glow.position = Vector2.ZERO
	glow.scale = Vector2.ZERO
	light.energy = 0.0
	label.modulate.a = 0.0

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
	if not _armed:
		return

	_t += delta
	glow.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.14)
	glow.rotation = _t * 0.6

	# Se comprueba cada frame en vez de recoger en `body_entered`: si el jugador ya
	# estaba encima cuando cayó, esa señal saltó mientras seguía desarmado.
	if _player_inside:
		_collect()

func _arm() -> void:
	_armed = true
	label.modulate.a = 1.0

func _collect() -> void:
	_armed = false
	GameState.gain_ability(ability_id)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
