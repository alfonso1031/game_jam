class_name SlimePlayer
extends CharacterBody2D

const ChargeMotionMath = preload("res://scripts/charge_motion.gd")

enum MovementState {
	IDLE,
	CHARGING,
	LAUNCHING,
	RECOVERING,
}

@export_category("Charge")
@export var max_charge_time := ChargeMotionMath.MAX_CHARGE_TIME
@export var minimum_distance := ChargeMotionMath.MINIMUM_DISTANCE
@export var maximum_distance := ChargeMotionMath.MAXIMUM_DISTANCE

@export_category("Launch")
@export var launch_speed := ChargeMotionMath.LAUNCH_SPEED
@export var recovery_time := ChargeMotionMath.RECOVERY_TIME

var current_state := MovementState.IDLE
var charge_time := 0.0
var charge_direction := Vector2.DOWN
var remaining_distance := 0.0
var recovery_remaining := 0.0

@onready var visual: Node2D = get_node_or_null("Visual")
@onready var charge_bar: Node2D = get_node_or_null("ChargeBar")
@onready var slime_audio: Node = get_node_or_null("SlimeAudio")


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	match current_state:
		MovementState.IDLE:
			if not input_direction.is_zero_approx():
				begin_charge(input_direction)
		MovementState.CHARGING:
			if not _has_directional_input():
				release_charge()
			else:
				update_charge(input_direction, delta)
		MovementState.LAUNCHING:
			_advance_launch(delta)
		MovementState.RECOVERING:
			_advance_recovery(delta)


func begin_charge(direction: Vector2) -> void:
	var safe_direction := ChargeMotionMath.safe_direction(direction)
	if safe_direction.is_zero_approx():
		return

	current_state = MovementState.CHARGING
	charge_time = 0.0
	charge_direction = safe_direction
	if slime_audio != null:
		slime_audio.begin_charge()
	_sync_feedback()


func update_charge(direction: Vector2, delta: float) -> void:
	if current_state != MovementState.CHARGING:
		return

	var safe_direction := ChargeMotionMath.safe_direction(direction)
	if safe_direction.is_zero_approx():
		return

	charge_direction = safe_direction
	charge_time = minf(charge_time + delta, max_charge_time)
	if slime_audio != null:
		slime_audio.update_charge(get_charge_power())
	_sync_feedback()


func release_charge() -> void:
	if current_state != MovementState.CHARGING:
		return

	remaining_distance = ChargeMotionMath.launch_distance(
		get_charge_power(),
		minimum_distance,
		maximum_distance
	)
	current_state = MovementState.LAUNCHING
	if slime_audio != null:
		slime_audio.launch()
	_sync_feedback()


func get_charge_power() -> float:
	return ChargeMotionMath.normalized_power(charge_time, max_charge_time)


func _advance_launch(delta: float) -> void:
	var requested_distance := minf(launch_speed * delta, remaining_distance)
	velocity = charge_direction * launch_speed
	var collision := move_and_collide(charge_direction * requested_distance)
	remaining_distance -= requested_distance

	if collision != null or remaining_distance <= 0.001:
		_begin_recovery(collision != null)


func _begin_recovery(collided: bool) -> void:
	velocity = Vector2.ZERO
	remaining_distance = 0.0
	recovery_remaining = recovery_time
	current_state = MovementState.RECOVERING

	_sync_feedback()
	if slime_audio != null:
		if collided:
			slime_audio.impact()
		else:
			slime_audio.recover()
	if visual != null and visual.has_method("play_impact"):
		visual.play_impact(charge_direction, collided)


func _advance_recovery(delta: float) -> void:
	recovery_remaining -= delta
	if recovery_remaining > 0.0:
		return

	current_state = MovementState.IDLE
	charge_time = 0.0
	_sync_feedback()


func _has_directional_input() -> bool:
	return (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	)


func _sync_feedback() -> void:
	if charge_bar != null and charge_bar.has_method("set_charge"):
		charge_bar.set_charge(
			get_charge_power(),
			current_state == MovementState.CHARGING
		)
	if visual != null and visual.has_method("set_movement_feedback"):
		visual.set_movement_feedback(
			current_state,
			charge_direction,
			get_charge_power()
		)
