extends CharacterBody2D

const Palette := preload("res://core/palette.gd")
const Layers := preload("res://core/layers.gd")
const PartsDB := preload("res://core/parts_db.gd")
const ZoneScene := preload("res://world/props/hazard_zone.tscn")
const RadialPulseScene := preload("res://actors/player/abilities/radial_pulse.tscn")

# --- Movimiento base: impulso cargado sin piernas, continuo con piernas ---
# Portado de prototypes/slime_charge_movement. Se mantiene la dirección para
# cargar y se suelta para lanzarse; durante el vuelo no se puede girar.
const MAX_CHARGE_TIME := 1.0
# Por debajo de este tiempo no hay impulso: machacar teclas no es movimiento.
const MIN_CHARGE_TIME := 0.12
const MIN_DISTANCE := 112.0
const MAX_DISTANCE := 520.0

# El arrastre base avanza uniforme: la carga aumenta distancia y duración.
const CRAWL_SPEED := 480.0
const CONTINUOUS_MOVE_SPEED := 280.0

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

# --- Embestida ---
# El slime hace daño al chocar contra un experimento si viene lanzado de verdad.
# Por debajo de esta fracción del pico de velocidad el choque es solo un empujón.
const RAM_SPEED_RATIO := 0.35
# Tras clavar una embestida no vuelve a puntuar hasta soltarse del enemigo.
const RAM_HIT_COOLDOWN := 0.35

# La carga manda: soltar en cuanto se puede pega como un empujón, aguantar hasta
# el tope convierte el impulso en el ataque más fuerte que tiene el slime sin
# partes. Umbrales sobre la potencia de carga (0..1) y su daño.
const RAM_TIERS := [
	{"power": 0.85, "damage": 3},
	{"power": 0.5, "damage": 2},
	{"power": 0.0, "damage": 1},
]
# El DASH de habilidad no se carga, así que pega siempre en el escalón medio.
const DASH_RAM_DAMAGE := 2

# El rastro del DASH de partes deja una zona cada tantos píxeles recorridos.
const TRAIL_STEP := 90.0
# Radios de sondeo para encontrar la pared más cercana (Ventosas Adhesivas).
const WALL_PROBE_DIRECTIONS := 8
const WALL_PROBE_LENGTH := 2000.0

enum State {IDLE, CHARGING, LAUNCHING, RECOVERING, DASHING, PART_DASH}

@onready var body: Polygon2D = $Body
@onready var core: Polygon2D = $Body/Core
@onready var slime_audio: Node = $SlimeAudio

var _state: int = State.IDLE
var _charge_time := 0.0
var _charge_dir := Vector2.RIGHT
var _facing := Vector2.RIGHT
var _remaining := 0.0
var _launch_distance := 1.0
# Potencia de carga con la que se soltó el impulso actual: fija su daño.
var _launch_power := 0.0
var _recovery := 0.0
# Velocidad actual normalizada al pico: alimenta el estiramiento del cuerpo.
var _speed_ratio := 0.0

var _dash_time := 0.0
var _dash_cd := 0.0
var _invuln := 0.0
var _knockback := Vector2.ZERO
var _breathe := 0.0
var _body_base := PackedVector2Array()
var _core_base := PackedVector2Array()
var _crawl_phase := 0.0
var _leg_count := 0
var _continuous_moving := false

# --- Partes equipadas ---
# Buff activo (Piel Escamada, Garras Silenciosas, Placa de Cadera...).
var _buff_time := 0.0
var _buff_flags: Dictionary = {}
# Impactos que el escudo todavía puede absorber.
var _shield := 0
# Estados que los experimentos ponen sobre el slime (red del Arácnido, esporas).
var _status: Dictionary = {}
# Cargas de DASH de la Pierna de Zorro; -1 = la parte no está equipada.
var _dash_charges := -1
# Bloqueo por fallar un golpe con la Garra de Oso.
var _whiff_lock := 0.0
# Estado del DASH que viene de una parte (distinto del DASH de habilidad).
var _part_dash: Dictionary = {}
var _part_dir := Vector2.RIGHT
var _part_remaining := 0.0
var _part_trail := 0.0
var _ram_hit_cd := 0.0
var _rammed: Dictionary = {}

func _ready() -> void:
	_body_base = body.polygon.duplicate()
	_core_base = core.polygon.duplicate()
	GameState.room_changed.connect(_on_room_changed)
	Inventory.slots_changed.connect(_refresh_dash_charges)
	Inventory.slots_changed.connect(_refresh_leg_mobility)
	_refresh_dash_charges()
	_refresh_leg_mobility()

