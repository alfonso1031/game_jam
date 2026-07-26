extends Node

const MapGenerator := preload("res://core/map_generator.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")

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
		room.free()
	_finish()


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
