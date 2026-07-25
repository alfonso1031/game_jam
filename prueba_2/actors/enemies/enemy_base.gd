extends CharacterBody2D

# Base común de los experimentos. Los scripts concretos heredan de acá y solo
# escriben su máquina de estados en `_tick_ai()`; vida, contacto con el jugador,
# estados alterados, empuje y drop viven todos acá.
#
# El cuerpo está en la capa `enemy` y solo choca contra `world`: los enemigos no
# empujan al jugador ni se atascan entre ellos. El contacto lo resuelve el
# Area2D `Hitbox`, igual que hace el boss.

const Palette := preload("res://core/palette.gd")
const Layers := preload("res://core/layers.gd")
const PartsDB := preload("res://core/parts_db.gd")
const PickupScene := preload("res://world/props/part_pickup.tscn")
const ProjectileScene := preload("res://actors/enemies/enemy_projectile.tscn")
const ZoneScene := preload("res://world/props/hazard_zone.tscn")

signal died(enemy: Node)

const HURT_FLASH := 0.16
const CONTACT_COOLDOWN := 0.55
const KNOCKBACK_DECAY := 6.0
const BURN_TICK := 0.5
const SLOW_FACTOR := 0.45
const CRIT_MULT := 2

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var move_speed: float = 120.0
# Detección: a partir de esta distancia el experimento reacciona al jugador.
@export var detect_range: float = 1400.0
# Partes que puede soltar. El drop elige una al azar de la lista.
@export var drop_parts: Array[String] = []
@export var drop_rate: float = 0.3
# El líder de sala sella las puertas hasta morir y SIEMPRE suelta parte.
@export var is_room_leader: bool = false
@export var leader_health_mult: float = 1.5
@export var sealed_directions: Array[String] = ["N", "S", "E", "O"]

var health: int
var facing := Vector2.RIGHT

var _player: Node2D
var _knockback := Vector2.ZERO
var _hurt_flash := 0.0
var _contact_cd := 0.0
var _dead := false

# Estados alterados: nombre -> segundos restantes.
var _status: Dictionary = {}
var _burn_tick := 0.0

@onready var body: Polygon2D = $Body
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	if is_room_leader:
		health = int(round(max_health * leader_health_mult))
		add_to_group("room_leaders")
		scale *= 1.25
	_player = get_tree().get_first_node_in_group("player")
	_on_ready()

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_tick_status(delta)
	# La quemadura puede matarlo dentro de `_tick_status`. `queue_free` no libera
	# hasta el final del frame, así que sin este corte el resto del ciclo seguiría
	# corriendo sobre un enemigo ya muerto.
	if _dead:
		return

	_tick_timers(delta)
	_apply_knockback(delta)

	if not has_status(PartsDB.STATUS_STUN) or _ignores_stun():
		_tick_ai(delta)

	_resolve_contact()
	_update_visual(delta)

# --- Puntos de extensión para los experimentos concretos ---

func _on_ready() -> void:
	pass

func _tick_ai(_delta: float) -> void:
	pass

# Los experimentos con guardia frontal (Crustáceo) sobrescriben esto.
func _blocks_from(_attack_position: Vector2) -> bool:
	return false

# El Gólem lo sobrescribe: su embestida no se puede interrumpir con aturdimiento.
func _ignores_stun() -> bool:
	return false

# --- Movimiento asistido ---

func speed_now() -> float:
	var speed := move_speed
	if has_status(PartsDB.STATUS_SLOW):
		speed *= SLOW_FACTOR
	if has_status(PartsDB.STATUS_ROOT):
		speed = 0.0
	return speed

func player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else global_position

func player_offset() -> Vector2:
	return player_position() - global_position

func sees_player() -> bool:
	if not is_instance_valid(_player):
		return false
	# La Pierna de Pálido recorta el alcance de detección de los orgánicos.
	var range_now := detect_range * Inventory.mod_product("detection_mult")
	return player_offset().length() <= range_now

func move_towards(direction: Vector2, speed: float, delta: float, accel: float = 10.0) -> void:
	if has_status(PartsDB.STATUS_ROOT):
		velocity = velocity.lerp(Vector2.ZERO, 0.4)
		move_and_slide()
		return
	var target := direction.normalized() * speed
	velocity = velocity.lerp(target, 1.0 - exp(-accel * delta))
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	move_and_slide()

func brake(delta: float, rate: float = 8.0) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-rate * delta))
	move_and_slide()

# --- Ataques (helpers compartidos por los experimentos) ---

func fire_projectile(direction: Vector2, config: Dictionary = {}) -> Node2D:
	var projectile: Node2D = ProjectileScene.instantiate()
	projectile.direction = direction.normalized()
	projectile.speed = config.get("speed", 340.0)
	projectile.damage = config.get("damage", contact_damage)
	projectile.radius = config.get("radius", 18.0)
	projectile.lifetime = config.get("lifetime", 4.0)
	projectile.color = config.get("color", Palette.WARM_LIGHT)
	projectile.player_status = config.get("status", "")
	projectile.player_status_time = config.get("status_time", 0.0)
	projectile.position = position + direction.normalized() * config.get("offset", 60.0)
	get_parent().add_child(projectile)
	return projectile

