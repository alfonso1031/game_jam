extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 08 — Cuerpo Fúngico
# Camina despacio y suelta nubes tóxicas cada pocos segundos. Es inofensivo de
# uno en uno; lo peligroso es que va llenando la sala de zonas que no se pueden
# cruzar, así que hay que matarlo pronto o quedarte sin espacio.

const CLOUD_INTERVAL := 4.5
const CLOUD_DURATION := 3.2
const CLOUD_RADIUS := 160.0
const CLOUD_DPS := 1.0
const RELEASE_WINDUP := 0.6

enum State {WALK, RELEASE}

var _state: int = State.WALK
var _timer := 0.0
var _cloud_cd := 0.0

func _on_ready() -> void:
	# Escalona el primer soplo para que un grupo no suelte todo a la vez.
	_cloud_cd = randf() * CLOUD_INTERVAL

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_cloud_cd = max(0.0, _cloud_cd - delta)

	match _state:
		State.WALK:
			_walk(delta)
		State.RELEASE:
			brake(delta, 10.0)
			if _timer <= 0.0:
				_release()

func _walk(delta: float) -> void:
	if sees_player():
		move_towards(player_offset().normalized(), speed_now(), delta, 3.0)
	else:
		brake(delta)

	if _cloud_cd <= 0.0:
		_state = State.RELEASE
		_timer = RELEASE_WINDUP

func _release() -> void:
	spawn_zone(position, {
		"duration": CLOUD_DURATION,
		"radius": CLOUD_RADIUS,
		"dps": CLOUD_DPS,
		"status": PartsDB.STATUS_SLOW,
		"status_time": 1.0,
		"color": Palette.SLIME_BODY,
	})
	_cloud_cd = CLOUD_INTERVAL
	_state = State.WALK
