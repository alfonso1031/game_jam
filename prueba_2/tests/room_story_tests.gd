extends Node

const RunMap := preload("res://core/run_map.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")
const ContainmentPropCatalog := preload("res://core/containment_prop_catalog.gd")

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
	_test_containment_prop_recipe()
	_test_lamp_reach()
	_test_tutorial_mural_contract()

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
		var broken_tube := entry.get_node_or_null("Prop_broken_glass_tube_0") as Node2D
		_check(broken_tube != null, "%s deja el tubo roto en la entrada" % direction)
		if broken_tube != null:
			_check(
				broken_tube.get_meta("prop_id", "") == "broken_glass_tube",
				"%s conserva el id narrativo del tubo roto" % direction
			)
			_check(
				broken_tube.position == Vector2(960, 500),
				"%s centra el tubo roto en la entrada" % direction
			)
			_check(
				broken_tube.scene_file_path == "res://world/props/containment/broken_glass_tube.tscn",
				"%s instancia la escena del tubo roto" % direction
			)
			_check(broken_tube.has_method("footprint"), "%s expone la huella del tubo roto" % direction)
			if broken_tube.has_method("footprint"):
				var broken_footprint: Rect2 = broken_tube.call("footprint")
				_check(
					broken_footprint.size.x > 0.0 and broken_footprint.size.y > 0.0,
					"%s mantiene una huella positiva del tubo roto" % direction
				)
		_check(body.get_node_or_null("Prop_broken_glass_tube_0") == null, "%s no repite el tubo roto en el cuerpo" % direction)
		_check(normal.get_node_or_null("Prop_broken_glass_tube_0") == null, "%s no repite el tubo roto en sala normal" % direction)
		var mural := entry.get_node_or_null("TutorialMural") as Node2D
		_check(mural != null, "%s siempre incluye mural" % direction)
		_check(body.get_node_or_null("TutorialMural") == null, "%s no repite mural" % direction)
		_check(normal.get_node_or_null("TutorialMural") == null, "%s mural solo vive en tutorial" % direction)
		if mural != null:
			var rect: Rect2 = mural.footprint()
			_check(not rect.has_point(Vector2(960, 540)), "%s deja libre el spawn" % direction)
			for door_position: Vector2 in [
				Vector2(960, 60),
				Vector2(1800, 540),
				Vector2(960, 1020),
				Vector2(120, 540),
			]:
				_check(
					not rect.grow(80.0).has_point(door_position),
					"%s deja libre la puerta %s" % [direction, door_position]
				)
		entry.free()
		body.free()
		normal.free()


func _test_containment_prop_recipe() -> void:
	var fixture := {
		"id": "NORMAL_FIXTURE",
		"role": &"normal",
	}
	var first: Array[Dictionary] = ContainmentPropCatalog.placements_for(fixture)
	var second: Array[Dictionary] = ContainmentPropCatalog.placements_for(fixture)
	_check(first == second, "la misma sala conserva props")
	_check(first.size() >= 1 and first.size() <= 3, "una sala normal recibe entre uno y tres props")
	var used_cells: Array[Vector2i] = []
	for item: Dictionary in first:
		var cell: Vector2i = item["cell"] as Vector2i
		_check(cell.x != 6 and cell.y != 3, "deja carriles de puerta")
		_check(not used_cells.has(cell), "no repite la celda de un prop")
		used_cells.append(cell)


func _test_lamp_reach() -> void:
	var lamp_scene: PackedScene = load("res://world/props/lamp.tscn")
	var lamp: Node2D = lamp_scene.instantiate()
	var light: PointLight2D = lamp.get_node("Light")
	_check(is_equal_approx(light.energy, 1.6), "la intensidad de los focos se conserva")
	_check(is_equal_approx(light.texture_scale, 1.85), "el radio de los focos conserva la cobertura aprobada")
	lamp.free()


func _test_tutorial_mural_contract() -> void:
	var texture_path := "res://assets/environment/tutorial/charged_movement_mural.png"
	var texture_exists := ResourceLoader.exists(texture_path)
	_check(texture_exists, "existe el mural de movimiento cargado")
	if texture_exists:
		_check(load(texture_path) is Texture2D, "el mural importa como textura")

	var scene_path := "res://world/props/tutorial_mural.tscn"
	var scene_exists := ResourceLoader.exists(scene_path)
	_check(scene_exists, "existe la escena pasiva del mural")
	if not scene_exists:
		return
	var mural: Node = load(scene_path).instantiate()
	add_child(mural)
	_check(mural.has_method("footprint"), "el mural expone su huella")
	_check(not (mural is CanvasLayer), "el tutorial pertenece al mundo")
	_check(
		mural.process_mode != Node.PROCESS_MODE_ALWAYS,
		"el mural no opera durante pausa"
	)
	mural.queue_free()


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
