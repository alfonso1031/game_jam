extends Node

const RoomAssembler := preload("res://world/rooms/room_assembler.gd")
const FADE_DURATION := 0.25
const OPPOSITE := {"N": "S", "S": "N", "E": "O", "O": "E"}

var _room_host: Node
var _player: Node
var _fade_rect: ColorRect
var _busy := false


func setup(room_host: Node, player: Node, fade_rect: ColorRect) -> void:
	_room_host = room_host
	_player = player
	_fade_rect = fade_rect
	_busy = false
	_fade_rect.modulate.a = 0.0


func load_initial(room_id: String) -> void:
	assert(RunManager.current_map != null, "No hay mapa de partida activo")
	_swap_room(room_id, "")
	_set_current_room(room_id)


func go_to(target_id: String, from_dir: String) -> void:
	if _busy or not RunManager.active:
		return
	if RunManager.current_map.room(target_id).is_empty():
		push_error("Transition: sala procedural inexistente %s" % target_id)
		return
	_busy = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	var spawn_name := "Spawn%s" % OPPOSITE[from_dir]
	_swap_room(target_id, spawn_name)
	_set_current_room(target_id)

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	_busy = false


func go_via_grate(target_id: String) -> void:
	if _busy or not RunManager.active:
		return
	if RunManager.current_map.room(target_id).is_empty():
		push_error("Transition: sala procedural inexistente %s" % target_id)
		return
	_busy = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	_swap_room(target_id, "GrateSpawn")
	_set_current_room(target_id)

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	_busy = false


func _set_current_room(room_id: String) -> void:
	GameState.current_room = room_id
	GameState.visited[room_id] = true
	var room_data: Dictionary = RunManager.current_map.room(room_id)
	if not String(room_data.get("grate_target", "")).is_empty():
		GameState.discover_grate(room_id)
	GameState.room_changed.emit(room_id)


func _swap_room(room_id: String, spawn_name: String) -> Node:
	for child in _room_host.get_children():
		_room_host.remove_child(child)
		child.queue_free()

	var room_data: Dictionary = RunManager.current_map.room(room_id)
	assert(not room_data.is_empty(), "Sala procedural inexistente: %s" % room_id)
	var instance: Node2D = RoomAssembler.build(room_data)

	# Posicionar antes de entrar al árbol evita encadenar la puerta de llegada.
	var spawn: Node2D = (
		instance.get_node_or_null(spawn_name)
		if spawn_name != ""
		else null
	)
	_player.global_position = spawn.position if spawn else Vector2(960, 540)
	_room_host.add_child(instance)
	return instance