func _physics_process(delta: float) -> void:
	_dash_cd = max(0.0, _dash_cd - delta)
	_invuln = max(0.0, _invuln - delta)
	_whiff_lock = max(0.0, _whiff_lock - delta)
	_ram_hit_cd = max(0.0, _ram_hit_cd - delta)
	_tick_buff(delta)
	_tick_status(delta)
	_apply_knockback(delta)

	if _state == State.PART_DASH:
		_continuous_moving = false
		_advance_part_dash(delta)
	elif _state == State.DASHING:
		_continuous_moving = false
		_advance_dash(delta)
	elif not _try_dash():
		if uses_continuous_movement():
			if _state == State.RECOVERING:
				_advance_recovery(delta)
			else:
				_state = State.IDLE
				_advance_continuous(delta)
		else:
			_continuous_moving = false
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
	return _state == State.DASHING or _state == State.PART_DASH

func aim_direction() -> Vector2:
	return _facing


func leg_count() -> int:
	return _leg_count


func uses_continuous_movement() -> bool:
	return _leg_count > 0


func _refresh_leg_mobility() -> void:
	var previous := _leg_count
	_leg_count = Inventory.equipped_count_for_slot(PartsDB.SLOT_PIERNA)
	if previous == 0 and _leg_count > 0 and _state == State.CHARGING:
		slime_audio.stop_charge()
		_state = State.IDLE
		_charge_time = 0.0
		_speed_ratio = 0.0
		velocity = Vector2.ZERO
	if previous > 0 and _leg_count == 0:
		_continuous_moving = false
		if _state == State.IDLE or _state == State.CHARGING:
			_state = State.IDLE
			velocity = Vector2.ZERO


# Los experimentos preguntan esto al tocarlo: si viene lanzado, el que cobra
# es el experimento, no el slime.
func is_ramming() -> bool:
	if _ram_hit_cd > 0.0:
		return false
	if _state == State.DASHING or _state == State.PART_DASH:
		return true
	return _state == State.LAUNCHING and _speed_ratio >= RAM_SPEED_RATIO

# Daño de la embestida, escalado por lo cargado que iba el impulso. El Caparazón
# del Ariete lo sube; el bono por partes de jefe consumidas se aplica acá porque
# la embestida es el ataque básico del slime, y es lo único que tiene sin partes.
func ram_damage() -> int:
	var base := DASH_RAM_DAMAGE
	if _state == State.LAUNCHING:
		base = _tier_damage(_launch_power)
	base += int(Inventory.mod_sum("ram_damage"))
	return int(round(base * GameState.base_damage_multiplier()))

func _tier_damage(power: float) -> int:
	for tier in RAM_TIERS:
		if power >= tier["power"]:
			return tier["damage"]
	return 1

# Potencia con la que salió el impulso en curso, para la barra y el HUD.
func launch_power() -> float:
	return _launch_power

func notify_ram_hit(_enemy: Node) -> void:
	_ram_hit_cd = RAM_HIT_COOLDOWN

func take_damage(amount: int = 1, from: Vector2 = Vector2.ZERO) -> void:
	if _invuln > 0.0:
		return
	# La Piel Escamada se come el impacto entero, no una fracción.
	if _shield > 0:
		_shield -= 1
		_invuln = INVULN_TIME
		return
	_invuln = INVULN_TIME
	GameState.damage(amount)
	if from != Vector2.ZERO:
		apply_knockback(from, KNOCKBACK)

func apply_knockback(from: Vector2, force: float) -> void:
	# La Placa de Cadera ignora empujes durante su ventana.
	if _buff_flags.get("immune_push", false):
		return
	_knockback = (global_position - from).normalized() * force
	if _state == State.CHARGING or _state == State.LAUNCHING:
		if _state == State.CHARGING:
			slime_audio.stop_charge()
		_begin_recovery(RECOVERY_TIME)

# Estados que los experimentos aplican al slime (red del Arácnido, esporas).
func apply_status(status: String, duration: float) -> void:
	if duration <= 0.0:
		return
	_status[status] = max(float(_status.get(status, 0.0)), duration)
	if status == PartsDB.STATUS_ROOT and _state == State.CHARGING:
		slime_audio.stop_charge()
		_begin_recovery(RECOVERY_TIME)

func has_status(status: String) -> bool:
	return _status.has(status)

