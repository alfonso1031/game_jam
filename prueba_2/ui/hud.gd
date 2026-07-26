extends Control

const Palette := preload("res://core/palette.gd")

const HEALTH_RADIUS := 14.0
const HEALTH_GAP := 36.0
const HEALTH_ORIGIN := Vector2(40, 40)

const MINIMAP_PANEL := Rect2(1660, 20, 240, 180)
const MINIMAP_MAX_CELL := 42.0

@onready var level_label: Label = $LevelLabel
@onready var room_label: Label = $RoomLabel

func _ready() -> void:
	GameState.room_changed.connect(_on_room_changed)
	GameState.health_changed.connect(_on_health_changed)
	queue_redraw()

func _on_health_changed(_health: int) -> void:
	queue_redraw()

func _on_room_changed(_room_id: String) -> void:
	_refresh_labels()
	queue_redraw()

func _refresh_labels() -> void:
	var room_data: Dictionary = _current_room_data()
	if room_data.is_empty():
		return
	var level: int = int(room_data.get("level", -3))
	var level_name: String = String(room_data.get("level_name", "CONTENCIÓN"))
	level_label.text = "NIVEL %d · %s" % [level, level_name]
	if room_data.has("room_name"):
		room_label.text = room_data["room_name"]
	else:
		var role: String = String(room_data.get("role", &"normal"))
		var content: String = String(room_data.get("content_type", &"empty"))
		room_label.text = "%s · %s" % [role.capitalize(), content.capitalize()]

func _draw() -> void:
	if GameState.current_room == "":
		return
	_draw_health()
	_draw_minimap()

func _draw_health() -> void:
	# La vida se lleva en medios corazones: consumir una parte cura exactamente
	# medio, así que el HUD tiene que poder mostrar mitades.
	var hearts: int = ceili(float(GameState.max_health_halves) / 2.0)
	for i in range(hearts):
		var pos: Vector2 = HEALTH_ORIGIN + Vector2(i * HEALTH_GAP, 0)
		var filled: int = clampi(GameState.health_halves - i * 2, 0, 2)
		draw_arc(pos, HEALTH_RADIUS, 0.0, TAU, 24, Palette.VOID, 2.0)
		if filled == 2:
			draw_circle(pos, HEALTH_RADIUS, Palette.SLIME_BODY)
		elif filled == 1:
			# Media luna izquierda: se lee de un vistazo aunque sea diminuta.
			var points: PackedVector2Array = []
			for step in range(13):
				var angle: float = PI / 2.0 + PI * float(step) / 12.0
				points.append(pos + Vector2.RIGHT.rotated(angle) * HEALTH_RADIUS)
			points.append(pos)
			draw_colored_polygon(points, Palette.SLIME_BODY)
		draw_arc(pos, HEALTH_RADIUS, 0.0, TAU, 24, Palette.WALL, 2.0)

func _draw_minimap() -> void:
	draw_rect(MINIMAP_PANEL, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.75), true)
	draw_rect(MINIMAP_PANEL, Palette.WALL, false, 2.0)

	var rooms: Dictionary = _active_rooms()
	var current_data: Dictionary = _current_room_data()
	var level: int = int(current_data.get("level", -3))
	var procedural := (
		RunManager.current_map != null
		and rooms == RunManager.current_map.rooms
	)

	var min_x := 999
	var max_x := -999
	var min_y := 999
	var max_y := -999
	for room_id in rooms:
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

	for room_id in rooms:
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


func _active_rooms() -> Dictionary:
	if (
		RunManager.current_map != null
		and RunManager.current_map.rooms.has(GameState.current_room)
	):
		return RunManager.current_map.rooms
	return RoomDB.ROOMS


func _current_room_data() -> Dictionary:
	return _active_rooms().get(GameState.current_room, {})
