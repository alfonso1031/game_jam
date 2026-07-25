extends "res://actors/enemies/enemy_base.gd"

# EXPERIMENTO 09 — Gólem de Metal Sólido
# Avanza a pasos pesados que hacen temblar el suelo y su embestida es imparable:
# durante la carga ignora el aturdimiento. Contra él el control no sirve, solo
# el espacio.

const STEP_INTERVAL := 1.6
const TREMOR_RADIUS := 230.0
const TREMOR_KNOCKBACK := 260.0
const CHARGE_RANGE := 900.0
const CHARGE_WINDUP := 1.3
const CHARGE_SPEED := 560.0
const CHARGE_TIME := 1.6
const CHARGE_COOLDOWN := 4.2
const WALL_STUN := 2.0
const RECOVER_TIME := 0.8

enum State {WALK, CHARGE_WINDUP, CHARGE, RECOVER}

var _state: int = State.WALK
var _timer := 0.0
var _step_cd := STEP_INTERVAL
var _charge_cd := 0.0
var _charge_dir := Vector2.RIGHT

func _tick_ai(delta: float) -> void:
	_timer -= delta
	_charge_cd = max(0.0, _charge_cd - delta)
	_tick_steps(delta)

	match _state:
		State.WALK:
			_walk(delta)
		State.CHARGE_WINDUP:
			brake(delta, 10.0)
			if _timer <= 0.0:
				_enter_charge()
		State.CHARGE:
			_advance_charge(delta)
		State.RECOVER:
			brake(delta, 4.0)
			if _timer <= 0.0:
				_state = State.WALK

# Durante la embestida no hay forma de pararlo: es su identidad mecánica.
func _ignores_stun() -> bool:
	return _state == State.CHARGE

func _tick_steps(delta: float) -> void:
	if _state == State.CHARGE:
		return
	_step_cd -= delta
	if _step_cd > 0.0:
		return
	_step_cd = STEP_INTERVAL
	# El temblor no hace daño: solo desestabiliza y avisa de dónde está.
	if is_instance_valid(_player) and player_offset().length() <= TREMOR_RADIUS:
		if _player.has_method("apply_knockback"):
			_player.apply_knockback(global_position, TREMOR_KNOCKBACK)
	spawn_zone(position, {
		"duration": 0.3,
		"radius": TREMOR_RADIUS,
		"dps": 0.0,
		"color": Palette.WALL,
	})

func _walk(delta: float) -> void:
	if not sees_player():
		brake(delta)
		return
	var offset := player_offset()
	move_towards(offset.normalized(), speed_now(), delta, 2.5)
	if offset.length() <= CHARGE_RANGE and _charge_cd <= 0.0:
		_state = State.CHARGE_WINDUP
		_timer = CHARGE_WINDUP
		_charge_dir = offset.normalized()

func _enter_charge() -> void:
	_state = State.CHARGE
	_timer = CHARGE_TIME
	facing = _charge_dir

func _advance_charge(delta: float) -> void:
	velocity = _charge_dir * CHARGE_SPEED
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		# Estrellarse contra el muro es la única forma de pararlo, y lo deja
		# expuesto un buen rato.
		spawn_zone(position, {
			"duration": 0.4,
			"radius": TREMOR_RADIUS * 1.3,
			"dps": 0.0,
			"color": Palette.WARM_LIGHT,
		})
		_enter_recover(WALL_STUN)
		return
	if _timer <= 0.0:
		_enter_recover(RECOVER_TIME)

func _enter_recover(time: float) -> void:
	_state = State.RECOVER
	_timer = time
	_charge_cd = CHARGE_COOLDOWN
	velocity = Vector2.ZERO
