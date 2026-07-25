extends Node2D

# Pulso de 360° centrado en el slime: Cola de Látigo, Glándula Eléctrica, Núcleo
# Imán y la explosión del Saco de Esporas. Resuelve una sola vez al nacer; la
# onda que se expande es solo lectura visual.

const Palette := preload("res://core/palette.gd")

var radius := 220.0
var damage: int = 0
var knockback := 0.0
var status: String = ""
var status_time := 0.0
var break_shield := false
var color: Color = Palette.SLIME_CORE
var show_time := 0.32
# Retardo antes de resolver (el Saco de Esporas explota tras 1 segundo).
var delay := 0.0

var _life := 0.0
var _resolved := false

func _ready() -> void:
	if delay <= 0.0:
		_resolve()

func _process(delta: float) -> void:
	_life += delta
	if not _resolved and _life >= delay:
		_resolve()
	if _resolved and _life >= delay + show_time:
		queue_free()
	queue_redraw()

func _resolve() -> void:
	_resolved = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		if damage > 0:
			enemy.take_damage(damage, global_position, knockback, break_shield)
		elif knockback > 0.0:
			enemy.push_away(global_position, knockback)
		if status != "" and enemy.has_method("apply_status"):
			enemy.apply_status(status, status_time)

func _draw() -> void:
	if not _resolved:
		# Fase de aviso: círculo que se llena hasta el momento de estallar.
		var charge: float = clampf(_life / max(delay, 0.001), 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * charge, 0.0, TAU, 32, Color(color, 0.5), 3.0)
		draw_circle(Vector2.ZERO, 14.0, Color(color, 0.6))
		return
	var progress: float = clampf((_life - delay) / show_time, 0.0, 1.0)
	var alpha: float = (1.0 - progress) * 0.6
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 40, Color(color, alpha), 8.0)
	draw_circle(Vector2.ZERO, radius * progress, Color(color, alpha * 0.25))
