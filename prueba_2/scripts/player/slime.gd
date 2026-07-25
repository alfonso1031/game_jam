extends CharacterBody2D

const SPEED := 220.0
const ACCEL := 12.0
const FRICTION := 10.0

@onready var body: Polygon2D = $Body
@onready var core: Polygon2D = $Body/Core

var breathe_time := 0.0

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	var target_velocity := input_dir * SPEED
	var accel := ACCEL if input_dir != Vector2.ZERO else FRICTION
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-accel * delta))
	move_and_slide()

	_update_squash(delta)

func _update_squash(delta: float) -> void:
	if velocity.length() > 5.0:
		var stretch: float = clamp(velocity.length() / SPEED, 0.0, 1.0)
		body.rotation = lerp_angle(body.rotation, velocity.angle(), 0.2)
		body.scale = body.scale.lerp(Vector2(1.0 + stretch * 0.25, 1.0 - stretch * 0.15), 0.25)
	else:
		breathe_time += delta
		var breathe: float = sin(breathe_time * 2.0) * 0.04
		body.scale = body.scale.lerp(Vector2(1.0 + breathe, 1.0 - breathe), 0.2)
		body.rotation = lerp_angle(body.rotation, 0.0, 0.1)

	core.modulate.a = 0.6 + sin(breathe_time * 3.0) * 0.2
