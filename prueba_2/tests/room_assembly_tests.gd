extends Node

const MapGenerator := preload("res://core/map_generator.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")
const ContainmentPropCatalog := preload("res://core/containment_prop_catalog.gd")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator := MapGenerator.new()
	var regression_map: RefCounted = generator.generate(1785033756)
	_check(regression_map != null, "la seed de regresión genera")
	if regression_map == null:
		_finish()
		return

	RunManager.current_map = regression_map
	for room_id: String in regression_map.room_ids():
		var data: Dictionary = regression_map.room(room_id)
		var room: Node2D = RoomAssembler.build(data)
		for direction: String in ["N", "E", "S", "O"]:
			var expected: bool = data["doors"].has(direction)
			_check(
				room.has_node("Door%s" % direction) == expected,
				"%s materializa Door%s" % [room_id, direction]
			)
			_check(
				room.has_node("Spawn%s" % direction) == expected,
				"%s materializa Spawn%s" % [room_id, direction]
			)
		_test_containment_props(room, data, room_id)
		room.free()
	_finish()


func _test_containment_props(room: Node2D, room_data: Dictionary, room_id: String) -> void:
	var placements: Array[Dictionary] = ContainmentPropCatalog.placements_for(room_data)
	var expected_names: Array[String] = []
	for index: int in range(placements.size()):
		var placement: Dictionary = placements[index]
		var prop_id: String = String(placement["id"])
		var prop_name := "Prop_%s_%d" % [prop_id, index]
		expected_names.append(prop_name)
		var prop := room.get_node_or_null(prop_name) as Node2D
		_check(prop != null, "%s materializa %s" % [room_id, prop_name])
		if prop == null:
			continue
		_check(prop.get_meta("prop_id", "") == prop_id, "%s conserva el id de %s" % [room_id, prop_name])
		_check(prop.position == placement["position"], "%s conserva la posicion de %s" % [room_id, prop_name])
		var expected_scene: PackedScene = placement["scene"] as PackedScene
		_check(
			prop.scene_file_path == expected_scene.resource_path,
			"%s usa la escena esperada para %s" % [room_id, prop_name]
		)

	var protected_positions: Array[Vector2] = [Vector2(1060, 540)]
	for direction: String in ["N", "E", "S", "O"]:
		var door := room.get_node_or_null("Door%s" % direction) as Node2D
		if door != null:
			protected_positions.append(door.position)
		var spawn := room.get_node_or_null("Spawn%s" % direction) as Node2D
		if spawn != null:
			protected_positions.append(spawn.position)
	for child: Node in room.get_children():
		if not String(child.name).begins_with("Prop_"):
			continue
		_check(child.has_meta("prop_id"), "%s identifica %s como prop" % [room_id, child.name])
		_check(child.has_method("footprint"), "%s expone la huella de %s" % [room_id, child.name])
		if not child.has_meta("prop_id") or not child.has_method("footprint"):
			continue
		var child_id: String = String(child.get_meta("prop_id"))
		_check(
			String(child.name).begins_with("Prop_%s_" % child_id),
			"%s nombra %s con su id" % [room_id, child.name]
		)
		_check(expected_names.has(String(child.name)), "%s no agrega %s fuera de la receta" % [room_id, child.name])
		var footprint: Rect2 = child.call("footprint")
		for protected_position: Vector2 in protected_positions:
			_check(
				not footprint.has_point(protected_position),
				"%s deja libre %s" % [room_id, protected_position]
			)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: room assembly matches RunMap")
		get_tree().quit(0)
		return
	get_tree().quit(1)
