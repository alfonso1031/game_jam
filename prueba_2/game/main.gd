extends Node2D

const START_ROOM := "L3_CELDA"

func _ready() -> void:
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	GameState.died.connect(_on_died)
	Transition.load_initial(START_ROOM)

func _on_died() -> void:
	GameState.reset_health()
	Transition.respawn(START_ROOM)
