extends Node2D

# Línea instantánea hacia donde mira el slime: Mano de Micelio, Ojo Parásito,
# Ojo Disruptor y el agarre del Tentáculo. Resuelve al nacer y se queda un
# momento dibujada.

const Palette := preload("res://core/palette.gd")

var aim := Vector2.RIGHT
var length := 700.0
var width := 40.0
var damage: int = 0
var status: String = ""
var status_time := 0.0
# Solo afecta al primer enemigo del carril (Mano de Micelio, Tentáculo).
var first_only := false
# Barre los proyectiles enemigos que estén volando dentro del haz.
var clear_projectiles := false
# Fuerza con la que arrastra al enemigo hacia el slime (Tentáculo).
var pull := 0.0
var color: Color = Palette.SLIME_CORE
var show_time := 0.28

var _life := 0.0
var _reach := 0.0

func _ready() -> void:
	_reach = length
	_resolve()

func _process(delta: float) -> void:
	_life += delta
	if _life >= show_time:
		queue_free()
	queue_redraw()

func _resolve() -> void:
	if clear_projectiles:
		for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
			if is_instance_valid(projectile) and _in_beam(projectile.global_position) >= 0.0:
				projectile.queue_free()

	var targets: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var along := _in_beam(enemy.global_position)
		if along < 0.0:
			continue
		targets.append({"enemy": enemy, "along": along})

	if targets.is_empty():
		return
	targets.sort_custom(func(a, b): return a["along"] < b["along"])
	if first_only:
		_reach = targets[0]["along"]
		targets = [targets[0]]

	for entry in targets:
		var enemy = entry["enemy"]
		if damage > 0:
			enemy.take_damage(damage, global_position)
		if status != "" and enemy.has_method("apply_status"):
			enemy.apply_status(status, status_time)
		if pull > 0.0:
			# Tirón hacia el slime: se empuja desde un punto al otro lado.
			enemy.push_away(global_position + aim * (entry["along"] + 200.0), pull)

# Distancia a lo largo del haz, o -1 si el punto queda fuera.
func _in_beam(point: Vector2) -> float:
	var offset := point - global_position
	var along := offset.dot(aim)
	if along < 0.0 or along > length:
		return -1.0
	if absf(offset.cross(aim)) > width * 0.5:
		return -1.0
	return along

func _draw() -> void:
	var alpha: float = (1.0 - clampf(_life / show_time, 0.0, 1.0)) * 0.75
	draw_line(Vector2.ZERO, aim * _reach, Color(color, alpha), width * 0.35)
	draw_line(Vector2.ZERO, aim * _reach, Color(color, alpha * 0.4), width)
	draw_circle(aim * _reach, width * 0.3, Color(color, alpha))
