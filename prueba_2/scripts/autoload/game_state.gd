extends Node

signal room_changed(room_id: String)
signal ability_gained(id: String)

var current_room: String = ""
var visited: Dictionary = {}
var abilities: Dictionary = {}
var max_health: int = 3
var health: int = 3

func has_ability(id: String) -> bool:
	return abilities.has(id)
