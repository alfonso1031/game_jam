extends Node2D

const ROOMS := {
	"lab": preload("res://scenes/rooms/room_lab.tscn"),
	"hall": preload("res://scenes/rooms/room_hall.tscn"),
	"storage": preload("res://scenes/rooms/room_storage.tscn"),
}

@onready var room_holder: Node2D = $YSortRoot/RoomHolder
@onready var player: CharacterBody2D = $YSortRoot/Player
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

var current_room: Node2D
var _changing := false

func _ready() -> void:
	add_to_group("world")
	fade_rect.color = Color(0, 0, 0, 0)
	_load_room("lab", "Start")

func change_room(room_id: String, spawn_name: String) -> void:
	if _changing:
		return
	_changing = true
	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await tween_out.finished
	_load_room(room_id, spawn_name)
	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "color:a", 0.0, 0.25)
	await tween_in.finished
	_changing = false

func _load_room(room_id: String, spawn_name: String) -> void:
	if current_room:
		current_room.queue_free()
	var scene: PackedScene = ROOMS[room_id]
	current_room = scene.instantiate()
	room_holder.add_child(current_room)
	var spawn := current_room.find_child(spawn_name, true, false)
	if spawn:
		player.global_position = spawn.global_position