func spawn_zone(at: Vector2, config: Dictionary) -> Node2D:
	var zone: Node2D = ZoneScene.instantiate()
	zone.affects = zone.AFFECT_PLAYER
	zone.duration = config.get("duration", 3.0)
	zone.radius = config.get("radius", 120.0)
	zone.dps = config.get("dps", 2.0)
	zone.status = config.get("status", "")
	zone.status_time = config.get("status_time", 0.0)
	zone.color = config.get("color", Palette.SLIME_BODY)
	zone.position = at
	get_parent().add_child(zone)
	return zone

# Golpe de área centrado en el experimento. Devuelve true si alcanzó al jugador.
func hit_player_area(radius: float, damage: int, knockback: float = 0.0) -> bool:
	if not is_instance_valid(_player):
		return false
	if player_offset().length() > radius:
		return false
	_player.take_damage(damage, global_position)
	if knockback > 0.0 and _player.has_method("apply_knockback"):
		_player.apply_knockback(global_position, knockback)
	return true

# Golpe en cono frontal. `arc_deg` es la apertura total.
func hit_player_cone(range_px: float, arc_deg: float, damage: int, direction: Vector2, knockback: float = 0.0) -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := player_offset()
	if offset.length() > range_px:
		return false
	if offset.normalized().dot(direction.normalized()) < cos(deg_to_rad(arc_deg * 0.5)):
		return false
	_player.take_damage(damage, global_position)
	if knockback > 0.0 and _player.has_method("apply_knockback"):
		_player.apply_knockback(global_position, knockback)
	return true

# --- Daño recibido ---

# `crit` lo activa el Ojo Parásito a través del estado MARK.
func take_damage(amount: int, from: Vector2 = Vector2.ZERO, knockback: float = 0.0, break_shield: bool = false) -> void:
	if _dead or amount <= 0:
		return
	if not break_shield and from != Vector2.ZERO and _blocks_from(from):
		_hurt_flash = HURT_FLASH
		return

	var final_amount := amount
	if has_status(PartsDB.STATUS_MARK):
		final_amount *= CRIT_MULT
		clear_status(PartsDB.STATUS_MARK)

	health -= final_amount
	_hurt_flash = HURT_FLASH
	if knockback > 0.0 and from != Vector2.ZERO:
		push_away(from, knockback)
	if health <= 0:
		_die()

func push_away(from: Vector2, force: float) -> void:
	var dir := (global_position - from)
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	_knockback = dir.normalized() * force

# --- Estados alterados ---

func apply_status(status: String, duration: float) -> void:
	if _dead or status == "" or duration <= 0.0:
		return
	_status[status] = max(float(_status.get(status, 0.0)), duration)

func has_status(status: String) -> bool:
	return _status.has(status)

func clear_status(status: String) -> void:
	_status.erase(status)

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

	if not has_status(PartsDB.STATUS_BURN):
		_burn_tick = 0.0
		return
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = BURN_TICK
		health -= 1
		_hurt_flash = HURT_FLASH
		if health <= 0:
			_die()

# --- Contacto con el jugador ---

func _resolve_contact() -> void:
	if _contact_cd > 0.0:
		return
	for other in hitbox.get_overlapping_bodies():
		if not other.is_in_group("player"):
			continue
		# Si el slime viene embistiendo, el que come el golpe es el experimento.
		if other.has_method("is_ramming") and other.is_ramming():
			_contact_cd = CONTACT_COOLDOWN
			take_damage(other.ram_damage(), other.global_position, 420.0)
			other.notify_ram_hit(self)
		elif contact_damage > 0:
			_contact_cd = CONTACT_COOLDOWN
			other.take_damage(contact_damage, global_position)
		return

# --- Muerte y drop ---

func _die() -> void:
	if _dead:
		return
	_dead = true
	_drop()
	died.emit(self)
	queue_free()

func _drop() -> void:
	if drop_parts.is_empty():
		return
	# Los jefes de sala son la fuente fiable de partes: siempre sueltan.
	if not is_room_leader and randf() > drop_rate:
		return
	var part_id: String = drop_parts[randi() % drop_parts.size()]
	var pickup: Node2D = PickupScene.instantiate()
	pickup.part_id = part_id
	pickup.position = position
	get_parent().add_child(pickup)

# --- Presentación (formas primitivas: las texturas van aparte) ---

func _tick_timers(delta: float) -> void:
	_hurt_flash = max(0.0, _hurt_flash - delta)
	_contact_cd = max(0.0, _contact_cd - delta)

func _apply_knockback(delta: float) -> void:
	if _knockback.is_zero_approx():
		return
	move_and_collide(_knockback * delta)
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-KNOCKBACK_DECAY * delta))
	if _knockback.length() < 12.0:
		_knockback = Vector2.ZERO

func _update_visual(_delta: float) -> void:
	var tint := Color.WHITE
	if _hurt_flash > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	elif has_status(PartsDB.STATUS_BURN):
		tint = Color(1.6, 0.9, 0.7)
	elif has_status(PartsDB.STATUS_STUN):
		tint = Color(0.8, 0.9, 1.6)
	elif has_status(PartsDB.STATUS_ROOT):
		tint = Color(0.9, 1.4, 0.9)
	elif has_status(PartsDB.STATUS_MARK):
		tint = Color(1.5, 1.2, 0.7)
	elif has_status(PartsDB.STATUS_SLOW):
		tint = Color(0.75, 0.85, 1.0)
	modulate = tint
	if body != null:
		body.rotation = lerp_angle(body.rotation, facing.angle(), 0.2)
