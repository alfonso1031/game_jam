extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 04 — Anguila Voltaica
# Levita de lado a lado mientras acorta distancia y descarga chispas a su
# alrededor. No embiste: la amenaza es que te alcanza rápido, aunque avisa antes
# de soltar la descarga y luego se retira.

const STRAFE_FREQ := 2.4
const STRAFE_AMPLITUD := 1.4
const DISCHARGE_RANGE := 240.0
const DISCHARGE_RADIUS := 250.0
const DISCHARGE_WINDUP := 0.5
const DISCHARGE_COOLDOWN := 2.8
const RETREAT_TIME := 0.8

enum State {STRAFE, DISCHARGE_WINDUP, RETREAT}

var _state: int = State.STRAFE
var _timer := 0.0
var _discharge_cd := 0.0
var _wave := 0.0
var _retreat_dir := Vector2.RIGHT

func _on_ready() -> void:
	_wave = randf() * TAU

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_discharge_cd = max(0.0, _discharge_cd - delta)

	match _state:
		State.STRAFE:
			_strafe(delta)
		State.DISCHARGE_WINDUP:
			brake(delta, 9.0)
			if _timer <= 0.0:
				_discharge()
		State.RETREAT:
			move_towards(_retreat_dir, speed_now() * 0.8, delta, 8.0)
			if _timer <= 0.0:
				_state = State.STRAFE

func _strafe(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	var to_player := offset.normalized()
	_wave += delta * STRAFE_FREQ
	var side := Vector2(-to_player.y, to_player.x) * sin(_wave) * STRAFE_AMPLITUD
	move_towards(to_player * 0.7 + side, speed_now(), delta, 9.0)

	if offset.length() <= DISCHARGE_RANGE and _discharge_cd <= 0.0:
		_state = State.DISCHARGE_WINDUP
		_timer = DISCHARGE_WINDUP

func _discharge() -> void:
	hit_player_area(DISCHARGE_RADIUS, contact_damage, 520.0)
	spawn_zone(position, {
		"duration": 0.4,
		"radius": DISCHARGE_RADIUS,
		"dps": 0.0,
		"color": Palette.SLIME_CORE,
	})
	_discharge_cd = DISCHARGE_COOLDOWN
	# Tras descargar se aparta: no se queda pegada esperando el contraataque.
	_retreat_dir = -player_offset().normalized()
	_state = State.RETREAT
	_timer = RETREAT_TIME
