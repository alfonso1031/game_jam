extends Node2D

const START_ROOM := "L3_CELDA"

func _ready() -> void:
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	GameState.died.connect(_on_died)
	Transition.load_initial(START_ROOM)

func _on_died() -> void:
	GameState.reset_health()
	var room_id := GameState.checkpoint_room
	if room_id == "":
		room_id = START_ROOM
	Transition.respawn(room_id, GameState.checkpoint_spawn)
