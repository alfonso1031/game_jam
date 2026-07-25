extends Area2D

# Proyectil disparado por una parte del slime. Cubre el Aguijón de Ácido, el
# Estilete Óseo, el Lanzaredes, el Puño de Chatarra, el Saco de Viscosidad y el
# Brote de Micelio: lo que cambia entre ellos son los parámetros, no el código.

const Palette := preload("res://core/palette.gd")

const ZoneScene := preload("res://world/props/hazard_zone.tscn")
# La torreta se carga en caliente a propósito: `turret.gd` precarga este mismo
# proyectil para disparar, y con dos `preload` cruzados una de las dos escenas
# se resuelve vacía.
const TURRET_SCENE_PATH := "res://actors/player/abilities/turret.tscn"

var direction := Vector2.RIGHT
var speed := 800.0
var damage: int = 1
var radius := 16.0
var max_range := 700.0
var pierce := false
var knockback := 0.0
var status: String = ""
var status_time := 0.0
var color: Color = Palette.SLIME_CORE
# Charco/nube que deja al terminar (spec `leaves` de la parte).
var leaves: Dictionary = {}
# Torreta que planta al terminar (spec `plants` de la parte).
var plants: Dictionary = {}

var _traveled := 0.0
var _hit: Dictionary = {}

func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	queue_redraw()

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= max_range:
		_burst()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius * 1.35, 0.0, TAU, 20, Color(color, 0.45), 3.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if not body.is_in_group("enemies"):
		# Muro o prop sólido: acá termina el recorrido.
		_burst()
		return
	# Con `pierce` atraviesa, pero no golpea dos veces al mismo enemigo.
	if _hit.has(body.get_instance_id()):
		return
	_hit[body.get_instance_id()] = true
	if damage > 0:
		body.take_damage(damage, global_position, knockback)
	if status != "" and body.has_method("apply_status"):
		body.apply_status(status, status_time)
	if not pierce:
		_burst()

func _burst() -> void:
	if not leaves.is_empty():
		var zone: Node2D = ZoneScene.instantiate()
		zone.affects = zone.AFFECT_ENEMIES
		zone.duration = leaves.get("duration", 3.0)
		zone.radius = leaves.get("radius", 80.0)
		zone.dps = leaves.get("dps", 0.0)
		zone.status = leaves.get("status", "")
		zone.status_time = leaves.get("status_time", 1.0)
		zone.color = color
		zone.position = position
		get_parent().add_child(zone)

	if not plants.is_empty():
		var turret_scene: PackedScene = load(TURRET_SCENE_PATH)
		var turret: Node2D = turret_scene.instantiate()
		turret.duration = plants.get("duration", 4.0)
		turret.interval = plants.get("interval", 0.6)
		turret.damage = plants.get("damage", 1)
		turret.position = position
		get_parent().add_child(turret)

	queue_free()
