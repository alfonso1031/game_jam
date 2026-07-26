extends Node

const RunMap := preload("res://core/run_map.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := RunMap.new(4, 0)
	map.add_room("SOURCE", Vector2i.ZERO, &"normal", &"easy")
	map.add_room("TARGET", Vector2i.RIGHT, &"grate_destination", &"loot")
	map.set_grate("SOURCE", "TARGET")
	RunManager.current_map = map
	RunManager.active = true
	GameState.reset_run()

	var source_room: Node2D = RoomAssembler.build(map.room("SOURCE"))
	var target_room: Node2D = RoomAssembler.build(map.room("TARGET"))
	_test_grate_assembly(
		source_room,
		"SOURCE",
		"TARGET",
		true,
		Vector2(1650, 540),
		Vector2(1470, 540)
	)
	_test_grate_assembly(
		target_room,
		"TARGET",
		"SOURCE",
		false,
		Vector2(960, 540),
		Vector2(1140, 540)
	)
	source_room.free()
	target_room.free()

	var room_host := Node2D.new()
	var player := Node2D.new()
	var fade := ColorRect.new()
	add_child(room_host)
	add_child(player)
	add_child(fade)
	Transition.setup(room_host, player, fade)
	Transition.load_initial("SOURCE")
	await Transition.go_via_grate("TARGET")
	var grate_spawn := room_host.get_child(0).get_node_or_null("GrateSpawn") as Marker2D
	_check(GameState.current_room == "TARGET", "viaje por rejilla actualiza la sala actual")
	_check(grate_spawn != null, "el destino ofrece GrateSpawn")
	_check(
		grate_spawn != null and player.global_position == grate_spawn.global_position,
		"viaje por rejilla coloca al jugador en GrateSpawn"
	)
	room_host.queue_free()
	player.queue_free()
	fade.queue_free()
	await get_tree().process_frame
	_finish()


func _test_grate_assembly(
	room: Node2D,
	source_id: String,
	target_id: String,
	requires_cost: bool,
	expected_position: Vector2,
	expected_spawn_position: Vector2
) -> void:
	var grate := room.get_node_or_null("Grate") as Area2D
	var spawn := room.get_node_or_null("GrateSpawn") as Marker2D
	_check(grate != null, "%s materializa Grate" % source_id)
	_check(spawn != null, "%s materializa GrateSpawn" % source_id)
	if grate == null:
		return
	_check(grate.source_room_id == source_id, "%s conserva el origen" % source_id)
	_check(grate.target_room_id == target_id, "%s apunta a %s" % [source_id, target_id])
	_check(grate.requires_cost == requires_cost, "%s conserva la regla de coste" % source_id)
	_check(grate.position == expected_position, "%s ubica la rejilla" % source_id)
	_check(
		spawn != null and spawn.position == expected_spawn_position,
		"%s coloca GrateSpawn 180 px hacia el interior" % source_id
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
		print("PASS: grate flow")
		get_tree().quit(0)
		return
	get_tree().quit(1)
