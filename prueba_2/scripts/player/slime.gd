extends CharacterBody2D

const SPEED := 220.0
const ACCEL := 12.0
const FRICTION := 10.0

const DASH_SPEED := 1200.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 0.8
const INVULN_TIME := 1.0
const KNOCKBACK := 620.0

# Capa 3 = huecos: solo se atraviesan en dash.
const GAP_MASK_BIT := 3

@onready var body: Polygon2D = $Body
@onready var core: Polygon2D = $Body/Core

var breathe_time := 0.0
var _facing := Vector2.RIGHT
var _dash_time := 0.0
var _dash_cd := 0.0
var _invuln := 0.0

func _physics_process(delta: float) -> void:
	_dash_cd = max(0.0, _dash_cd - delta)
	_invuln = max(0.0, _invuln - delta)

	if _dash_time > 0.0:
		_dash_time -= delta
		if _dash_time <= 0.0:
			_end_dash()
		move_and_slide()
		_update_squash(delta)
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	if input_dir != Vector2.ZERO:
		_facing = input_dir

	if Input.is_action_just_pressed("dash") and GameState.has_ability("dash") and _dash_cd <= 0.0:
		_start_dash()
		move_and_slide()
		_update_squash(delta)
		return

	var target_velocity := input_dir * SPEED
	var accel := ACCEL if input_dir != Vector2.ZERO else FRICTION
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-accel * delta))
	move_and_slide()

	_update_squash(delta)

func is_dashing() -> bool:
	return _dash_time > 0.0

func take_damage(amount: int = 1, from: Vector2 = Vector2.ZERO) -> void:
	if _invuln > 0.0:
		return
	_invuln = INVULN_TIME
	GameState.damage(amount)
	if from != Vector2.ZERO:
		velocity = (global_position - from).normalized() * KNOCKBACK

func _start_dash() -> void:
	_dash_time = DASH_TIME
	_dash_cd = DASH_COOLDOWN + DASH_TIME
	_invuln = max(_invuln, DASH_TIME)
	velocity = _facing * DASH_SPEED
	set_collision_mask_value(GAP_MASK_BIT, false)

func _end_dash() -> void:
	set_collision_mask_value(GAP_MASK_BIT, true)
	velocity = velocity.limit_length(SPEED)

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

	core.modulate.a = 1.0 if is_dashing() else 0.6 + sin(breathe_time * 3.0) * 0.2
	# Parpadeo durante los frames de invulnerabilidad.
	modulate.a = 0.45 if _invuln > 0.0 and int(_invuln * 12.0) % 2 == 0 else 1.0
