extends Node2D

# Herramienta de desarrollo: carga una sala sola (sin jugador) con la misma
# oscuridad que usa `main.tscn`, espera unos frames para que las luces se
# asienten y vuelca un PNG del viewport. Se lanza con:
#   godot --path <proyecto> res://tests/screenshot_room.tscn -- <ROOM_ID> <salida.png>
# (sin --headless: hace falta un contexto de render real para que las luces
# 2D compongan).

const SlimeScene := preload("res://actors/player/slime.tscn")

@onready var host: Node2D = $RoomHost
@onready var darkness: CanvasModulate = $Darkness

var _frames := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var room_id: String = args[0] if args.size() > 0 else "L3_PASILLO"
	var out_path: String = args[1] if args.size() > 1 else "user://screenshot.png"

	if args.size() > 2 and args[2] == "nodim":
		darkness.color = Color(1, 1, 1, 1)
	else:
		darkness.color = Color(0.09, 0.1, 0.12, 1.0)

	var room_data: Dictionary = RoomDB.ROOMS[room_id]
	var scene: PackedScene = load(room_data["scene"])
	var instance: Node = scene.instantiate()
	instance.name = room_id
	host.add_child(instance)
	var bg: Sprite2D = instance.get_node_or_null("Background")
	if bg != null:
		print("BACKGROUND_TEXTURE ", bg.texture.resource_path)

	# Un slime quieto en el centro, solo para ver su luz propia en la captura.
	if args.size() > 3 and args[3] == "slime":
		var slime: Node2D = SlimeScene.instantiate()
		slime.position = Vector2(960, 540)
		host.add_child(slime)

	set_meta("out_path", out_path)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 12:
		return
	var image := get_viewport().get_texture().get_image()
	var out_path: String = get_meta("out_path")
	image.save_png(out_path)
	print("SCREENSHOT_OK ", out_path)
	get_tree().quit()
