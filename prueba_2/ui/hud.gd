extends Control

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

const HEALTH_RADIUS := 14.0
const HEALTH_GAP := 36.0
const HEALTH_ORIGIN := Vector2(40, 40)

const MINIMAP_PANEL := Rect2(1660, 20, 240, 180)
const MINIMAP_MAX_CELL := 42.0

const ABILITY_ORIGIN := Vector2(40, 110)
const ABILITY_SIZE := 56.0
const ABILITY_GAP := 84.0
const ABILITY_IDS := ["dash"]

# Tira de partes: seis huecos en columna, con la tecla que los dispara.
const SLOT_ORIGIN := Vector2(40, 300)
const SLOT_SIZE := Vector2(230, 62)
const SLOT_GAP := 8.0

@onready var level_label: Label = $LevelLabel
@onready var room_label: Label = $RoomLabel

func _ready() -> void:
	GameState.room_changed.connect(_on_room_changed)
	GameState.ability_gained.connect(_on_ability_gained)
	GameState.health_changed.connect(_on_health_changed)
	Inventory.slots_changed.connect(queue_redraw)
	Inventory.pending_changed.connect(_on_pending_changed)
	queue_redraw()

func _process(_delta: float) -> void:
	# Las recargas cambian cada frame; redibujar el HUD entero es barato porque
	# es todo geometría plana.
	queue_redraw()

func _on_pending_changed(_part_id: String) -> void:
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
	_draw_part_slots()

func _draw_health() -> void:
	# La vida se lleva en medios corazones: consumir una parte cura exactamente
	# medio, así que el HUD tiene que poder mostrar mitades.
	var hearts: int = GameState.max_health_halves / 2
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

func _draw_part_slots() -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2(
		SLOT_ORIGIN - Vector2(14, 42),
		Vector2(SLOT_SIZE.x + 28, 54 + Inventory.SLOT_COUNT * (SLOT_SIZE.y + SLOT_GAP))
	)
	draw_rect(panel, Color(Palette.VOID, 0.75), true)
	draw_rect(panel, Palette.WALL, false, 2.0)
	draw_string(font, panel.position + Vector2(0, 26), "PARTES  [I]", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Palette.WARM_LIGHT)

	for i in range(Inventory.SLOT_COUNT):
		var rect := Rect2(SLOT_ORIGIN + Vector2(0, i * (SLOT_SIZE.y + SLOT_GAP)), SLOT_SIZE)
		var id := Inventory.part_at(i)
		draw_rect(rect, Color(Palette.FLOOR, 0.5 if id != "" else 0.2), true)

		# La recarga se vacía de abajo hacia arriba sobre el propio hueco.
		var ratio := Inventory.cooldown_ratio(i)
		if ratio > 0.0:
			var height: float = rect.size.y * ratio
			draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - height), Vector2(rect.size.x, height)), Color(Palette.VOID, 0.7), true)

		draw_rect(rect, Palette.WALL, false, 2.0)
		draw_string(font, rect.position + Vector2(10, 24), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 24, 18, Palette.WARM_LIGHT)
		draw_string(font, rect.position + Vector2(34, 24), Inventory.slot_label(i), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44, 15, Palette.WALL.lightened(0.4))

		if id == "":
			continue
		var color: Color = Palette.WARM_LIGHT if PartsDB.is_boss_part(id) else Palette.SLIME_CORE
		draw_string(font, rect.position + Vector2(10, 50), PartsDB.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 17, color)

	if Inventory.pending == "":
		return
	var warn := Rect2(SLOT_ORIGIN + Vector2(0, Inventory.SLOT_COUNT * (SLOT_SIZE.y + SLOT_GAP) + 6), Vector2(SLOT_SIZE.x, 40))
	draw_rect(warn, Color(Palette.WARM_LIGHT, 0.22), true)
	draw_rect(warn, Palette.WARM_LIGHT, false, 2.0)
	draw_string(font, warn.position + Vector2(0, 26), "PENDIENTE · [I]", HORIZONTAL_ALIGNMENT_CENTER, warn.size.x, 18, Palette.WARM_LIGHT)
