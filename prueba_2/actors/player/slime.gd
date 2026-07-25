extends CharacterBody2D

const Palette := preload("res://core/palette.gd")
const Layers := preload("res://core/layers.gd")

# --- Impulso cargado: movimiento base del slime (todavía no tiene piernas) ---
# Portado de prototypes/slime_charge_movement. Se mantiene la dirección para
# cargar y se suelta para lanzarse; durante el vuelo no se puede girar.
const MAX_CHARGE_TIME := 1.0
# Por debajo de este tiempo no hay impulso: machacar teclas no es movimiento.
# El desplazamiento continuo es una habilidad futura (piernas).
const MIN_CHARGE_TIME := 0.12
const MIN_DISTANCE := 112.0
const MAX_DISTANCE := 520.0

# El recorrido no va a velocidad fija: sale acelerando y frena de forma
# exponencial hacia el final. La distancia recorrida no cambia (la controla
# `_remaining`), solo el reparto del tiempo — es lo que quita la sensación tosca.
const LAUNCH_PEAK_SPEED := 2100.0
const LAUNCH_END_SPEED := 120.0
const LAUNCH_EASE := 0.7
# Arranque: fracción del pico con la que sale y tramo en el que acelera.
# Cuanto más bajo el arranque y más largo el tramo, más se nota el despegue.
const LAUNCH_START := 0.18
const LAUNCH_RAMP := 0.28

const RECOVERY_TIME := 0.12
# Chocar contra una pared cuesta caro: el slime queda aplastado y aturdido.
const WALL_RECOVERY_TIME := 0.45
# Soltar antes del mínimo: la carga se desinfla y también penaliza.
const FIZZLE_RECOVERY_TIME := 0.28

# --- DASH de habilidad: recompensa del boss, cruza huecos ---
# Mismo perfil de aceleración. Las constantes están calibradas para que la
# integral de la curva supere con margen el ancho del hueco de L2_BIOLAB
# (120 px) más el diámetro del slime (90 px).
const DASH_PEAK_SPEED := 2200.0
const DASH_END_SPEED := 300.0
const DASH_EASE := 0.8
const DASH_START := 0.30
const DASH_RAMP := 0.22
const DASH_TIME := 0.32
const DASH_COOLDOWN := 0.8

# Un impacto rasante desvía en vez de cortar el recorrido: es lo que hace que
# las jambas en embudo de las puertas guíen hacia adentro. Por encima de este
# coseno el golpe se considera frontal y sí aturde.
const GRAZE_DOT := 0.85

const INVULN_TIME := 1.0
const KNOCKBACK := 620.0
const KNOCKBACK_DECAY := 7.0

const BAR_WIDTH := 96.0
const BAR_HEIGHT := 10.0
const BAR_Y := -78.0

enum State {IDLE, CHARGING, LAUNCHING, RECOVERING, DASHING}

@onready var body: Polygon2D = $Body
@onready var core: Polygon2D = $Body/Core
@onready var slime_audio: Node = $SlimeAudio

var _state: int = State.IDLE
var _charge_time := 0.0
var _charge_dir := Vector2.RIGHT
var _facing := Vector2.RIGHT
var _remaining := 0.0
var _launch_distance := 1.0
var _recovery := 0.0
# Velocidad actual normalizada al pico: alimenta el estiramiento del cuerpo.
var _speed_ratio := 0.0

var _dash_time := 0.0
var _dash_cd := 0.0
var _invuln := 0.0
var _knockback := Vector2.ZERO
var _breathe := 0.0

func _physics_process(delta: float) -> void:
	_dash_cd = max(0.0, _dash_cd - delta)
	_invuln = max(0.0, _invuln - delta)
	_apply_knockback(delta)

	if _state == State.DASHING:
		_advance_dash(delta)
	elif not _try_dash():
		match _state:
			State.IDLE:
				var input_dir := _input_direction()
				if input_dir != Vector2.ZERO:
					_begin_charge(input_dir)
			State.CHARGING:
				if _has_direction_held():
					_update_charge(delta)
				else:
					_release_charge()
			State.LAUNCHING:
				_advance_launch(delta)
			State.RECOVERING:
				_advance_recovery(delta)

	_update_visual(delta)
	queue_redraw()

# --- API pública ---

func is_dashing() -> bool:
	return _state == State.DASHING

func take_damage(amount: int = 1, from: Vector2 = Vector2.ZERO) -> void:
	if _invuln > 0.0:
		return
	_invuln = INVULN_TIME
	GameState.damage(amount)
	if from != Vector2.ZERO:
		apply_knockback(from, KNOCKBACK)

func apply_knockback(from: Vector2, force: float) -> void:
	_knockback = (global_position - from).normalized() * force
	if _state == State.CHARGING or _state == State.LAUNCHING:
		if _state == State.CHARGING:
			slime_audio.stop_charge()
		_begin_recovery(RECOVERY_TIME)

