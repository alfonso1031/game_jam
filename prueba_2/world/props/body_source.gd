extends Node2D

const PartPickupScene := preload("res://world/props/part_pickup.tscn")

var _room_id := ""
var _reward_part_id := ""


func configure(room_id: String, reward_part_id: String) -> void:
	_room_id = room_id
	_reward_part_id = reward_part_id


func _ready() -> void:
	if _room_id.is_empty() or _reward_part_id.is_empty():
		return
	if GameState.is_room_reward_claimed(_room_id):
		return
	var pickup: Area2D = PartPickupScene.instantiate()
	pickup.name = "PartPickup"
	pickup.part_id = _reward_part_id
	pickup.position = Vector2(110.0, 0.0)
	pickup.collected.connect(_on_collected)
	add_child(pickup)


func _on_collected(_part_id: String) -> void:
	GameState.claim_room_reward(_room_id)
