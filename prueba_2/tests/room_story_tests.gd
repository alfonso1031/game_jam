extends Node

const RunMap := preload("res://core/run_map.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	Inventory.reset_run()

	var pickup_scene: PackedScene = load("res://world/props/part_pickup.tscn")
	var loose_pickup: Area2D = pickup_scene.instantiate()
	_check(loose_pickup.has_signal("collected"), "el pickup avisa cuando se recoge")
	loose_pickup.free()

	var has_state_contract := (
		GameState.has_method("claim_room_reward")
		and GameState.has_method("is_room_reward_claimed")
	)
	_check(has_state_contract, "GameState expone recompensas de sala")

	var body_path := "res://world/props/body_source.tscn"
	var has_body_scene := ResourceLoader.exists(body_path)
	_check(has_body_scene, "existe la escena del cuerpo")
	if has_state_contract and has_body_scene:
		await _test_body_reward(body_path)

	for asset_path: String in [
		"res://assets/environment/body/inert_body.png",
		"res://assets/environment/blood/blood_drops.png",
		"res://assets/environment/blood/blood_drag.png",
		"res://assets/environment/blood/blood_pool.png",
	]:
		var exists := ResourceLoader.exists(asset_path)
		_check(exists, "%s existe" % asset_path)
		if exists:
			_check(load(asset_path) is Texture2D, "%s importa como textura" % asset_path)

	var trail_path := "res://world/props/blood_trail.tscn"
	var has_trail_scene := ResourceLoader.exists(trail_path)
	_check(has_trail_scene, "existe la escena reutilizable del rastro")
	if has_trail_scene:
		_test_blood_trail(trail_path)

	_test_story_rooms()

	_finish()


func _test_body_reward(body_path: String) -> void:
	var scene: PackedScene = load(body_path)
	var body: Node2D = scene.instantiate()
	body.configure("C_01", "serrated_jaw")
	add_child(body)
	await get_tree().process_frame

	var pickup := body.get_node_or_null("PartPickup")
	_check(
		pickup != null and pickup.part_id == "serrated_jaw",
		"el cuerpo aloja la recompensa"
	)
	if pickup != null:
		pickup.emit_signal("collected", "serrated_jaw")
		_check(GameState.is_room_reward_claimed("C_01"), "recoger marca la sala")

	body.queue_free()
	await get_tree().process_frame

	var revisited: Node2D = scene.instantiate()
	revisited.configure("C_01", "serrated_jaw")
	add_child(revisited)
	await get_tree().process_frame
	_check(revisited.get_node_or_null("PartPickup") == null, "volver no duplica la parte")
	revisited.queue_free()
	await get_tree().process_frame

	GameState.reset_run()
	_check(
		not GameState.is_room_reward_claimed("C_01"),
		"otra partida libera la recompensa"
	)


func _test_blood_trail(trail_path: String) -> void:
	var scene: PackedScene = load(trail_path)
	var trail: Node2D = scene.instantiate()
	_check(trail.has_method("configure"), "el rastro puede orientarse entre dos puntos")
	if not trail.has_method("configure"):
		trail.free()
		return
	trail.configure(Vector2(200, 540), Vector2(960, 540), true)
	_check(trail.get_child_count() >= 6, "el rastro combina gotas arrastre y charco")
	_check(trail.get_node_or_null("Pool") != null, "el cuerpo puede terminar en un charco")
	_check(trail.position == Vector2.ZERO, "el rastro no desplaza el origen de la sala")
	for child in trail.get_children():
		_check(not child is CollisionObject2D, "el rastro no bloquea al jugador")
	trail.free()


func _test_story_rooms() -> void:
	var grids := {
		"N": Vector2i(0, -1),
		"E": Vector2i(1, 0),
		"S": Vector2i(0, 1),
		"O": Vector2i(-1, 0),
	}
	for direction: String in ["N", "E", "S", "O"]:
		var run_map := RunMap.new(100, 0)
		run_map.add_room("ENTRY", Vector2i.ZERO, &"entry", &"tutorial")
		run_map.add_room("BODY", grids[direction], &"body", &"body_reward")
		run_map.add_room("NORMAL", grids[direction] * 2, &"normal", &"empty")
		run_map.connect_rooms("ENTRY", "BODY", direction)
		run_map.connect_rooms("BODY", "NORMAL", direction)
		run_map.entry_room_id = "ENTRY"
		run_map.main_path.assign(["ENTRY", "BODY", "NORMAL"])
		run_map.rooms["BODY"]["reward_part_id"] = "serrated_jaw"
		RunManager.current_map = run_map

		var entry: Node2D = RoomAssembler.build(run_map.room("ENTRY"))
		var body: Node2D = RoomAssembler.build(run_map.room("BODY"))
		var normal: Node2D = RoomAssembler.build(run_map.room("NORMAL"))
		_check(entry.get_node_or_null("BloodTrail") != null, "%s guía desde tutorial" % direction)
		_check(entry.get_node_or_null("BodySource") == null, "%s no pone cuerpo en tutorial" % direction)
		_check(body.get_node_or_null("BloodTrail") != null, "%s continúa sangre" % direction)
		_check(body.get_node_or_null("BodySource") != null, "%s pone cuerpo segundo" % direction)
		_check(normal.get_node_or_null("BloodTrail") == null, "%s no sangra en sala normal" % direction)
		_check(normal.get_node_or_null("BodySource") == null, "%s no repite el cuerpo" % direction)
		entry.free()
		body.free()
		normal.free()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: room story content")
		get_tree().quit(0)
		return
	get_tree().quit(1)
