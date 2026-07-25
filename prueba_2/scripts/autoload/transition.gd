extends Node

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

func load_initial(room_id: String) -> void:
	_swap_room(room_id, "")
	GameState.current_room = room_id
	GameState.visited[room_id] = true
	GameState.room_changed.emit(room_id)

func go_to(target_id: String, from_dir: String) -> void:
	if _busy:
		return
	_busy = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	_swap_room(target_id, "Spawn%s" % OPPOSITE[from_dir])

	GameState.current_room = target_id
	GameState.visited[target_id] = true
	GameState.room_changed.emit(target_id)

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished

	_busy = false

func respawn(room_id: String) -> void:
	if _busy:
		return
	_busy = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	_swap_room(room_id, "")

	GameState.current_room = room_id
	GameState.visited[room_id] = true
	GameState.room_changed.emit(room_id)

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished

	_busy = false

func _swap_room(room_id: String, spawn_name: String) -> Node:
	for child in _room_host.get_children():
		_room_host.remove_child(child)
		child.queue_free()

	var room_data: Dictionary = RoomDB.ROOMS[room_id]
	var scene: PackedScene = load(room_data["scene"])
	var instance: Node = scene.instantiate()
	instance.name = room_id

	# El jugador se coloca ANTES de añadir la sala al árbol: si no, las puertas
	# de la sala nueva lo detectan todavía en la posición de la puerta anterior
	# y encadenan otra transición.
	var spawn: Node2D = instance.get_node_or_null(spawn_name) if spawn_name != "" else null
	_player.global_position = spawn.position if spawn else Vector2(960, 540)

	_room_host.add_child(instance)
	return instance