func is_floor_immune() -> bool:
	return _buff_flags.get("immune_floor", false)

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


func _advance_continuous(delta: float) -> void:
	if has_status(PartsDB.STATUS_ROOT) or not _knockback.is_zero_approx():
		_continuous_moving = false
		velocity = Vector2.ZERO
		return
	var direction := _input_direction()
	_continuous_moving = direction != Vector2.ZERO
	if not _continuous_moving:
		velocity = Vector2.ZERO
		return
	direction = direction.normalized()
	_facing = direction
	velocity = direction * CONTINUOUS_MOVE_SPEED
	move_and_collide(velocity * delta)


# Tiempo real que cuesta llegar a carga plena. La Pierna de Pálido y el
# Robovigilante lo alargan; el Corazón lo acorta cuando queda un corazón.
func _max_charge_time() -> float:
	var time := MAX_CHARGE_TIME * Inventory.mod_product("charge_time_mult")
	if GameState.is_low_health():
		time *= Inventory.mod_product("low_health_charge_mult")
	return max(0.05, time)

func _charge_power() -> float:
	return clampf(_charge_time / _max_charge_time(), 0.0, 1.0)


func _distance_power() -> float:
	var duration := _max_charge_time() - MIN_CHARGE_TIME
	if duration <= 0.0:
		return 1.0
	return clampf((_charge_time - MIN_CHARGE_TIME) / duration, 0.0, 1.0)


func _begin_charge(direction: Vector2) -> void:
	# Inmovilizado no se puede cargar: la red del Arácnido te deja vendido.
	if has_status(PartsDB.STATUS_ROOT) or _whiff_lock > 0.0:
		return
	_state = State.CHARGING
	_charge_time = 0.0
	_charge_dir = direction.normalized()
	_facing = _charge_dir
	slime_audio.begin_charge()

func _update_charge(delta: float) -> void:
	_charge_time = min(_charge_time + delta, _max_charge_time())
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
	_launch_power = _distance_power()
	_remaining = lerpf(MIN_DISTANCE, MAX_DISTANCE, _launch_power)
	_launch_distance = _remaining
	_state = State.LAUNCHING
	slime_audio.launch()

func _advance_launch(delta: float) -> void:
	var speed := CRAWL_SPEED * _speed_multiplier()
	_speed_ratio = clampf(speed / CRAWL_SPEED, 0.0, 1.5)
	velocity = _charge_dir * speed

	var step: float = minf(speed * delta, _remaining)
	var collision := move_and_collide(_charge_dir * step)
	_remaining -= step

	var collided: bool = collision != null
	if collided:
		slime_audio.impact()
		var deflected := _deflect(collision, _charge_dir)
		if deflected == Vector2.ZERO:
			_begin_recovery(_wall_recovery_time())
			return
		_charge_dir = deflected
		_facing = deflected

	if _remaining <= 0.001:
		if not collided:
			slime_audio.recover()
		_begin_recovery(RECOVERY_TIME)

# Las Garras Silenciosas multiplican la velocidad base mientras duran; las
# esporas del Cuerpo Fúngico tiran para el otro lado.
func _speed_multiplier() -> float:
	var multiplier := float(_buff_flags.get("speed_mult", 1.0))
	if has_status(PartsDB.STATUS_SLOW):
		multiplier *= 0.6
	return multiplier

# El Caparazón del Ariete alarga el aturdimiento contra pared, y la Garra de Oso
# la recuperación de todos los remates.
func _wall_recovery_time() -> float:
	return (WALL_RECOVERY_TIME + Inventory.mod_sum("wall_stun_add")) * Inventory.mod_best("recovery_mult")

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

# Perfil exclusivo del DASH de habilidad: arranca acelerando y cae hacia una
# velocidad final finita. El arrastre base no consume esta curva.
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
	# El Caparazón del Ariete cobra su peaje solo tras un remate, no al desinflar
	# una carga corta.
	if _state == State.LAUNCHING or _state == State.DASHING or _state == State.PART_DASH:
		time += Inventory.mod_sum("recovery_add")
	_state = State.RECOVERING
	_recovery = time
	_remaining = 0.0
	_charge_time = 0.0
	_speed_ratio = 0.0
	_continuous_moving = false
	velocity = Vector2.ZERO

func _advance_recovery(delta: float) -> void:
	_recovery -= delta
	if _recovery <= 0.0:
		_state = State.IDLE

# --- DASH de habilidad ---

