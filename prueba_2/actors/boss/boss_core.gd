extends CharacterBody2D

const Palette := preload("res://core/palette.gd")
const AbilityPickupScene := preload("res://world/props/ability_pickup.tscn")
const PartPickupScene := preload("res://world/props/part_pickup.tscn")

signal died(boss: Node)

const MAX_HEALTH := 12
const HEALTH_BAR_WIDTH := 260.0
const CONTACT_COOLDOWN := 0.8
const CORNER_REACHED_DISTANCE := 24.0
const CORNERS: Array[Vector2] = [
	Vector2(330, 270),
	Vector2(1590, 270),
	Vector2(1590, 810),
	Vector2(330, 810),
]
const CORNER_SPEED := [620.0, 720.0, 820.0]
const POUNCE_SPEED := [950.0, 1080.0, 1220.0]
const AIM_TIME := [1.35, 1.08, 0.84]
const RECOVER_TIME := [0.64, 0.52, 0.42]

enum State { SEEK_CORNER, CORNER_AIM, POUNCE, RECOVER, DEAD }

@export var room_id: String = "L3_NUCLEO"
@export var ability_id: String = "dash"
@export var part_id: String = "silent_claws"
@export var is_room_leader := true
@export var sealed_directions: Array[String] = ["N", "S", "E", "O"]

var health := MAX_HEALTH

var _state: int = State.SEEK_CORNER
var _timer := 0.0
var _contact_cd := 0.0
var _hurt_flash := 0.0
var _corner_index := -1
var _corner_target := Vector2.ZERO
var _pounce_target := Vector2.ZERO
var _player: Node2D
var _dead := false
var _visual_time := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var health_fill: ColorRect = $HealthBar/Fill


func _ready() -> void:
	if GameState.bosses_defeated.get(room_id, false):
		queue_free()
		return
	add_to_group("enemies")
	add_to_group("bosses")
	_player = get_tree().get_first_node_in_group("player")
	_seal_doors(true)
	_refresh_health_bar()
	_choose_next_corner()


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_timer = maxf(0.0, _timer - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_visual_time += delta

	match _state:
		State.SEEK_CORNER:
			_seek_corner(delta)
		State.CORNER_AIM:
			_brake(delta, 12.0)
			if _timer <= 0.0:
				_enter_pounce()
		State.POUNCE:
			_pounce(delta)
		State.RECOVER:
			_brake(delta, 7.0)
			if _timer <= 0.0:
				_choose_next_corner()

	_resolve_contact()
	_update_visual()
	queue_redraw()


func _draw() -> void:
	if _state != State.CORNER_AIM or _pounce_target == Vector2.ZERO:
		return
	var local_target := to_local(_pounce_target)
	var pulse := 0.52 + sin(_visual_time * 12.0) * 0.18
	draw_dashed_line(
		Vector2.ZERO,
		local_target,
		Color(Palette.WARM_LIGHT, pulse),
		5.0,
		18.0
	)
	draw_circle(local_target, 22.0, Color(Palette.WARM_LIGHT, 0.18))
	draw_arc(local_target, 30.0, 0.0, TAU, 24, Palette.WARM_LIGHT, 4.0)


func _phase() -> int:
	if health > 8:
		return 1
	if health > 4:
		return 2
	return 3


func _choose_next_corner() -> void:
	_state = State.SEEK_CORNER
	var candidates: Array[int] = []
	for index in range(CORNERS.size()):
		if index != _corner_index:
			candidates.append(index)
	_corner_index = candidates[randi() % candidates.size()]
	_corner_target = CORNERS[_corner_index]


func _seek_corner(delta: float) -> void:
	var offset := _corner_target - global_position
	if offset.length() <= CORNER_REACHED_DISTANCE:
		global_position = _corner_target
		_enter_corner_aim()
		return
	var target_velocity: Vector2 = offset.normalized() * CORNER_SPEED[_phase() - 1]
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-14.0 * delta))
	move_and_slide()


func _enter_corner_aim() -> void:
	_state = State.CORNER_AIM
	_timer = AIM_TIME[_phase() - 1]
	_pounce_target = (
		_player.global_position
		if is_instance_valid(_player)
		else Vector2(960, 540)
	)


