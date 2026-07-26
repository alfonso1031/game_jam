extends Node

const BossScene := preload("res://actors/boss/boss_core.tscn")
const ProjectileScene := preload("res://actors/player/abilities/player_projectile.tscn")
const ProceduralRoomScene := preload("res://world/rooms/procedural_room.tscn")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	RunManager.active = true
	RunManager.completed_floors.clear()

	var arena := Node2D.new()
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(1120, 620)
	player.add_to_group("player")
	add_child(arena)
	arena.add_child(player)

	var boss: CharacterBody2D = BossScene.instantiate()
	boss.room_id = "TEST_BOSS"
	boss.position = Vector2(330, 270)
	arena.add_child(boss)
	await get_tree().process_frame

	_check(boss.is_in_group("enemies"), "la Quimera participa en el contrato de enemigos")
	_check(int(boss.get("health")) == 12, "la Quimera comienza con 12 HP")
	_check(
		boss.get_node_or_null("StateLabel") == null,
		"la Quimera no anuncia sus acciones con texto"
	)
	_check(
		boss.get_node_or_null("HealthBar") != null,
		"la Quimera conserva la barra de vida"
	)

	var sprite := boss.get_node_or_null("Sprite") as AnimatedSprite2D
	_check(sprite != null, "la Quimera usa un AnimatedSprite2D")
	var frames: SpriteFrames = sprite.sprite_frames if sprite != null else null
	_check(frames != null, "la Quimera trae su SpriteFrames")
	if frames != null:
		for animation: StringName in [&"seek_corner", &"corner_aim", &"pounce", &"recover"]:
			_check(
				frames.has_animation(animation) and frames.get_frame_count(animation) > 0,
				"la Quimera anima '%s'" % animation
			)
		_check(
			sprite.autoplay != "" and frames.has_animation(StringName(sprite.autoplay)),
			"la Quimera conserva una animación por defecto válida"
		)
	# El estado visual tiene que traducirse sin reiniciar la animación en cada
	# fotograma: si `corner_aim` se relanzara, el aviso no avanzaría de pose.
	_check(boss.has_method("_visual_state"), "la Quimera traduce su estado a animación")

	var can_snapshot := (
		boss.has_method("_enter_corner_aim")
		and boss.has_method("_enter_pounce")
		and boss.has_method("get_pounce_target")
	)
	_check(can_snapshot, "la Quimera expone el ciclo esquina-apuntar-ráfaga")
	if can_snapshot:
		boss.set("health", 12)
		boss.call("_enter_corner_aim")
		_check(
			is_equal_approx(float(boss.get("_timer")), 1.35),
			"la fase 1 anticipa la embestida durante 1.35 s"
		)
		boss.set("health", 8)
		boss.call("_enter_corner_aim")
		_check(
			is_equal_approx(float(boss.get("_timer")), 1.08),
			"la fase 2 anticipa la embestida durante 1.08 s"
		)
		boss.set("health", 4)
		boss.call("_enter_corner_aim")
		_check(
			is_equal_approx(float(boss.get("_timer")), 0.84),
			"la fase 3 anticipa la embestida durante 0.84 s"
		)
		player.position = Vector2(1250, 700)
		boss.call("_enter_pounce")
		var frozen_target: Vector2 = boss.call("get_pounce_target")
		player.position = Vector2(600, 400)
		_check(
			boss.call("get_pounce_target") == frozen_target,
			"la ráfaga conserva la posición del jugador tomada al lanzarse"
		)
		boss.set("health", 12)

	_check(boss.has_method("take_damage"), "la Quimera recibe daño del combate normal")
	if boss.has_method("take_damage"):
		boss.call("take_damage", 12, player.global_position)
		await get_tree().process_frame
		_check(
			GameState.bosses_defeated.get("TEST_BOSS", false),
			"la derrota se conserva durante la partida"
		)
		_check(GameState.is_room_cleared("TEST_BOSS"), "la sala del jefe queda limpia")
		_check(
			RunManager.completed_floors.has(&"contencion"),
			"derrotar a la Quimera completa Contención"
		)
		_check(_has_ability_pickup(arena, "dash"), "la Quimera entrega DASH")
		_check(_has_part_pickup(arena, "silent_claws"), "la Quimera entrega Garras Silenciosas")

	arena.queue_free()
	await get_tree().process_frame
	await _check_room_integration()
	_finish()


func _check_room_integration() -> void:
	GameState.reset_run()
	RunManager.active = true
	var room: Node2D = ProceduralRoomScene.instantiate()
	room.configure({
		"id": "BOSS_ROOM",
		"doors": {"O": "PREBOSS"},
		"role": &"boss_choice",
		"content_type": &"boss_choice",
		"enemy_count": 0,
		"one_way": {},
		"grate_target": "",
		"grate_source": "",
		"closure_keep_direction": "",
	})
	add_child(room)
	await get_tree().process_frame
	_check(room.get_node_or_null("BossCore") != null, "la sala final materializa a la Quimera")
	var arena_decal := room.get_node_or_null("ChimeraArena") as Sprite2D
	_check(
		arena_decal != null
		and arena_decal.texture != null
		and arena_decal.texture.resource_path.ends_with("chimera_arena.png"),
		"la sala final usa el escenario de la Quimera"
	)
	var projectile := ProjectileScene.instantiate() as Area2D
	_check(
		projectile != null and projectile.collision_mask & 2 != 0,
		"los proyectiles del slime detectan la capa del jefe"
	)
	projectile.free()
	room.queue_free()
	await get_tree().process_frame


func _has_ability_pickup(root: Node, ability_id: String) -> bool:
	for child: Node in root.get_children():
		if child.get("ability_id") == ability_id:
			return true
	return false


func _has_part_pickup(root: Node, part_id: String) -> bool:
	for child: Node in root.get_children():
		if child.get("part_id") == part_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	print("PASS: containment boss" if _failures.is_empty() else "FAIL: containment boss")
	get_tree().quit(0 if _failures.is_empty() else 1)
