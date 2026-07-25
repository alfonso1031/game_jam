extends CharacterBody2D

const Palette := preload("res://scripts/core/palette.gd")
const ProjectileScene := preload("res://scenes/boss/projectile.tscn")
const PickupScene := preload("res://scenes/props/ability_pickup.tscn")

const MAX_HEALTH := 6
const HIT_COOLDOWN := 0.7

# Por fase (1..3): velocidad de persecución, duración de persecución,
# cantidad de proyectiles y ventana de vulnerabilidad.
const CHASE_SPEED := [55.0, 85.0, 120.0]
const CHASE_TIME := [2.2, 1.8, 1.4]
const BURST_COUNT := [8, 10, 12]
const VULNERABLE_TIME := [1.9, 1.6, 1.3]

enum State {CHASE, SHOOT, VULNERABLE, DEAD}

@export var room_id: String = "L3_NUCLEO"
@export var ability_id: String = "dash"

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

func _ready() -> void:
	if GameState.bosses_defeated.get(room_id, false):
		queue_free()
		return
	_player = get_tree().get_first_node_in_group("player")
	_seal_doors(true)
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

	_resolve_contact()

func _phase() -> int:
	if health > 4:
		return 1
	elif health > 2:
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

func _enter_shoot() -> void:
	_state = State.SHOOT
	_timer = 0.45
	shell.color = Palette.WARM_LIGHT
	_fire_burst()

func _enter_vulnerable() -> void:
	_state = State.VULNERABLE
	_timer = VULNERABLE_TIME[_phase() - 1]
	shell.color = Palette.WALL.darkened(0.3)
	core.color = Palette.SLIME_CORE
	light.energy = 1.4

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
	player_node.velocity = (player_node.global_position - global_position).normalized() * 700.0
	if health <= 0:
		_die()
	else:
		_enter_chase()

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
		if node.has_method("set_sealed"):
			node.set_sealed(value)
