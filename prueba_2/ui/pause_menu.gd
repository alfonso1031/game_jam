extends Control

@onready var resume_button: Button = $Panel/Box/Resume
@onready var restart_button: Button = $Panel/Box/Restart
@onready var title_button: Button = $Panel/Box/ToTitle
@onready var quit_button: Button = $Panel/Box/Quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_close)
	restart_button.pressed.connect(_restart)
	title_button.pressed.connect(_to_title)
	quit_button.pressed.connect(_quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		get_viewport().set_input_as_handled()
		_close()
	elif not get_tree().paused:
		# Si ya está pausado, lo pausó el mapa: que se cierre él con su propio Esc.
		get_viewport().set_input_as_handled()
		_open()

func _open() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _restart() -> void:
	get_tree().paused = false
	RunManager.start_new_run()
	get_tree().reload_current_scene()

func _to_title() -> void:
	get_tree().paused = false
	RunManager.active = false
	GameState.reset_run()
	Inventory.reset_run()
	get_tree().change_scene_to_file("res://ui/title.tscn")

func _quit() -> void:
	get_tree().quit()
