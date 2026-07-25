extends StaticBody2D

# Obstáculo rígido temporal: Placa de Hueso y Muro Mecánico. Está en la capa
# `world`, así que frena a los enemigos y corta los proyectiles enemigos sin
# lógica extra — es un muro de verdad mientras dura.

const Palette := preload("res://core/palette.gd")

var duration := 6.0
var size := Vector2(120, 40)
var color: Color = Palette.WALL

var _life: float

@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_life = duration
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	queue_redraw()

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# Parpadea el último segundo para avisar de que se va.
	var alpha: float = 0.9 if _life > 1.0 else (0.35 + 0.55 * absf(sin(_life * 14.0)))
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(color, alpha), true)
	draw_rect(rect, Color(Palette.WARM_LIGHT, alpha), false, 3.0)
