extends Area2D

# Proyectil genérico de los experimentos. Los parámetros los pone quien lo
# instancia; muere al tocar al jugador, al tocar un muro o al agotar su vida.
# Pertenece al grupo `enemy_projectiles` para que el Ojo Disruptor pueda
# barrerlos de la pantalla.

const Palette := preload("res://core/palette.gd")

var direction := Vector2.RIGHT
var speed := 340.0
var damage: int = 1
var lifetime := 4.0
var radius := 18.0
var color: Color = Palette.WARM_LIGHT
# Estado que deja en el jugador al impactar (la red del Arácnido inmoviliza).
var player_status: String = ""
var player_status_time := 0.0

var _life: float

func _ready() -> void:
	add_to_group("enemy_projectiles")
	_life = lifetime
	body_entered.connect(_on_body_entered)
	# Forma propia por instancia: las SubResource del .tscn se comparten entre
	# instancias, así que tocarle el radio a una se lo tocaría a todas.
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(color, 0.5), 3.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if damage > 0:
			body.take_damage(damage, global_position)
		if player_status != "" and body.has_method("apply_status"):
			body.apply_status(player_status, player_status_time)
	queue_free()
