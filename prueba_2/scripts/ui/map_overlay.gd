extends Control

const Palette := preload("res://scripts/core/palette.gd")

const BASE_Y := 900.0
const LEVEL_GAP := 220.0
const CELL := 90.0
const NODE_RADIUS := 22.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		# Si ya está pausado por otro overlay (pausa, final), no abrir el mapa encima.
		if not visible and get_tree().paused:
			return
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible:
		return

	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0.192157, 0.211765, 0.219608, 0.92), true)

	var levels: Array = []
	for room_id in RoomDB.ROOMS:
		var lvl: int = RoomDB.ROOMS[room_id]["level"]
		if not levels.has(lvl):
			levels.append(lvl)
	levels.sort()

	var level_row_y := {}
	for i in range(levels.size()):
		level_row_y[levels[i]] = BASE_Y - i * LEVEL_GAP

	var font := ThemeDB.fallback_font

	for lvl in levels:
		var y: float = level_row_y[lvl]
		draw_string(font, Vector2(140, y + 8), "NIVEL %d" % lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.WARM_LIGHT)

	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		for dir in data["doors"]:
			var target_id: String = data["doors"][dir]
			var a: Vector2 = _room_map_pos(room_id, level_row_y)
			var b: Vector2 = _room_map_pos(target_id, level_row_y)
			draw_line(a, b, Palette.WALL, 3.0)

	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		var pos: Vector2 = _room_map_pos(room_id, level_row_y)
		var color: Color = Palette.VOID
		if room_id == GameState.current_room:
			color = Palette.SLIME_CORE
		elif GameState.visited.get(room_id, false):
			color = Palette.WALL
		draw_circle(pos, NODE_RADIUS, color)
		draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32, Palette.FLOOR, 2.0)
		if data.get("is_boss", false):
			draw_arc(pos, NODE_RADIUS + 8.0, 0.0, TAU, 32, Palette.WARM_LIGHT, 3.0)
		draw_string(font, pos + Vector2(-70, 40), data["room_name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Palette.WARM_LIGHT)

func _room_map_pos(room_id: String, level_row_y: Dictionary) -> Vector2:
	var data: Dictionary = RoomDB.ROOMS[room_id]
	var grid: Vector2i = data["grid"]
	var y: float = level_row_y[data["level"]]
	var x: float = 960.0 + grid.x * CELL
	return Vector2(x, y)
