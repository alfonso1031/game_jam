extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 10 — Mutante Parásito
# Se arrastra manteniendo distancia y lanza su tentáculo desde lejos para
# arrastrarte hacia él. Solo no hace gran cosa; puesto detrás de otros
# experimentos te tira encima de ellos.

const PREFERRED_RANGE := 620.0
const RANGE_TOLERANCE := 120.0
const TENTACLE_RANGE := 780.0
const TENTACLE_WIDTH := 46.0
const TENTACLE_WINDUP := 0.9
const TENTACLE_COOLDOWN := 4.2
const TENTACLE_PULL := 1000.0
const TENTACLE_HOLD := 0.35
const RECOVER_TIME := 0.9

enum State {CRAWL, AIM, STRIKE, RECOVER}

var _state: int = State.CRAWL
var _timer := 0.0
var _tentacle_cd := 0.0
var _aim := Vector2.RIGHT
var _tentacle_length := 0.0

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_tentacle_cd = max(0.0, _tentacle_cd - delta)

	match _state:
		State.CRAWL:
			_crawl(delta)
		State.AIM:
			brake(delta, 10.0)
			_aim = player_offset().normalized()
			if _timer <= 0.0:
				_strike()
		State.STRIKE:
			brake(delta, 14.0)
			if _timer <= 0.0:
				_state = State.RECOVER
				_timer = RECOVER_TIME
				_tentacle_length = 0.0
		State.RECOVER:
			brake(delta, 5.0)
			if _timer <= 0.0:
				_state = State.CRAWL
	queue_redraw()

func _crawl(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	var distance := offset.length()
	facing = offset.normalized()

	if distance <= TENTACLE_RANGE and _tentacle_cd <= 0.0:
		_state = State.AIM
		_timer = TENTACLE_WINDUP
		return

	var direction := Vector2.ZERO
	if distance > PREFERRED_RANGE + RANGE_TOLERANCE:
		direction = offset.normalized()
	elif distance < PREFERRED_RANGE - RANGE_TOLERANCE:
		direction = -offset.normalized()
	move_towards(direction, speed_now(), delta, 4.0)

func _strike() -> void:
	_state = State.STRIKE
	_timer = TENTACLE_HOLD
	_tentacle_cd = TENTACLE_COOLDOWN
	_tentacle_length = TENTACLE_RANGE

	if not is_instance_valid(_player):
		return
	var offset := player_offset()
	if offset.length() > TENTACLE_RANGE:
		return
	# Golpea en línea: hay que salirse del carril durante el telegrafiado.
	var along := offset.dot(_aim)
	if along <= 0.0:
		return
	var perpendicular: float = absf(offset.cross(_aim))
	if perpendicular > TENTACLE_WIDTH:
		return

	_tentacle_length = along
	_player.take_damage(contact_damage, global_position)
	# El tirón es hacia el parásito, no hacia afuera: te mete en el peligro.
	if _player.has_method("apply_knockback"):
		_player.apply_knockback(global_position + _aim * (along + 200.0), TENTACLE_PULL)

func _draw() -> void:
	if _tentacle_length <= 0.0:
		return
	var alpha: float = clampf(_timer / TENTACLE_HOLD, 0.0, 1.0)
	draw_line(Vector2.ZERO, _aim * _tentacle_length, Color(Palette.SLIME_BODY, alpha), 10.0)
	draw_circle(_aim * _tentacle_length, 16.0, Color(Palette.WARM_LIGHT, alpha))
