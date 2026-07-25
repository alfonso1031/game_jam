extends Area2D

@export var target_room: String
@export var target_spawn: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("world", "change_room", target_room, target_spawn)