func _try_dash() -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	if not GameState.has_ability("dash"):
		return false
	if _state == State.LAUNCHING or _state == State.RECOVERING:
		return false
	if has_status(PartsDB.STATUS_ROOT):
		return false
	# Con la Pierna de Zorro el DASH deja de tener recarga por tiempo y pasa a
	# tener cargas que solo se reponen al cambiar de sala.
	if _dash_charges >= 0:
		if _dash_charges <= 0:
			return false
		_dash_charges -= 1
	elif _dash_cd > 0.0:
		return false
	_start_dash()
	return true

func _refresh_dash_charges() -> void:
	var charges := Inventory.mod_max_int("dash_charges", 0)
	if charges <= 0:
		_dash_charges = -1
		return
	# Al equiparla arranca con el depósito lleno.
	if _dash_charges < 0:
		_dash_charges = charges

func dash_charges_left() -> int:
	return _dash_charges

func _on_room_changed(_room_id: String) -> void:
	var charges := Inventory.mod_max_int("dash_charges", 0)
	_dash_charges = charges if charges > 0 else -1
	_status.clear()

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

# --- Partes: DASH, buffs y estados ---

# La llama el `ability_runner` para los efectos de tipo DASH. Devuelve false si
# la parte no se puede ejecutar ahora, para que no se le cobre la recarga.
func begin_part_dash(effect: Dictionary) -> bool:
	if _state == State.PART_DASH or has_status(PartsDB.STATUS_ROOT) or _whiff_lock > 0.0:
		return false

	var direction := _facing
	if effect.get("to_wall", false) and effect.get("aim", "") != "facing":
		direction = _nearest_wall_direction()
	if direction == Vector2.ZERO:
		return false

	# Ráfaga trasera del Escape de Vapor: quema lo que dejas atrás al salir.
	var backblast: Dictionary = effect.get("backblast", {})
	if not backblast.is_empty():
		var blast: Node2D = RadialPulseScene.instantiate()
		blast.radius = backblast.get("radius", 200.0)
		blast.damage = backblast.get("damage", 1)
		blast.status = backblast.get("status", "")
		blast.status_time = backblast.get("status_time", 0.0)
		blast.color = Palette.WARM_LIGHT
		blast.position = global_position
		_effect_parent().add_child(blast)

	_part_dash = effect
	_part_dir = direction
	_part_remaining = effect.get("distance", 320.0)
	_part_trail = 0.0
	_rammed.clear()
	_facing = direction
	_charge_time = 0.0
	_invuln = max(_invuln, effect.get("invuln", 0.0))
	# El planeo y el garfio pasan por encima de los huecos del suelo.
	if effect.get("glide", false) or effect.get("to_wall", false):
		set_collision_mask_value(Layers.GAP_BIT, false)
	_state = State.PART_DASH
	slime_audio.dash()
	return true

func _advance_part_dash(delta: float) -> void:
	var speed: float = _part_dash.get("speed", 1800.0) * _speed_multiplier()
	_speed_ratio = clampf(speed / DASH_PEAK_SPEED, 0.0, 1.0)
	velocity = _part_dir * speed

	var step: float = min(speed * delta, _part_remaining)
	var collision := move_and_collide(_part_dir * step)
	_part_remaining -= step

	_drop_trail(step)
	if _part_dash.get("pierce", false):
		_hit_pierced_enemies()

	if collision != null:
		# Ventosas y garfio TERMINAN en la pared: llegar es el objetivo, no un
		# accidente, así que no cuenta como choque frontal.
		if _part_dash.get("to_wall", false):
			_end_part_dash(_part_dash.get("stick", 0.0))
			return
		var deflected := _deflect(collision, _part_dir)
		if deflected == Vector2.ZERO:
			_end_part_dash(_wall_recovery_time())
			return
		_part_dir = deflected
		_facing = deflected

	if _part_remaining <= 0.001:
		_end_part_dash(RECOVERY_TIME)

func _drop_trail(step: float) -> void:
	var trail: Dictionary = _part_dash.get("trail", {})
	if trail.is_empty():
		return
	_part_trail += step
	if _part_trail < TRAIL_STEP:
		return
	_part_trail = 0.0
	var zone: Node2D = ZoneScene.instantiate()
	zone.affects = zone.AFFECT_ENEMIES
	zone.duration = trail.get("duration", 2.0)
	zone.radius = trail.get("radius", 60.0)
	zone.dps = trail.get("dps", 3.0)
	zone.color = Palette.SLIME_CORE
	zone.position = global_position
	_effect_parent().add_child(zone)

