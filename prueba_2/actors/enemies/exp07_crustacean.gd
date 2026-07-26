extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 07 — Crustáceo Triturador
# Avanza lento, mantiene distancia con el slime y ataca con la tenaza.

const PINCH_RANGE := 150.0
const PINCH_ARC := 50.0
const PINCH_WINDUP := 0.8
const PINCH_COOLDOWN := 2.6
const PINCH_KNOCKBACK := 520.0
const STRAFE_MIX := 0.55
const RECOVER_TIME := 0.6
const PERSONAL_SPACE := 105.0
const RETREAT_SPEED_MULT := 0.8

enum State {ADVANCE, PINCH_WINDUP, RECOVER}

var _state: int = State.ADVANCE
var _timer := 0.0
var _pinch_cd := 0.0
var _strafe_sign := 1.0

func _on_ready() -> void:
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0

# La secuencia ilustrada de cinco fotogramas ocupa exactamente los 0,8 s del
# aviso: el último fotograma se muestra entre 0,64 y 0,8 s. Al vencer el
# temporizador, `_pinch()` aplica el daño una sola vez y `recover` reproduce la
# misma secuencia en reversa durante 0,6 s. Si cambian esas duraciones, también
# deben cambiar las velocidades 6,25 y 8,333333 del SpriteFrames.
func _visual_state() -> StringName:
	match _state:
		State.PINCH_WINDUP:
			return &"pinch_windup"
		State.RECOVER:
			return &"recover"
		_:
			return &"advance"


func _update_sprite() -> void:
	super()
	# La tenaza fue dibujada mirando a la izquierda, al contrario que el resto
	# del arte de enemigos. Solo EXP07 invierte la orientación visual.
	if sprite != null and absf(facing.x) > 0.05:
		sprite.flip_h = facing.x > 0.0


func _tick_ai(delta: float) -> void:
	_timer -= delta
	_pinch_cd = max(0.0, _pinch_cd - delta)

	if _make_space(delta):
		return

	match _state:
		State.ADVANCE:
			_advance(delta)
		State.PINCH_WINDUP:
			brake(delta, 12.0)
			if _timer <= 0.0:
				_pinch()
		State.RECOVER:
			brake(delta, 6.0)
			if _timer <= 0.0:
				_state = State.ADVANCE

func _advance(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	var to_player := offset.normalized()
	# Dentro del alcance mantiene su espacio y espera el próximo ataque sin
	# perseguir al jugador durante el cooldown.
	if offset.length() <= PINCH_RANGE:
		brake(delta, 10.0)
		if _pinch_cd <= 0.0:
			_state = State.PINCH_WINDUP
			_timer = PINCH_WINDUP
		return

	# El desplazamiento lateral es lo que lo hace un muro móvil en vez de un
	# saco de vida: te empuja hacia los bordes de la sala.
	var side := Vector2(-to_player.y, to_player.x) * _strafe_sign * STRAFE_MIX
	move_towards(to_player + side, speed_now(), delta, 3.5)
	# La tenaza siempre mira al jugador mientras avanza.
	facing = to_player


func _make_space(delta: float) -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := player_offset()
	if offset.length() >= PERSONAL_SPACE:
		return false
	var to_player := offset.normalized()
	if to_player.is_zero_approx():
		to_player = facing if not facing.is_zero_approx() else Vector2.RIGHT
	move_towards(-to_player, speed_now() * RETREAT_SPEED_MULT, delta, 12.0)
	facing = to_player
	return true

func _pinch() -> void:
	hit_player_cone(PINCH_RANGE, PINCH_ARC, contact_damage, facing, PINCH_KNOCKBACK)
	_pinch_cd = PINCH_COOLDOWN
	_state = State.RECOVER
	_timer = RECOVER_TIME
	_strafe_sign *= -1.0
