extends Node2D

@onready var music: AudioStreamPlayer = $Music


func _ready() -> void:
	music.finished.connect(_on_music_finished)
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	GameState.died.connect(_on_died)
	if not RunManager.active or RunManager.current_map == null:
		RunManager.start_new_run()
	Transition.load_initial(RunManager.current_map.entry_room_id)

func _on_died() -> void:
	RunManager.end_run(&"death")


func _on_music_finished() -> void:
	music.play()
