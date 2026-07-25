extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 02 — Arácnido Blindado
# Lento y pesado. Mantiene distancia para escupir proyectiles pegajosos y, si le
# entras al cuerpo, aplasta en área. Castiga tanto quedarse lejos parado como
# pegarse sin pensar.

const PREFERRED_RANGE := 520.0
const RANGE_TOLERANCE := 110.0
const SLAM_RANGE := 220.0
const SHOOT_INTERVAL := 3.2
const SHOOT_WINDUP := 0.75
const SLAM_WINDUP := 0.9
const SLAM_RADIUS := 220.0
const SLAM_COOLDOWN := 3.0

enum State {REPOSITION, SHOOT_WINDUP, SLAM_WINDUP, RECOVER}

var _state: int = State.REPOSITION
var _timer := 0.0
var _shoot_cd := 0.0
var _slam_cd := 0.0
var _aim := Vector2.RIGHT

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_shoot_cd = max(0.0, _shoot_cd - delta)
	_slam_cd = max(0.0, _slam_cd - delta)

	match _state:
		State.REPOSITION:
			_reposition(delta)
		State.SHOOT_WINDUP:
			brake(delta, 10.0)
			if _timer <= 0.0:
				_fire_web()
		State.SLAM_WINDUP:
			brake(delta, 14.0)
			if _timer <= 0.0:
				_slam()
		State.RECOVER:
			brake(delta, 6.0)
			if _timer <= 0.0:
				_state = State.REPOSITION

func _reposition(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	var distance := offset.length()
	facing = offset.normalized()

	if distance <= SLAM_RANGE and _slam_cd <= 0.0:
		_state = State.SLAM_WINDUP
		_timer = SLAM_WINDUP
		return
	if _shoot_cd <= 0.0 and distance > SLAM_RANGE:
		_state = State.SHOOT_WINDUP
		_timer = SHOOT_WINDUP
		_aim = offset.normalized()
		return

	# Fuera de la banda cómoda se acerca o se aleja; dentro, orbita despacio.
	var direction := Vector2.ZERO
	if distance > PREFERRED_RANGE + RANGE_TOLERANCE:
		direction = offset.normalized()
	elif distance < PREFERRED_RANGE - RANGE_TOLERANCE:
		direction = -offset.normalized()
	else:
		direction = Vector2(-offset.y, offset.x).normalized() * 0.6
	move_towards(direction, speed_now(), delta, 6.0)

func _fire_web() -> void:
	fire_projectile(_aim, {
		"speed": 420.0,
		"damage": 1,
		"radius": 26.0,
		"status": PartsDB.STATUS_ROOT,
		"status_time": 1.2,
		"color": Palette.SLIME_BODY,
	})
	_shoot_cd = SHOOT_INTERVAL
	_state = State.RECOVER
	_timer = 0.4

func _slam() -> void:
	hit_player_area(SLAM_RADIUS, contact_damage, 700.0)
	spawn_zone(position, {
		"duration": 0.35,
		"radius": SLAM_RADIUS,
		"dps": 0.0,
		"color": Palette.WALL,
	})
	_slam_cd = SLAM_COOLDOWN
	_state = State.RECOVER
	_timer = 0.7
