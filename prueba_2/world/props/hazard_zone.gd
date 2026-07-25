extends Node2D

# Zona de suelo con efecto continuo: charco de ácido, nube de esporas, micelio,
# rastro de chispas... La usan tanto los experimentos como las partes del slime,
# solo cambia a quién afecta.
#
# No usa Area2D: con `affects` mixto y radios que cambian en caliente sale más
# barato comprobar distancias contra el jugador y el grupo `enemies`.

const Palette := preload("res://core/palette.gd")

const AFFECT_PLAYER := "player"
const AFFECT_ENEMIES := "enemies"

const TICK := 0.5

var affects: String = AFFECT_ENEMIES
var duration := 3.0
var radius := 80.0
# Daño por segundo. Se aplica a tramos de TICK segundos redondeando hacia
# arriba, así una zona de dps 2 pega 1 cada medio segundo.
var dps := 0.0
var status: String = ""
var status_time := 0.0
var color: Color = Palette.SLIME_BODY
# Fundido de entrada/salida, solo estético.
var fade := 0.35

var _life: float
var _tick := 0.0
var _pulse := 0.0

func _ready() -> void:
	add_to_group("hazard_zones")
	_life = duration
	z_index = -1
	queue_redraw()

func _physics_process(delta: float) -> void:
	_life -= delta
	_pulse += delta
	if _life <= 0.0:
		queue_free()
		return

	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_affect()
	queue_redraw()

func _affect() -> void:
	var damage: int = int(ceil(dps * TICK))
	if affects == AFFECT_PLAYER:
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.global_position.distance_to(global_position) <= radius:
			# La Placa de Cadera vuelve inmune a los efectos del suelo.
			if not (player.has_method("is_floor_immune") and player.is_floor_immune()):
				if damage > 0:
					player.take_damage(damage, global_position)
				if status != "" and player.has_method("apply_status"):
					player.apply_status(status, status_time)
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		if damage > 0:
			enemy.take_damage(damage, global_position)
		if status != "" and enemy.has_method("apply_status"):
			enemy.apply_status(status, status_time)

func _draw() -> void:
	var alpha: float = clampf(min(_life, fade) / fade, 0.0, 1.0) * 0.45
	var wobble: float = 1.0 + sin(_pulse * 3.0) * 0.03
	draw_circle(Vector2.ZERO, radius * wobble, Color(color, alpha))
	draw_arc(Vector2.ZERO, radius * wobble, 0.0, TAU, 32, Color(color, alpha + 0.25), 3.0)
