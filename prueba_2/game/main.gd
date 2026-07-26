extends Node2D

func _ready() -> void:
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	GameState.died.connect(_on_died)
	RunManager.start_new_run()
	Transition.load_initial(RunManager.current_map.entry_room_id)

func _on_died() -> void:
	RunManager.end_run(&"death")
