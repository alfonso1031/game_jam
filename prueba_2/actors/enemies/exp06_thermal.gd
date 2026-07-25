extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 06 — Bestia Térmica
# Agresiva e incesante: persigue sin descanso y golpea el suelo. No tiene fase
# pasiva, así que la única forma de gestionarla es el control de espacio.

const SLAM_RANGE := 200.0
const SLAM_WINDUP := 0.75
const SLAM_RADIUS := 240.0
const SLAM_COOLDOWN := 2.4
const SLAM_KNOCKBACK := 560.0
const RECOVER_TIME := 0.9

enum State {CHASE, SLAM_WINDUP, RECOVER}

var _state: int = State.CHASE
var _timer := 0.0
var _slam_cd := 0.0

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_slam_cd = max(0.0, _slam_cd - delta)

	match _state:
		State.CHASE:
			_chase(delta)
		State.SLAM_WINDUP:
			brake(delta, 16.0)
			if _timer <= 0.0:
				_slam()
		State.RECOVER:
			brake(delta, 7.0)
			if _timer <= 0.0:
				_state = State.CHASE

func _chase(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	# Acelera al perseguir: cuanto más lejos estás, más rápido cierra el hueco.
	var urgency: float = clampf(offset.length() / 700.0, 0.7, 1.35)
	move_towards(offset.normalized(), speed_now() * urgency, delta, 8.0)

	if offset.length() <= SLAM_RANGE and _slam_cd <= 0.0:
		_state = State.SLAM_WINDUP
		_timer = SLAM_WINDUP

func _slam() -> void:
	hit_player_area(SLAM_RADIUS, contact_damage, SLAM_KNOCKBACK)
	# El suelo queda ardiendo un instante: no basta con aguantar el golpe.
	spawn_zone(position, {
		"duration": 1.2,
		"radius": SLAM_RADIUS * 0.8,
		"dps": 2.0,
		"color": Palette.WARM_LIGHT,
	})
	_slam_cd = SLAM_COOLDOWN
	_state = State.RECOVER
	_timer = RECOVER_TIME
