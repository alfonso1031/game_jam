extends Control

const Palette := preload("res://core/palette.gd")

const HEALTH_RADIUS := 14.0
const HEALTH_GAP := 36.0
const HEALTH_ORIGIN := Vector2(40, 40)

const MINIMAP_PANEL := Rect2(1660, 20, 240, 180)
const MINIMAP_MAX_CELL := 42.0

const ABILITY_ORIGIN := Vector2(40, 300)
const ABILITY_SIZE := 56.0
const ABILITY_GAP := 84.0
const ABILITY_IDS := ["dash"]

@onready var level_label: Label = $LevelLabel
@onready var room_label: Label = $RoomLabel

func _ready() -> void:
	GameState.room_changed.connect(_on_room_changed)
	GameState.ability_gained.connect(_on_ability_gained)
	GameState.health_changed.connect(_on_health_changed)
	queue_redraw()

func _on_health_changed(_health: int) -> void:
	queue_redraw()

func _on_room_changed(_room_id: String) -> void:
	_refresh_labels()
	queue_redraw()

func _on_ability_gained(_id: String) -> void:
	queue_redraw()

func _refresh_labels() -> void:
	var room_data: Dictionary = RoomDB.ROOMS[GameState.current_room]
	level_label.text = "NIVEL %d · %s" % [room_data["level"], room_data["level_name"]]
	room_label.text = room_data["room_name"]

func _draw() -> void:
	if GameState.current_room == "":
		return
	_draw_health()
	_draw_minimap()
	_draw_abilities()

func _draw_health() -> void:
	for i in range(GameState.max_health):
		var pos: Vector2 = HEALTH_ORIGIN + Vector2(i * HEALTH_GAP, 0)
		if i < GameState.health:
			draw_circle(pos, HEALTH_RADIUS, Palette.SLIME_BODY)
		else:
			draw_arc(pos, HEALTH_RADIUS, 0.0, TAU, 24, Palette.VOID, 2.0)

func _draw_minimap() -> void:
	draw_rect(MINIMAP_PANEL, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.75), true)
	draw_rect(MINIMAP_PANEL, Palette.WALL, false, 2.0)

	var current_data: Dictionary = RoomDB.ROOMS[GameState.current_room]
	var level: int = current_data["level"]

	var min_x := 999
	var max_x := -999
	var min_y := 999
	var max_y := -999
	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		if data["level"] != level:
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

	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		if data["level"] != level:
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

func _draw_abilities() -> void:
	var font := ThemeDB.fallback_font
	var panel_height: float = 46.0 + ABILITY_IDS.size() * ABILITY_GAP
	var panel_width: float = max(ABILITY_SIZE + 32.0, 150.0)
	var panel := Rect2(ABILITY_ORIGIN + Vector2(-16, -40), Vector2(panel_width, panel_height))
	draw_rect(panel, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.75), true)
	draw_rect(panel, Palette.WALL, false, 2.0)
	draw_string(font, panel.position + Vector2(0, 24), "HABILIDADES", HORIZONTAL_ALIGNMENT_CENTER, panel_width, 15, Palette.WARM_LIGHT)

	var slot_x: float = panel.position.x + (panel_width - ABILITY_SIZE) * 0.5
	for i in range(ABILITY_IDS.size()):
		var id: String = ABILITY_IDS[i]
		var pos := Vector2(slot_x, ABILITY_ORIGIN.y + i * ABILITY_GAP)
		var rect := Rect2(pos, Vector2(ABILITY_SIZE, ABILITY_SIZE))
		if GameState.has_ability(id):
			draw_rect(rect, Palette.SLIME_CORE, true)
		else:
			draw_rect(rect, Palette.WALL, false, 2.0)
		draw_string(font, Vector2(panel.position.x, pos.y + ABILITY_SIZE + 18), id.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, panel_width, 14, Palette.WARM_LIGHT)