# Las Patas Hidráulicas y la Pila Voltaica atraviesan: hay que golpear a mano
# porque el cuerpo del slime no colisiona con la capa de enemigos.
func _hit_pierced_enemies() -> void:
	var damage: int = _part_dash.get("damage", 0)
	var push: float = _part_dash.get("push", 0.0)
	if damage <= 0 and push <= 0.0:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if _rammed.has(enemy.get_instance_id()):
			continue
		if enemy.global_position.distance_to(global_position) > 90.0:
			continue
		_rammed[enemy.get_instance_id()] = true
		if damage > 0:
			enemy.take_damage(damage, global_position, push)
		elif push > 0.0:
			enemy.push_away(global_position, push)

func _end_part_dash(recovery: float) -> void:
	set_collision_mask_value(Layers.GAP_BIT, true)
	_part_dash = {}
	_rammed.clear()
	_begin_recovery(max(recovery, RECOVERY_TIME))

# Sondea en abanico y devuelve la dirección de la pared más próxima.
func _nearest_wall_direction() -> Vector2:
	var space := get_world_2d().direct_space_state
	var best := Vector2.ZERO
	var best_distance := INF
	for i in range(WALL_PROBE_DIRECTIONS):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / float(WALL_PROBE_DIRECTIONS))
		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + direction * WALL_PROBE_LENGTH,
			Layers.WORLD_MASK,
			[get_rid()]
		)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var distance: float = global_position.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best = direction
	return best

func apply_part_buff(effect: Dictionary) -> bool:
	var flags: Dictionary = effect.get("flags", {})
	_buff_flags = flags.duplicate()
	_buff_time = effect.get("duration", 1.0)
	_shield = int(flags.get("shield", 0))
	if flags.get("scan", false):
		_scan_room()
	return true

# El escaneo del Robovigilante: marca todo lo vivo de la sala durante la ventana.
func _scan_room() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("apply_status"):
			enemy.apply_status(PartsDB.STATUS_MARK, _buff_time)

func _tick_buff(delta: float) -> void:
	if _buff_time <= 0.0:
		return
	_buff_time -= delta
	if _buff_time > 0.0:
		return
	_buff_flags.clear()
	# El escudo sobrevive a su buff: se gasta con el golpe, no con el reloj.

func _tick_status(delta: float) -> void:
	if _status.is_empty():
		return
	var expired: Array[String] = []
	for status in _status:
		_status[status] = float(_status[status]) - delta
		if float(_status[status]) <= 0.0:
			expired.append(status)
	for status in expired:
		_status.erase(status)

# La llama el runner tras un golpe cuerpo a cuerpo: la Garra de Oso castiga
# fallar dejando al slime clavado un momento.
func notify_melee_swing(arc: Node2D) -> void:
	var lock := Inventory.mod_sum("whiff_lock")
	if lock <= 0.0:
		return
	# Se comprueba al frame siguiente, cuando el arco ya resolvió sus impactos.
	await get_tree().process_frame
	if not is_instance_valid(arc):
		return
	if _nearest_enemy_distance() > arc.range_px:
		_whiff_lock = lock

func _nearest_enemy_distance() -> float:
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			best = min(best, enemy.global_position.distance_to(global_position))
	return best

func _effect_parent() -> Node:
	var room := get_tree().get_first_node_in_group("room")
	return room if room != null else get_parent()

# --- Empuje ---

func _apply_knockback(delta: float) -> void:
	if _knockback.is_zero_approx():
		return
	move_and_collide(_knockback * delta)
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-KNOCKBACK_DECAY * delta))
	if _knockback.length() < 10.0:
		_knockback = Vector2.ZERO

# --- Presentación ---

