extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 03 — Saurio Escamado
# Camina a paso constante hacia el jugador. Es ciego: solo reacciona con el
# coletazo cuando lo rodeas, así que atacarlo de frente es lo seguro y flanquearlo
# el error. Invierte la intuición del resto de experimentos.

const TAIL_RANGE := 260.0
# Solo late el coletazo si el jugador está fuera del cono frontal.
const FRONT_CONE_DEG := 90.0
const TAIL_WINDUP := 0.5
const TAIL_ARC := 300.0
const TAIL_COOLDOWN := 2.4
const TAIL_KNOCKBACK := 480.0

enum State {WALK, TAIL_WINDUP, RECOVER}

var _state: int = State.WALK
var _timer := 0.0
var _tail_cd := 0.0

# El aviso son tres poses en los 0,5 s de `TAIL_WINDUP` a 6 FPS: la cola extendida
# aparece a 0,333 s y sigue en pantalla cuando `_swipe()` resuelve el cono. La
# recuperación devuelve a la marcha dentro de los 0,55 s del estado.
func _visual_state() -> StringName:
	match _state:
		State.TAIL_WINDUP:
			return &"tail_windup"
		State.RECOVER:
			return &"recover"
		_:
			return &"walk"


func _tick_ai(delta: float) -> void:
	_timer -= delta
	_tail_cd = max(0.0, _tail_cd - delta)

	match _state:
		State.WALK:
			_walk(delta)
		State.TAIL_WINDUP:
			brake(delta, 12.0)
			if _timer <= 0.0:
				_swipe()
		State.RECOVER:
			brake(delta, 8.0)
			if _timer <= 0.0:
				_state = State.WALK

func _walk(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	if offset.length() <= TAIL_RANGE and _tail_cd <= 0.0 and _is_flanked(offset):
		_state = State.TAIL_WINDUP
		_timer = TAIL_WINDUP
		return
	# Paso constante: nada de acelerones, la amenaza es la presión continua.
	move_towards(offset.normalized(), speed_now(), delta, 4.0)

func _is_flanked(offset: Vector2) -> bool:
	return offset.normalized().dot(facing) < cos(deg_to_rad(FRONT_CONE_DEG * 0.5))

func _swipe() -> void:
	# El barrido es casi circular: si te pilla al lado o detrás, te saca de ahí.
	hit_player_cone(TAIL_RANGE, TAIL_ARC, contact_damage, -facing, TAIL_KNOCKBACK)
	spawn_zone(position, {
		"duration": 0.3,
		"radius": TAIL_RANGE,
		"dps": 0.0,
		"color": Palette.WALL,
	})
	_tail_cd = TAIL_COOLDOWN
	_state = State.RECOVER
	_timer = 0.55
