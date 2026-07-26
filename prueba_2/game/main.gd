extends Node2D

@onready var music: AudioStreamPlayer = $Music
@onready var floor_route: Control = $RouteLayer/FloorRouteOverlay


func _ready() -> void:
	music.finished.connect(_on_music_finished)
	Transition.setup($RoomHost, $Player, $FadeLayer/Fade)
	GameState.died.connect(_on_died)
	floor_route.dismissed.connect(_on_route_dismissed)
	if not RunManager.active or RunManager.current_map == null:
		RunManager.start_new_run()
	Transition.load_initial(RunManager.current_map.entry_room_id)

func _on_died() -> void:
	RunManager.end_run(&"death")


func _on_route_dismissed(floor_id: StringName) -> void:
	# Contención es el único piso jugable: superarlo es la fuga, y ahí acaba la partida.
	if floor_id == &"contencion":
		RunManager.end_run(&"escape")


func _on_music_finished() -> void:
	music.play()