func _deform_points(
	base: PackedVector2Array,
	charge: float,
	phase: float,
	launching: bool
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in base:
		var normalized_x := clampf(point.x / 45.0, -1.0, 1.0)
		var front := maxf(normalized_x, 0.0)
		var tail := maxf(-normalized_x, 0.0)
		var x := point.x + front * front * charge * 30.0
		x += tail * charge * 8.0
		var belly := 1.0 + charge * 0.10 * (1.0 - absf(normalized_x))
		var wave := sin(phase - normalized_x * PI) * 4.0 if launching else 0.0
		result.append(Vector2(x + wave, point.y * belly))
	return result


func _lerp_points(
	current: PackedVector2Array,
	target: PackedVector2Array,
	weight: float
) -> PackedVector2Array:
	if current.size() != target.size():
		return target.duplicate()
	var result := PackedVector2Array()
	for index in range(target.size()):
		result.append(current[index].lerp(target[index], weight))
	return result


func _update_visual(delta: float) -> void:
	var target_scale := Vector2.ONE
	var target_offset := Vector2.ZERO
	var charge := pow(_charge_power(), 0.75) if _state == State.CHARGING else 0.0
	var launching := _state == State.LAUNCHING
	var crawling := launching or _continuous_moving
	if crawling:
		_crawl_phase += delta * 9.0

	if _state == State.CHARGING or crawling:
		body.polygon = _deform_points(_body_base, charge, _crawl_phase, crawling)
		core.polygon = _deform_points(_core_base, charge * 0.65, _crawl_phase, crawling)
	else:
		var point_smoothing := 1.0 - exp(-18.0 * delta)
		body.polygon = _lerp_points(body.polygon, _body_base, point_smoothing)
		core.polygon = _lerp_points(core.polygon, _core_base, point_smoothing)

	match _state:
		State.CHARGING:
			# El frente se alarga sin desplazar el cuerpo físico.
			body.rotation = lerp_angle(body.rotation, _charge_dir.angle(), 1.0 - exp(-14.0 * delta))
		State.LAUNCHING:
			body.rotation = lerp_angle(body.rotation, _facing.angle(), 1.0 - exp(-14.0 * delta))
		State.DASHING, State.PART_DASH:
			# El DASH conserva un estiramiento rápido independiente del arrastre.
			target_scale = Vector2(1.0 + _speed_ratio * 0.36, 1.0 - _speed_ratio * 0.26)
			body.rotation = lerp_angle(body.rotation, _facing.angle(), 1.0 - exp(-22.0 * delta))
		State.RECOVERING:
			# Rebote: aplastado al aterrizar y recuperando forma durante la pausa.
			var settle: float = clampf(_recovery / WALL_RECOVERY_TIME, 0.0, 1.0)
			target_scale = Vector2(1.0 + settle * 0.24, 1.0 - settle * 0.2)
		_:
			if _continuous_moving:
				body.rotation = lerp_angle(
					body.rotation,
					_facing.angle(),
					1.0 - exp(-14.0 * delta)
				)
			else:
				_breathe += delta
				var breathe: float = sin(_breathe * 2.0) * 0.04
				target_scale = Vector2(1.0 + breathe, 1.0 - breathe)
				body.rotation = lerp_angle(body.rotation, 0.0, 1.0 - exp(-6.0 * delta))

	# Suavizado exponencial: independiente del framerate.
	var smoothing: float = 1.0 - exp(-18.0 * delta)
	if _state == State.CHARGING or launching:
		body.scale = Vector2.ONE
		body.position = Vector2.ZERO
	else:
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
	var threshold_x: float = origin.x + BAR_WIDTH * (MIN_CHARGE_TIME / _max_charge_time())
	draw_line(
		Vector2(threshold_x, origin.y),
		Vector2(threshold_x, origin.y + BAR_HEIGHT),
		Palette.WARM_LIGHT,
		2.0
	)

	# Escalones de daño: son la razón para aguantar la carga, así que tienen que
	# verse mientras se carga y no descubrirse por accidente.
	for tier in RAM_TIERS:
		var tier_power: float = tier["power"]
		if tier_power <= 0.0:
			continue
		var tier_x: float = origin.x + BAR_WIDTH * tier_power
		var reached: bool = power >= tier_power
		draw_line(
			Vector2(tier_x, origin.y - 3.0),
			Vector2(tier_x, origin.y + BAR_HEIGHT + 3.0),
			Palette.WARM_LIGHT if reached else Palette.WALL,
			3.0 if reached else 2.0
		)

	draw_rect(Rect2(origin, size), Palette.WALL, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(origin.x, origin.y - 8.0),
		"x%d" % _tier_damage(power),
		HORIZONTAL_ALIGNMENT_CENTER,
		BAR_WIDTH,
		20,
		Palette.WARM_LIGHT if power >= RAM_TIERS[0]["power"] else Palette.SLIME_CORE
	)
	if power >= 1.0:
		draw_rect(Rect2(origin - Vector2(4, 4), size + Vector2(8, 8)), Palette.WARM_LIGHT, false, 2.0)
