extends Node

signal room_changed(room_id: String)
signal ability_gained(id: String)
signal health_changed(health: int)
signal died

var current_room: String = ""
var visited: Dictionary = {}
var abilities: Dictionary = {}
var bosses_defeated: Dictionary = {}
var max_health: int = 5
var health: int = 5

func has_ability(id: String) -> bool:
	return abilities.has(id)

func gain_ability(id: String) -> void:
	if abilities.has(id):
		return
	abilities[id] = true
	ability_gained.emit(id)

func damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health)
	if health <= 0:
		died.emit()

func reset_health() -> void:
	health = max_health
	health_changed.emit(health)
