extends Node2D

# Golpe instantáneo en arco frontal. Cubre desde la Mandíbula Serrada hasta el
# Bulbo de Calor: `hits` e `interval` convierten el mismo arco en una ráfaga
# sostenida sin escribir un actor nuevo.
#
# La resolución es geométrica contra el grupo `enemies` en vez de un Area2D:
# el arco existe un instante y no hay que esperar a que el motor reporte
# solapamientos.

const Palette := preload("res://core/palette.gd")

var aim := Vector2.RIGHT
var range_px := 150.0
var arc_deg := 60.0
# Apertura interior vacía: convierte el cono en dos latigazos en V (Cola Doble).
var hollow_deg := 0.0
var damage: int = 1
var knockback := 0.0
var status: String = ""
var status_time := 0.0
var break_shield := false
var hits: int = 1
var interval := 0.15
var color: Color = Palette.SLIME_CORE

var _remaining: int
var _timer := 0.0
var _flash := 0.0

func _ready() -> void:
	_remaining = hits
	_strike()

func _process(delta: float) -> void:
	_flash = max(0.0, _flash - delta)
	queue_redraw()
	if _remaining <= 0:
		if _flash <= 0.0:
			queue_free()
		return
	_timer -= delta
	if _timer <= 0.0:
		_strike()

func _strike() -> void:
	_remaining -= 1
	_timer = interval
	_flash = min(interval, 0.12)

	var half_outer := cos(deg_to_rad(arc_deg * 0.5))
	var half_inner := cos(deg_to_rad(hollow_deg * 0.5))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > range_px:
			continue
		var alignment: float = offset.normalized().dot(aim)
		if alignment < half_outer:
			continue
		# El hueco central de la V: demasiado alineado al frente no entra.
		if hollow_deg > 0.0 and alignment > half_inner:
			continue
		enemy.take_damage(damage, global_position, knockback, break_shield)
		if status != "" and enemy.has_method("apply_status"):
			enemy.apply_status(status, status_time)

func _draw() -> void:
	if _flash <= 0.0:
		return
	var alpha: float = clampf(_flash / 0.12, 0.0, 1.0) * 0.55
	var base := aim.angle()
	var half := deg_to_rad(arc_deg * 0.5)
	var points: PackedVector2Array = [Vector2.ZERO]
	for i in range(17):
		var angle: float = base - half + (half * 2.0) * float(i) / 16.0
		points.append(Vector2.RIGHT.rotated(angle) * range_px)
	draw_colored_polygon(points, Color(color, alpha))
	draw_arc(Vector2.ZERO, range_px, base - half, base + half, 24, Color(color, alpha + 0.3), 4.0)
