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

func _ready() -> void:
	# Debe seguir escuchando el toggle de pantalla completa con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("fullscreen"):
		return
	var windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED
	)
	get_viewport().set_input_as_handled()

func has_ability(id: String) -> bool:
	return abilities.has(id)

func reset_run() -> void:
	current_room = ""
	visited.clear()
	abilities.clear()
	bosses_defeated.clear()
	health = max_health

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
