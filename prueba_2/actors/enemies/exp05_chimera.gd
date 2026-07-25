extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 05 — Quimera Alada
# Vuela en órbita, se detiene en el aire para marcar el objetivo y se lanza en
# picado. El picado va a la posición marcada, no a la actual: la pausa es la
# señal para moverse.

const ORBIT_RADIUS := 380.0
const ORBIT_SPEED := 1.5
const HOVER_TIME := 1.05
const DIVE_SPEED := 720.0
const DIVE_TIME := 0.75
const RECOVER_TIME := 1.4
const ORBIT_TIME := 2.2

enum State {ORBIT, HOVER, DIVE, RECOVER}

var _state: int = State.ORBIT
var _timer := ORBIT_TIME
var _angle := 0.0
var _dive_target := Vector2.ZERO

func _on_ready() -> void:
	_angle = randf() * TAU
	# Vuela: los huecos del suelo no la frenan.
	set_collision_mask_value(Layers.GAP_BIT, false)

func _tick_ai(delta: float) -> void:
	_timer -= delta
	match _state:
		State.ORBIT:
			_orbit(delta)
		State.HOVER:
			brake(delta, 14.0)
			if _timer <= 0.0:
				_enter_dive()
		State.DIVE:
			_advance_dive(delta)
		State.RECOVER:
			brake(delta, 5.0)
			if _timer <= 0.0:
				_state = State.ORBIT
				_timer = ORBIT_TIME

func _orbit(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	_angle += delta * ORBIT_SPEED
	var target := player_position() + Vector2.RIGHT.rotated(_angle) * ORBIT_RADIUS
	move_towards(target - global_position, speed_now(), delta, 5.0)
	facing = (player_position() - global_position).normalized()
	if _timer <= 0.0:
		_state = State.HOVER
		_timer = HOVER_TIME

func _enter_dive() -> void:
	# Se congela el destino ahora: esquivar el picado es cuestión de leer la pausa.
	_dive_target = player_position()
	facing = (_dive_target - global_position).normalized()
	_state = State.DIVE
	_timer = DIVE_TIME

func _advance_dive(delta: float) -> void:
	velocity = facing * DIVE_SPEED
	var collision := move_and_collide(velocity * delta)
	var arrived: bool = global_position.distance_to(_dive_target) < 40.0
	if collision != null or arrived or _timer <= 0.0:
		_state = State.RECOVER
		_timer = RECOVER_TIME
		velocity = Vector2.ZERO
