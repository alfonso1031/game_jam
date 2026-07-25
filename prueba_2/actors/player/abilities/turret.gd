extends Node2D

# Flor fúngica del Brote de Micelio: se queda clavada donde cayó la semilla y
# dispara sola al enemigo más cercano mientras dura.

const Palette := preload("res://core/palette.gd")
const ProjectileScene := preload("res://actors/player/abilities/player_projectile.tscn")

var duration := 4.0
var interval := 0.6
var damage: int = 1
var color: Color = Palette.SLIME_BODY

var _life: float
var _cooldown := 0.0
var _pulse := 0.0

func _ready() -> void:
	_life = duration
	queue_redraw()

func _process(delta: float) -> void:
	_life -= delta
	_pulse += delta
	if _life <= 0.0:
		queue_free()
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = interval
		_shoot()
	queue_redraw()

func _shoot() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var projectile: Node2D = ProjectileScene.instantiate()
	projectile.direction = (target.global_position - global_position).normalized()
	projectile.speed = 720.0
	projectile.damage = damage
	projectile.radius = 12.0
	projectile.max_range = 900.0
	projectile.color = color
	projectile.position = position
	get_parent().add_child(projectile)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _draw() -> void:
	var wobble: float = 1.0 + sin(_pulse * 5.0) * 0.12
	draw_circle(Vector2.ZERO, 22.0 * wobble, Color(color, 0.85))
	draw_arc(Vector2.ZERO, 30.0 * wobble, 0.0, TAU, 20, Color(Palette.WARM_LIGHT, 0.6), 3.0)
