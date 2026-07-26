extends Control

const Palette := preload("res://core/palette.gd")

const MINIMAP_PANEL := Rect2(1660, 20, 240, 180)
const MINIMAP_MAX_CELL := 42.0
const HEALTH_FILL_WIDTH := 356.0

@onready var health_fill: ColorRect = $Health/Fill
@onready var health_value: Label = $Health/Value

func _ready() -> void:
	GameState.room_changed.connect(_on_room_changed)
	GameState.health_changed.connect(_on_health_changed)
	_refresh_health()
	queue_redraw()

func _on_health_changed(_health: int) -> void:
	_refresh_health()

func health_ratio() -> float:
	if GameState.max_health_halves <= 0:
		return 0.0
	return clampf(
		float(GameState.health_halves) / float(GameState.max_health_halves),
		0.0,
		1.0
	)

func _refresh_health() -> void:
	health_value.text = "%d / %d HP" % [
		GameState.health_halves,
		GameState.max_health_halves,
	]
	health_fill.size.x = HEALTH_FILL_WIDTH * health_ratio()

func _on_room_changed(_room_id: String) -> void:
	queue_redraw()

func _draw() -> void:
	if GameState.current_room == "":
		return
	_draw_minimap()

func _draw_minimap() -> void:
	draw_rect(MINIMAP_PANEL, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.75), true)
	draw_rect(MINIMAP_PANEL, Palette.WALL, false, 2.0)
	draw_line(
		MINIMAP_PANEL.position + Vector2(10, 28),
		MINIMAP_PANEL.position + Vector2(MINIMAP_PANEL.size.x - 10, 28),
		Color(Palette.WALL, 0.45),
		1.0
	)
	draw_string(
		ThemeDB.fallback_font,
		MINIMAP_PANEL.position + Vector2(12, 21),
		"CONTENCIÓN / MAPA",
		HORIZONTAL_ALIGNMENT_LEFT,
		MINIMAP_PANEL.size.x - 24.0,
		13,
		Color(Palette.SLIME_CORE, 0.85)
	)

	var rooms: Dictionary = _active_rooms()
	var visible_ids := visible_room_ids()
	if visible_ids.is_empty():
		return
	var current_data: Dictionary = _current_room_data()
	var level: int = int(current_data.get("level", -3))
	var procedural: bool = (
		RunManager.current_map != null
		and rooms == RunManager.current_map.rooms
	)

	var min_x := 999
	var max_x := -999
	var min_y := 999
	var max_y := -999
	for room_id: String in visible_ids:
		var data: Dictionary = rooms[room_id]
		if not procedural and int(data.get("level", -3)) != level:
			continue
		var grid: Vector2i = data["grid"]
		min_x = min(min_x, grid.x)
		max_x = max(max_x, grid.x)
		min_y = min(min_y, grid.y)
		max_y = max(max_y, grid.y)

	var cols := max_x - min_x + 1
	var rows := max_y - min_y + 1
	var padding := 20.0
	var cell: float = min((MINIMAP_PANEL.size.x - padding * 2) / cols, (MINIMAP_PANEL.size.y - padding * 2) / rows)
	cell = min(cell, MINIMAP_MAX_CELL)
	var origin: Vector2 = MINIMAP_PANEL.position + (MINIMAP_PANEL.size - Vector2(cols, rows) * cell) * 0.5

	for room_id: String in visible_ids:
		var data: Dictionary = rooms[room_id]
		if not procedural and int(data.get("level", -3)) != level:
			continue
		var grid: Vector2i = data["grid"]
		var pos: Vector2 = origin + Vector2(grid.x - min_x, grid.y - min_y) * cell
		var cell_size := Vector2(cell - 6.0, cell - 6.0)
		var color: Color = Palette.VOID
		if room_id == GameState.current_room:
			color = Palette.SLIME_CORE
		elif GameState.visited.get(room_id, false):
			color = Palette.WALL
		draw_rect(Rect2(pos, cell_size), color, true)
		draw_rect(Rect2(pos, cell_size), Palette.FLOOR, false, 1.0)


func visible_room_ids() -> Array[String]:
	var result: Array[String] = []
	var rooms := _active_rooms()
	for room_id: String in GameState.visited:
		if GameState.visited[room_id] and rooms.has(room_id):
			result.append(room_id)
	result.sort()
	return result


func _active_rooms() -> Dictionary:
	if (
		RunManager.current_map != null
		and RunManager.current_map.rooms.has(GameState.current_room)
	):
		return RunManager.current_map.rooms
	return RoomDB.ROOMS


func _current_room_data() -> Dictionary:
	return _active_rooms().get(GameState.current_room, {})
