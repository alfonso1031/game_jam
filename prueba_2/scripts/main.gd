extends Node2D

func _ready() -> void:
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	Transition.load_initial("L3_CELDA")
