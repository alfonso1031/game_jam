extends Node

const RunMap := preload("res://core/run_map.gd")
const MapOverlayScene := preload("res://ui/map_overlay.tscn")
const FloorRouteScene := preload("res://ui/floor_route_overlay.tscn")
const HUDScene := preload("res://ui/hud.tscn")

var _frames := 0
var _output_path := ""
var _target_size := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "map"
	_output_path = args[1] if args.size() > 1 else "user://ui_capture.png"
	if args.size() > 2:
		var dimensions := args[2].split("x")
		if dimensions.size() == 2:
			_target_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_prepare_fixture()
	match mode:
		"route":
			var route: Control = FloorRouteScene.instantiate()
			add_child(route)
			RunManager.floor_completed.emit(&"contencion", 2)
		"hud":
			var hud: Control = HUDScene.instantiate()
			add_child(hud)
		"tooltip":
			var overlay: Control = MapOverlayScene.instantiate()
			add_child(overlay)
			overlay.visible = true
			await get_tree().process_frame
			overlay.get_node("BodyPanel/PartTooltip").show_part(
				"mycelium_hand",
				Vector2(1900.0, 1060.0)
			)
		_:
			var overlay: Control = MapOverlayScene.instantiate()
			add_child(overlay)
			overlay.visible = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 12:
		return
	var image := get_viewport().get_texture().get_image()
	# Con stretch `canvas_items`, Godot compone en el viewport lógico de 1080p
	# y después escala a la ventana. Guardamos el tamaño físico final para que
	# la evidencia de 1280×720 represente lo que realmente ve el jugador.
	var output_size := (
		_target_size
		if _target_size.x > 0 and _target_size.y > 0
		else DisplayServer.window_get_size()
	)
	if output_size.x > 0 and output_size.y > 0 and image.get_size() != output_size:
		image.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(_output_path)
	if error == OK:
		print("UI_CAPTURE_OK %s %dx%d" % [
			_output_path,
			image.get_width(),
			image.get_height(),
		])
	else:
		push_error("No se pudo guardar la captura: %s" % error_string(error))
	get_tree().paused = false
	get_tree().quit(0 if error == OK else 1)


func _prepare_fixture() -> void:
	GameState.reset_run()
	Inventory.reset_run()
	var map := RunMap.new(1080, 0)
	map.add_room("CENTER", Vector2i.ZERO, &"entry", &"empty")
	map.add_room("N", Vector2i.UP, &"normal", &"easy")
	map.add_room("E", Vector2i.RIGHT, &"normal", &"loot")
	map.add_room("S", Vector2i.DOWN, &"normal", &"hard")
	map.add_room("O", Vector2i.LEFT, &"normal", &"closure")
	map.add_room("GRATE", Vector2i(2, 0), &"grate_destination", &"loot")
	map.connect_rooms("CENTER", "N", &"N")
	map.connect_rooms("CENTER", "E", &"E")
	map.connect_rooms("CENTER", "S", &"S")
	map.connect_rooms("CENTER", "O", &"O")
	map.set_grate("CENTER", "GRATE")
	map.entry_room_id = "CENTER"
	RunManager.current_map = map
	RunManager.current_seed = 1080
	RunManager.active = true
	GameState.current_room = "CENTER"
	GameState.visited["CENTER"] = true
	GameState.discover_grate("CENTER")
	for part_id in [
		"serrated_jaw",
		"mycelium_hand",
		"crusher_claw",
		"scaled_skin",
		"whip_tail",
		"acid_stinger",
	]:
		Inventory.pick_up(part_id)
	GameState.gain_ability("dash")