func _enter_pounce() -> void:
	_state = State.POUNCE
	if is_instance_valid(_player):
		_pounce_target = _player.global_position
	var distance := global_position.distance_to(_pounce_target)
	_timer = maxf(0.22, distance / POUNCE_SPEED[_phase() - 1] + 0.08)


func get_pounce_target() -> Vector2:
	return _pounce_target


func _pounce(_delta: float) -> void:
	var offset := _pounce_target - global_position
	if offset.length() <= 34.0 or _timer <= 0.0:
		_enter_recover()
		return
	velocity = offset.normalized() * POUNCE_SPEED[_phase() - 1]
	move_and_slide()


func _enter_recover() -> void:
	_state = State.RECOVER
	_timer = RECOVER_TIME[_phase() - 1]


func _brake(delta: float, rate: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-rate * delta))
	move_and_slide()


func _resolve_contact() -> void:
	if _state != State.POUNCE or _contact_cd > 0.0:
		return
	for body: Node in hitbox.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		_contact_cd = CONTACT_COOLDOWN
		if body.has_method("take_damage"):
			body.take_damage(1, global_position)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 760.0)
		return


func take_damage(
	amount: int,
	from: Vector2 = Vector2.ZERO,
	knockback: float = 0.0,
	_break_shield: bool = false
) -> void:
	if _dead or amount <= 0:
		return
	health -= amount
	_hurt_flash = 0.14
	if knockback > 0.0 and from != Vector2.ZERO:
		var direction := (global_position - from).normalized()
		velocity += direction * minf(knockback * 0.18, 140.0)
	_refresh_health_bar()
	if health <= 0:
		_die()


func _refresh_health_bar() -> void:
	health_fill.size.x = HEALTH_BAR_WIDTH * maxf(0.0, float(health) / float(MAX_HEALTH))


func _visual_state() -> StringName:
	match _state:
		State.CORNER_AIM:
			return &"corner_aim"
		State.POUNCE:
			return &"pounce"
		State.RECOVER:
			return &"recover"
		_:
			return &"seek_corner"


# La animación solo se relanza al cambiar de estado: reiniciarla cada fotograma
# dejaría `corner_aim` clavada en su primera pose durante todo el aviso.
func _update_sprite_animation() -> void:
	var wanted := _visual_state()
	if sprite.animation != wanted:
		sprite.play(wanted)


func _update_visual() -> void:
	_update_sprite_animation()

	var direction := velocity
	if _state == State.CORNER_AIM and _pounce_target != Vector2.ZERO:
		direction = _pounce_target - global_position
	if absf(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0

	var stretch := 1.0
	var squash := 1.0
	if _state == State.POUNCE:
		stretch = 1.1
		squash = 0.92
	elif _state == State.CORNER_AIM:
		stretch = 0.96 + sin(_visual_time * 10.0) * 0.025
		squash = 1.04 - sin(_visual_time * 10.0) * 0.025
	# El arte ya viene al tamaño de juego: la escala solo conserva el estiramiento
	# mecánico que reforzaba la embestida.
	sprite.scale = Vector2(stretch, squash)
	sprite.rotation = clampf(direction.y / 3000.0, -0.08, 0.08)
	sprite.modulate = Color(1.8, 1.8, 1.8) if _hurt_flash > 0.0 else Color.WHITE


func _die() -> void:
	if _dead:
		return
	_dead = true
	_state = State.DEAD
	velocity = Vector2.ZERO
	GameState.bosses_defeated[room_id] = true
	GameState.mark_room_cleared(room_id)
	RunManager.complete_floor(&"contencion")
	_seal_doors(false)

	var ability_pickup: Node2D = AbilityPickupScene.instantiate()
	ability_pickup.ability_id = ability_id
	ability_pickup.position = position + Vector2(-80, 0)
	get_parent().add_child(ability_pickup)
	ability_pickup.start_drop()

	var part_pickup: Node2D = PartPickupScene.instantiate()
	part_pickup.part_id = part_id
	part_pickup.position = position + Vector2(80, 0)
	get_parent().add_child(part_pickup)
	part_pickup.start_drop()

	died.emit(self)
	call_deferred("queue_free")


func _seal_doors(value: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for node: Node in parent.get_children():
		if not node.has_method("set_sealed"):
			continue
		var direction: Variant = node.get("direction")
		if direction in sealed_directions:
			node.set_sealed(value)
