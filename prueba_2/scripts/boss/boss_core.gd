extends CharacterBody2D

const Palette := preload("res://scripts/core/palette.gd")
const ProjectileScene := preload("res://scenes/boss/projectile.tscn")
const PickupScene := preload("res://scenes/props/ability_pickup.tscn")

const MAX_HEALTH := 4
const HIT_COOLDOWN := 0.7
# Tras un golpe el boss retrocede y no hace daño por contacto: si no, el jugador
# sigue solapado con la hitbox y come daño en el frame siguiente.
const RECOIL_TIME := 0.9

# Por fase (1..3): velocidad de persecución, duración de persecución,
# cantidad de proyectiles y ventana de vulnerabilidad.
const CHASE_SPEED := [45.0, 65.0, 85.0]
const CHASE_TIME := [2.4, 2.0, 1.7]
const BURST_COUNT := [6, 8, 10]
const VULNERABLE_TIME := [3.4, 3.0, 2.6]

enum State {CHASE, SHOOT, VULNERABLE, RECOIL, DEAD}

@export var room_id: String = "L3_NUCLEO"
@export var ability_id: String = "dash"
# Solo se sellan estas salidas. La puerta de vuelta queda abierta para no
# encerrar al jugador si todavía no entendió la mecánica.
@export var sealed_directions: Array[String] = ["N"]

var health := MAX_HEALTH

var _state: int = State.CHASE
var _timer := 0.0
var _hit_cd := 0.0
var _pulse := 0.0
var _player: Node2D

@onready var shell: Polygon2D = $Shell
@onready var core: Polygon2D = $Core
@onready var light: PointLight2D = $Light
@onready var hitbox: Area2D = $Hitbox
@onready var state_label: Label = $StateLabel
@onready var health_fill: ColorRect = $HealthBar/Fill

const HEALTH_BAR_WIDTH := 200.0

func _ready() -> void:
	if GameState.bosses_defeated.get(room_id, false):
		queue_free()
		return
	_player = get_tree().get_first_node_in_group("player")
	_seal_doors(true)
	_refresh_health_bar()
	_enter_chase()

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	_timer -= delta
	_hit_cd = max(0.0, _hit_cd - delta)
	_pulse += delta

	match _state:
		State.CHASE:
			_chase(delta)
			if _timer <= 0.0:
				_enter_shoot()
		State.SHOOT:
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
			move_and_slide()
			if _timer <= 0.0:
				_enter_vulnerable()
		State.VULNERABLE:
			velocity = velocity.lerp(Vector2.ZERO, 0.15)
			move_and_slide()
			core.scale = Vector2.ONE * (1.0 + sin(_pulse * 8.0) * 0.12)
			if _timer <= 0.0:
				_enter_chase()
		State.RECOIL:
			velocity = velocity.lerp(Vector2.ZERO, 0.06)
			move_and_slide()
			if _timer <= 0.0:
				_enter_chase()

	_resolve_contact()

func _phase() -> int:
	if health > 2:
		return 1
	elif health > 1:
		return 2
	return 3

func _chase(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var dir := (_player.global_position - global_position).normalized()
	velocity = velocity.lerp(dir * CHASE_SPEED[_phase() - 1], 0.08)
	move_and_slide()

func _enter_chase() -> void:
	_state = State.CHASE
	_timer = CHASE_TIME[_phase() - 1]
	core.scale = Vector2.ONE
	core.color = Palette.WALL.lightened(0.1)
	light.energy = 0.5
	shell.color = Palette.WALL
	_set_label("NÚCLEO SELLADO", Palette.WALL.lightened(0.4))

func _enter_shoot() -> void:
	_state = State.SHOOT
	_timer = 0.45
	shell.color = Palette.WARM_LIGHT
	_set_label("¡CUIDADO!", Palette.WARM_LIGHT)
	_fire_burst()

func _enter_vulnerable() -> void:
	_state = State.VULNERABLE
	_timer = VULNERABLE_TIME[_phase() - 1]
	shell.color = Palette.WALL.darkened(0.3)
	core.color = Palette.SLIME_CORE
	light.energy = 1.4
	_set_label("¡NÚCLEO EXPUESTO — CHOCALO!", Palette.SLIME_CORE)

func _set_label(text: String, color: Color) -> void:
	state_label.text = text
	state_label.add_theme_color_override("font_color", color)

func _refresh_health_bar() -> void:
	health_fill.size.x = HEALTH_BAR_WIDTH * float(health) / float(MAX_HEALTH)

func _fire_burst() -> void:
	var count: int = BURST_COUNT[_phase() - 1]
	var offset := randf() * TAU
	for i in range(count):
		var angle: float = offset + TAU * float(i) / float(count)
		var dir := Vector2.RIGHT.rotated(angle)
		var projectile: Node2D = ProjectileScene.instantiate()
		projectile.direction = dir
		projectile.position = position + dir * 78.0
		get_parent().add_child(projectile)

func _resolve_contact() -> void:
	if _state == State.RECOIL:
		return
	for body in hitbox.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		if _state == State.VULNERABLE:
			if _hit_cd <= 0.0:
				_take_damage(body)
		else:
			body.take_damage(1, global_position)
		return

func _take_damage(player_node: Node2D) -> void:
	health -= 1
	_hit_cd = HIT_COOLDOWN
	_refresh_health_bar()
	var away := (player_node.global_position - global_position).normalized()
	player_node.apply_knockback(global_position, 700.0)
	if health <= 0:
		_die()
		return
	_enter_recoil(-away)

func _enter_recoil(push_dir: Vector2) -> void:
	_state = State.RECOIL
	_timer = RECOIL_TIME
	velocity = push_dir * 420.0
	shell.color = Palette.WALL
	core.color = Palette.WALL.lightened(0.1)
	core.scale = Vector2.ONE
	light.energy = 0.5
	_set_label("¡GOLPE!", Palette.SLIME_BODY)

func _die() -> void:
	_state = State.DEAD
	GameState.bosses_defeated[room_id] = true
	_seal_doors(false)

	var pickup: Node2D = PickupScene.instantiate()
	pickup.ability_id = ability_id
	pickup.position = position
	get_parent().add_child(pickup)

	queue_free()

func _seal_doors(value: bool) -> void:
	for node in get_parent().get_children():
		if node.has_method("set_sealed") and node.get("direction") in sealed_directions:
			node.set_sealed(value)