# --- Impulso cargado ---

func _input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _has_direction_held() -> bool:
	return (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	)

func _charge_power() -> float:
	return clampf(_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)

func _begin_charge(direction: Vector2) -> void:
	_state = State.CHARGING
	_charge_time = 0.0
	_charge_dir = direction.normalized()
	_facing = _charge_dir
	slime_audio.begin_charge()

func _update_charge(delta: float) -> void:
	_charge_time = min(_charge_time + delta, MAX_CHARGE_TIME)
	slime_audio.update_charge(_charge_power())
	# Con dos direcciones opuestas el vector es cero: la carga sigue corriendo
	# y se conserva la última dirección válida.
	var input_dir := _input_direction()
	if input_dir != Vector2.ZERO:
		_charge_dir = input_dir.normalized()
		_facing = _charge_dir

func _release_charge() -> void:
	if _charge_time < MIN_CHARGE_TIME:
		slime_audio.fizzle()
		_begin_recovery(FIZZLE_RECOVERY_TIME)
		return
	_remaining = lerpf(MIN_DISTANCE, MAX_DISTANCE, _charge_power())
	_launch_distance = _remaining
	_state = State.LAUNCHING
	slime_audio.launch()

func _advance_launch(delta: float) -> void:
	var ratio: float = clampf(_remaining / _launch_distance, 0.0, 1.0)
	var speed := _eased_speed(ratio, LAUNCH_PEAK_SPEED, LAUNCH_END_SPEED, LAUNCH_EASE, LAUNCH_RAMP, LAUNCH_START)
	_speed_ratio = speed / LAUNCH_PEAK_SPEED
	velocity = _charge_dir * speed

	var step: float = min(speed * delta, _remaining)
	var collision := move_and_collide(_charge_dir * step)
	_remaining -= step

	var collided: bool = collision != null
	if collided:
		slime_audio.impact()
		var deflected := _deflect(collision, _charge_dir)
		if deflected == Vector2.ZERO:
			_begin_recovery(WALL_RECOVERY_TIME)
			return
		_charge_dir = deflected
		_facing = deflected

	if _remaining <= 0.001:
		if not collided:
			slime_audio.recover()
		_begin_recovery(RECOVERY_TIME)

# Golpe rasante: se desliza por la superficie y el recorrido continúa en la
# dirección desviada. Golpe frontal: devuelve ZERO y el llamador aturde.
func _deflect(collision: KinematicCollision2D, dir: Vector2) -> Vector2:
	var normal := collision.get_normal()
	if -dir.dot(normal) >= GRAZE_DOT:
		return Vector2.ZERO

	var slide := collision.get_remainder().slide(normal)
	if slide.is_zero_approx():
		return Vector2.ZERO

	move_and_collide(slide)
	return slide.normalized()

# Perfil compartido por el impulso y el DASH: arranca acelerando desde una
# fracción del pico y cae exponencialmente hasta una velocidad final finita
# (finita para que el recorrido termine en vez de arrastrarse).
func _eased_speed(
	remaining_ratio: float,
	peak: float,
	end: float,
	ease_exp: float,
	ramp: float,
	start: float
) -> float:
	var speed: float = end + (peak - end) * pow(remaining_ratio, ease_exp)
	var progress := 1.0 - remaining_ratio
	var ramp_t: float = clampf(progress / ramp, 0.0, 1.0)
	return speed * lerpf(start, 1.0, smoothstep(0.0, 1.0, ramp_t))

func _begin_recovery(time: float) -> void:
	_state = State.RECOVERING
	_recovery = time
	_remaining = 0.0
	_charge_time = 0.0
	_speed_ratio = 0.0
	velocity = Vector2.ZERO

func _advance_recovery(delta: float) -> void:
	_recovery -= delta
	if _recovery <= 0.0:
		_state = State.IDLE

# --- DASH de habilidad ---

func _try_dash() -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	if not GameState.has_ability("dash") or _dash_cd > 0.0:
		return false
	if _state == State.LAUNCHING or _state == State.RECOVERING:
		return false
	_start_dash()
	return true

func _start_dash() -> void:
	_state = State.DASHING
	_dash_time = DASH_TIME
	_dash_cd = DASH_COOLDOWN + DASH_TIME
	_invuln = max(_invuln, DASH_TIME)
	_charge_time = 0.0
	set_collision_mask_value(Layers.GAP_BIT, false)
	slime_audio.dash()

