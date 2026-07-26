extends Node

const RunMap := preload("res://core/run_map.gd")
const MapGenerator := preload("res://core/map_generator.gd")
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")
const MapOverlayScene := preload("res://ui/map_overlay.tscn")
const FloorRouteScene := preload("res://ui/floor_route_overlay.tscn")
const HUDScene := preload("res://ui/hud.tscn")
const TitleScene := preload("res://ui/title.tscn")
const GrateCostOverlayScene := preload("res://ui/grate_cost_overlay.tscn")
const Exp01Scene := preload("res://actors/enemies/exp01_centipede.tscn")
const Exp02Scene := preload("res://actors/enemies/exp02_spider.tscn")
const Exp03Scene := preload("res://actors/enemies/exp03_saurian.tscn")
const Exp07Scene := preload("res://actors/enemies/exp07_crustacean.tscn")
const MainScene := preload("res://game/main.tscn")
const RunSummaryScene := preload("res://ui/run_summary.tscn")

var _frames := 0
var _min_frames := 12
var _output_path := ""
var _target_size := Vector2i.ZERO
var _mode := ""
var _exp07_sprite: AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "map"
	_mode = mode
	_output_path = args[1] if args.size() > 1 else "user://ui_capture.png"
	if args.size() > 2:
		var dimensions := args[2].split("x")
		if dimensions.size() == 2:
			_target_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_prepare_fixture(mode)
	match mode:
		"title_intro":
			var title: Control = TitleScene.instantiate()
			add_child(title)
			title.set_process_unhandled_input(false)
		"title_menu":
			var title: Control = TitleScene.instantiate()
			add_child(title)
			title.set_process_unhandled_input(false)
			title.skip_intro()
		"tutorial":
			_prepare_tutorial_room()
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
		"grate":
			_prepare_grate_room()
		"exp07_attack":
			_prepare_exp07_attack()
		"enemies":
			_prepare_enemy_lineup()
		"lighting":
			_prepare_lighting()
		"boss":
			_prepare_boss_room()
		"summary":
			_prepare_summary(args)
		_:
			var overlay: Control = MapOverlayScene.instantiate()
			add_child(overlay)
			overlay.visible = true
			overlay.get_node("BodyPanel").call("select_first_equipped")


func _prepare_tutorial_room() -> void:
	$Background.visible = false
	GameState.reset_run()
	Inventory.reset_run()
	var run_map: RefCounted = MapGenerator.new().generate(1785033756)
	assert(run_map != null, "la seed visual debe generar Contención")
	RunManager.current_map = run_map
	RunManager.current_seed = 1785033756
	RunManager.active = true
	GameState.current_room = run_map.entry_room_id
	GameState.visited[run_map.entry_room_id] = true
	var room: Node2D = RoomAssembler.build(run_map.room(run_map.entry_room_id))
	add_child(room)


func _prepare_summary(args: PackedStringArray) -> void:
	$Background.visible = false
	# La animación de entrada dura ~0,5 s: capturamos con el estado ya asentado.
	_min_frames = 60
	var reason: StringName = StringName(args[3]) if args.size() > 3 else &"death"
	var summary_ui: Control = RunSummaryScene.instantiate()
	add_child(summary_ui)
	RunManager.start_new_run(5150)
	GameState.visited[RunManager.current_map.entry_room_id] = true
	RunManager.end_run(reason)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < _min_frames:
		return
	if _mode == "exp07_attack" and (
		_exp07_sprite == null
		or _exp07_sprite.animation != &"pinch_windup"
		or _exp07_sprite.frame < 4
	):
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


func _prepare_grate_room() -> void:
	$Background.visible = false
	var room: Node2D = RoomAssembler.build(RunManager.current_map.room("CENTER"))
	add_child(room)
	var grate: Area2D = room.get_node("Grate") as Area2D
	grate.get_node("Prompt").visible = true
	var overlay: Control = GrateCostOverlayScene.instantiate()
	add_child(overlay)
	overlay.open("CENTER", "GRATE")
	assert(overlay.visible, "el selector de rejilla debe permanecer abierto")
	assert(overlay.selected_option == 0, "la primera parte debe quedar resaltada")
	assert(GameState.current_room == "CENTER", "la captura no debe viajar por la rejilla")


func _prepare_exp07_attack() -> void:
	var enemy: CharacterBody2D = Exp07Scene.instantiate()
	enemy.position = Vector2(960.0, 540.0)
	add_child(enemy)
	enemy.set_physics_process(false)
	var states: Dictionary = enemy.get_script().get_script_constant_map().get("State", {})
	assert(states.has("PINCH_WINDUP"), "EXP07 debe declarar el estado de aviso")
	enemy.set("_state", states["PINCH_WINDUP"])
	_exp07_sprite = enemy.get_node("Sprite") as AnimatedSprite2D
	_exp07_sprite.play(&"pinch_windup")


