extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 01 — Ciempiés de Agujas
# Se acerca en zig-zag rápido y embiste en línea recta. La embestida no sigue al
# jugador: apunta a donde estaba, así que acorrala contra las paredes y es
# esquivable si lees el telegrafiado.

const ZIGZAG_FREQ := 5.0
const ZIGZAG_AMPLITUD := 0.85
const APPROACH_RANGE := 620.0
const WINDUP_TIME := 0.65
const CHARGE_SPEED := 620.0
const CHARGE_TIME := 0.85
const WALL_STUN := 0.9
const REST_TIME := 1.1

enum State {APPROACH, WINDUP, CHARGE, REST}

var _state: int = State.APPROACH
var _timer := 0.0
var _wave := 0.0
var _charge_dir := Vector2.RIGHT

func _on_ready() -> void:
	_wave = randf() * TAU

func _tick_ai(delta: float) -> void:
	_timer -= delta
	match _state:
		State.APPROACH:
			_approach(delta)
		State.WINDUP:
			brake(delta, 12.0)
			if _timer <= 0.0:
				_enter_charge()
		State.CHARGE:
			_advance_charge(delta)
		State.REST:
			brake(delta, 5.0)
			if _timer <= 0.0:
				_state = State.APPROACH

func _approach(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	var to_player := offset.normalized()
	_wave += delta * ZIGZAG_FREQ
	# El zig-zag es una desviación perpendicular al vector hacia el jugador:
	# avanza igual pero nunca en línea recta, que es lo que lo hace molesto.
	var side := Vector2(-to_player.y, to_player.x) * sin(_wave) * ZIGZAG_AMPLITUD
	move_towards(to_player + side, speed_now(), delta, 14.0)

	if offset.length() <= APPROACH_RANGE:
		_state = State.WINDUP
		_timer = WINDUP_TIME
		_charge_dir = to_player

func _enter_charge() -> void:
	_state = State.CHARGE
	_timer = CHARGE_TIME
	facing = _charge_dir

func _advance_charge(delta: float) -> void:
	if has_status(PartsDB.STATUS_ROOT):
		_enter_rest(REST_TIME)
		return
	velocity = _charge_dir * CHARGE_SPEED
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		# Chocar de frente contra un muro lo deja clavado un momento: es la
		# ventana para castigarlo.
		_enter_rest(WALL_STUN)
		return
	if _timer <= 0.0:
		_enter_rest(REST_TIME)

func _enter_rest(time: float) -> void:
	_state = State.REST
	_timer = time
	velocity = Vector2.ZERO