func _advance_dash(delta: float) -> void:
	var ratio: float = clampf(_dash_time / DASH_TIME, 0.0, 1.0)
	var speed := _eased_speed(ratio, DASH_PEAK_SPEED, DASH_END_SPEED, DASH_EASE, DASH_RAMP, DASH_START)
	_speed_ratio = speed / DASH_PEAK_SPEED
	velocity = _facing * speed

	var collision := move_and_collide(_facing * speed * delta)
	_dash_time -= delta

	var collided: bool = collision != null
	if collided:
		slime_audio.impact()
		var deflected := _deflect(collision, _facing)
		if deflected == Vector2.ZERO:
			_end_dash(true)
			return
		_facing = deflected

	if _dash_time <= 0.0:
		if not collided:
			slime_audio.recover()
		_end_dash(false)

func _end_dash(collided: bool) -> void:
	set_collision_mask_value(Layers.GAP_BIT, true)
	_begin_recovery(WALL_RECOVERY_TIME if collided else RECOVERY_TIME)

# --- Empuje ---

func _apply_knockback(delta: float) -> void:
	if _knockback.is_zero_approx():
		return
	move_and_collide(_knockback * delta)
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-KNOCKBACK_DECAY * delta))
	if _knockback.length() < 10.0:
		_knockback = Vector2.ZERO

# --- Presentación ---

func _update_visual(delta: float) -> void:
	var target_scale := Vector2.ONE
	var target_offset := Vector2.ZERO

	match _state:
		State.CHARGING:
			# Se comprime en el eje del lanzamiento y retrocede como un resorte.
			# La curva hace que la compresión gane fuerza cerca de la carga plena.
			var power: float = pow(_charge_power(), 0.75)
			target_scale = Vector2(1.0 - power * 0.22, 1.0 + power * 0.16)
			target_offset = -_charge_dir * power * 14.0
			body.rotation = lerp_angle(body.rotation, _charge_dir.angle(), 1.0 - exp(-14.0 * delta))
		State.LAUNCHING, State.DASHING:
			# El estiramiento sigue la velocidad real: se afila al salir y se
			# redondea solo mientras frena, en vez de un valor fijo todo el vuelo.
			target_scale = Vector2(1.0 + _speed_ratio * 0.36, 1.0 - _speed_ratio * 0.26)
			body.rotation = lerp_angle(body.rotation, _facing.angle(), 1.0 - exp(-22.0 * delta))
		State.RECOVERING:
			# Rebote: aplastado al aterrizar y recuperando forma durante la pausa.
			var settle: float = clampf(_recovery / WALL_RECOVERY_TIME, 0.0, 1.0)
			target_scale = Vector2(1.0 + settle * 0.24, 1.0 - settle * 0.2)
		_:
			_breathe += delta
			var breathe: float = sin(_breathe * 2.0) * 0.04
			target_scale = Vector2(1.0 + breathe, 1.0 - breathe)
			body.rotation = lerp_angle(body.rotation, 0.0, 1.0 - exp(-6.0 * delta))

	# Suavizado exponencial: independiente del framerate.
	var smoothing: float = 1.0 - exp(-18.0 * delta)
	body.scale = body.scale.lerp(target_scale, smoothing)
	body.position = body.position.lerp(target_offset, smoothing)

	core.modulate.a = 1.0 if _state == State.DASHING else 0.6 + sin(_breathe * 3.0) * 0.2
	# Parpadeo durante los frames de invulnerabilidad.
	modulate.a = 0.45 if _invuln > 0.0 and int(_invuln * 12.0) % 2 == 0 else 1.0

func _draw() -> void:
	if _state != State.CHARGING:
		return

	var power := _charge_power()
	var origin := Vector2(-BAR_WIDTH * 0.5, BAR_Y)
	var size := Vector2(BAR_WIDTH, BAR_HEIGHT)
	var ready_to_launch := _charge_time >= MIN_CHARGE_TIME

	draw_rect(Rect2(origin, size), Color(Palette.VOID, 0.8), true)

	var fill: Color = Palette.SLIME_BODY.lerp(Palette.WARM_LIGHT, power)
	if not ready_to_launch:
		fill = Palette.WALL
	draw_rect(Rect2(origin, Vector2(BAR_WIDTH * power, BAR_HEIGHT)), fill, true)

	# Marca del mínimo: soltar antes de esta línea no lanza nada.
	var threshold_x: float = origin.x + BAR_WIDTH * (MIN_CHARGE_TIME / MAX_CHARGE_TIME)
	draw_line(
		Vector2(threshold_x, origin.y),
		Vector2(threshold_x, origin.y + BAR_HEIGHT),
		Palette.WARM_LIGHT,
		2.0
	)

	draw_rect(Rect2(origin, size), Palette.WALL, false, 2.0)
	if power >= 1.0:
		draw_rect(Rect2(origin - Vector2(4, 4), size + Vector2(8, 8)), Palette.WARM_LIGHT, false, 2.0)