# Fila de control del arte de Contención: cada experimento aparece en su pose de
# locomoción y en la de aviso, que son las dos que el jugador tiene que
# distinguir. La IA queda congelada para que la captura sea reproducible.
func _prepare_enemy_lineup() -> void:
	var lineup: Array[Array] = [
		[Exp01Scene, "APPROACH", "WINDUP"],
		[Exp02Scene, "REPOSITION", "SLAM_WINDUP"],
		[Exp03Scene, "WALK", "TAIL_WINDUP"],
		[Exp07Scene, "ADVANCE", "PINCH_WINDUP"],
	]
	for column in range(lineup.size()):
		var entry: Array = lineup[column]
		for row in range(2):
			var enemy: CharacterBody2D = entry[0].instantiate()
			enemy.position = Vector2(420.0 + 360.0 * float(column), 380.0 + 340.0 * float(row))
			add_child(enemy)
			enemy.set_physics_process(false)
			var states: Dictionary = enemy.get_script().get_script_constant_map().get("State", {})
			var wanted: String = entry[row + 1]
			assert(states.has(wanted), "%s debe declarar el estado %s" % [enemy.name, wanted])
			enemy.set("_state", states[wanted])
			var sprite := enemy.get_node("Sprite") as AnimatedSprite2D
			sprite.play(enemy.call("_visual_state"))
			# El último fotograma del aviso es el que tiene que verse antes del
			# golpe: la captura lo fuerza para poder compararlo con la locomoción.
			if row == 1:
				sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) - 1


func _prepare_lighting() -> void:
	$Background.visible = false
	RunManager.start_new_run(1785033756)
	var main: Node2D = MainScene.instantiate()
	add_child(main)


func _prepare_boss_room() -> void:
	$Background.visible = false
	# Angry alcanza su postura de embestida cerca del frame 8.
	_min_frames = 60
	GameState.reset_run()
	var map := RunMap.new(9001, 0)
	map.add_room("BOSS", Vector2i.ZERO, &"boss_choice", &"boss_choice")
	map.boss_room_id = "BOSS"
	RunManager.current_map = map
	RunManager.active = true
	GameState.current_room = "BOSS"
	GameState.visited["BOSS"] = true

	var player := Node2D.new()
	player.name = "PlayerTarget"
	player.position = Vector2(960, 540)
	player.add_to_group("player")
	add_child(player)
	var room: Node2D = RoomAssembler.build(map.room("BOSS"))
	add_child(room)
	var boss := room.get_node("BossCore") as CharacterBody2D
	boss.set_physics_process(false)
	boss.position = Vector2(330, 270)
	boss.call("_enter_corner_aim")
	boss.call("_update_sprite_animation")


func _prepare_fixture(mode: String) -> void:
	GameState.reset_run()
	Inventory.reset_run()
	var map := RunMap.new(1080, 0)
	map.add_room("CENTER", Vector2i.ZERO, &"entry", &"empty")
	map.add_room("N", Vector2i.UP, &"normal", &"easy")
	map.add_room("E", Vector2i.RIGHT, &"normal", &"loot")
	map.add_room("S", Vector2i.DOWN, &"normal", &"hard")
	map.add_room("O", Vector2i.LEFT, &"normal", &"closure")
	map.connect_rooms("CENTER", "N", &"N")
	map.connect_rooms("CENTER", "S", &"S")
	map.connect_rooms("CENTER", "O", &"O")
	if mode == "grate":
		map.add_room("GRATE", Vector2i.RIGHT, &"grate_destination", &"loot")
		map.set_grate("CENTER", "GRATE", &"E")
	else:
		map.connect_rooms("CENTER", "E", &"E")
	map.entry_room_id = "CENTER"
	RunManager.current_map = map
	RunManager.current_seed = 1080
	RunManager.active = true
	GameState.current_room = "CENTER"
	GameState.visited["CENTER"] = true
	GameState.discover_grate("CENTER")
	var part_ids: Array[String] = [
		"serrated_jaw",
		"mycelium_hand",
	]
	if mode != "grate":
		part_ids = [
			"serrated_jaw",
			"mycelium_hand",
			"crusher_claw",
			"scaled_skin",
			"whip_tail",
			"acid_stinger",
		]
	for part_id: String in part_ids:
		Inventory.pick_up(part_id)
	GameState.gain_ability("dash")
