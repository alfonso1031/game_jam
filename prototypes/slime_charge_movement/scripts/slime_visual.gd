class_name SlimeVisual
extends Node2D

const BODY_COLOR := Color("#4de3a2")
const BODY_DARK := Color("#1e9d78")
const HIGHLIGHT_COLOR := Color(0.78, 1.0, 0.9, 0.75)
const EYE_COLOR := Color("#eafff7")
const PUPIL_COLOR := Color("#123037")
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.28)

var facing_direction := Vector2.DOWN
var impact_tween: Tween


static func feedback_scale(
	state: int,
	power: float,
	direction: Vector2 = Vector2.DOWN
) -> Vector2:
	var vertical_axis := absf(direction.y) >= absf(direction.x)
	var base_scale := Vector2.ONE
	match state:
		1:
			base_scale = Vector2(
				1.0 + clampf(power, 0.0, 1.0) * 0.12,
				1.0 - clampf(power, 0.0, 1.0) * 0.18
			)
		2:
			base_scale = Vector2(0.78, 1.28)

	if vertical_axis:
		return base_scale
	return Vector2(base_scale.y, base_scale.x)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 34.0), 0.0, Vector2(1.2, 0.38))
	draw_circle(Vector2.ZERO, 48.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(Vector2(0.0, 4.0), 50.0, BODY_DARK)
	draw_circle(Vector2(0.0, -2.0), 47.0, BODY_COLOR)
	draw_circle(Vector2(-16.0, -23.0), 13.0, HIGHLIGHT_COLOR)

	var pupil_offset := facing_direction.normalized() * 5.0
	_draw_eye(Vector2(-18.0, -4.0), pupil_offset)
	_draw_eye(Vector2(18.0, -4.0), pupil_offset)
	draw_arc(
		Vector2(0.0, 17.0),
		12.0,
		0.15,
		PI - 0.15,
		12,
		PUPIL_COLOR,
		4.0
	)


func set_movement_feedback(state: int, direction: Vector2, power: float) -> void:
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		queue_redraw()

	if is_instance_valid(impact_tween) and impact_tween.is_running():
		return

	scale = feedback_scale(state, power, facing_direction)
	if state == 1:
		rotation = 0.0
		position = -facing_direction * power * 10.0
	elif state == 2:
		rotation = 0.0
		position = Vector2.ZERO
	else:
		rotation = 0.0
		position = Vector2.ZERO


func play_impact(direction: Vector2, collided: bool) -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(impact_tween):
		impact_tween.kill()

	facing_direction = direction.normalized()
	var impact_scale := Vector2(1.32, 0.68) if collided else Vector2(1.14, 0.86)
	if absf(facing_direction.x) > absf(facing_direction.y):
		impact_scale = Vector2(impact_scale.y, impact_scale.x)
	rotation = 0.0
	impact_tween = create_tween().set_parallel(true)
	impact_tween.set_trans(Tween.TRANS_BACK)
	impact_tween.set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(self, "scale", impact_scale, 0.06)
	impact_tween.tween_property(self, "position", facing_direction * 8.0, 0.06)
	impact_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.12)
	impact_tween.parallel().tween_property(self, "position", Vector2.ZERO, 0.12)
	impact_tween.parallel().tween_property(self, "rotation", 0.0, 0.12)


func _draw_eye(center: Vector2, pupil_offset: Vector2) -> void:
	draw_circle(center, 12.0, EYE_COLOR)
	draw_circle(center + pupil_offset, 5.5, PUPIL_COLOR)
