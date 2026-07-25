extends Control

# Pantalla de [Tab]: cuerpo del slime con sus partes y habilidades alrededor a
# la izquierda, mapa del complejo a la derecha. Antes el mapa ocupaba toda la
# pantalla y las partes vivían siempre encima del HUD; ahora todo eso vive
# aquí, pausado, para no tapar la partida con información que no cambia
# segundo a segundo.
#
# Dibuja cada sala como el rectángulo que es de verdad, en su posición real de
# la rejilla, con las puertas en el lado por el que se sale.

const Palette := preload("res://core/palette.gd")
const EnemyDB := preload("res://core/enemy_db.gd")
const PartsDB := preload("res://core/parts_db.gd")

# Proporción de una sala real (1920 x 1080) reducida, encajada en la mitad
# derecha de la pantalla.
const ROOM_SIZE := Vector2(120.0, 66.0)
const ROOM_GAP := Vector2(16.0, 16.0)
const FLOOR_GAP := 50.0
const DOOR_LENGTH := 8.0
const DOOR_THICKNESS := 5.0
const MAP_CENTER_X := 1440.0

# El slime va en el centro de la mitad izquierda, con las partes y
# habilidades repartidas en un anillo a su alrededor.
const LEFT_CENTER := Vector2(480.0, 500.0)
const SLIME_RADIUS := 85.0
const RING_RADIUS := 300.0
const ITEM_SIZE := Vector2(190.0, 80.0)
const ABILITY_IDS := ["dash"]

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

	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(Palette.VOID, 0.94), true)

	var font := ThemeDB.fallback_font
	_draw_left_panel(font)

	var layout := _build_layout()

	# Primero los enlaces, para que queden por debajo de las salas.
	for room_id in RoomDB.ROOMS:
		if not _is_known(room_id):
			continue
		var data: Dictionary = RoomDB.ROOMS[room_id]
		for dir in data["doors"]:
			var target_id: String = data["doors"][dir]
			_draw_link(layout, room_id, target_id, dir)

	for room_id in RoomDB.ROOMS:
		if not _is_known(room_id):
			continue
		_draw_room(font, layout, room_id)

	_draw_floor_labels(font, layout)
	_draw_legend(font)

# --- Panel izquierdo: slime, partes y habilidades ---

func _draw_left_panel(font: Font) -> void:
	draw_string(font, Vector2(0, 70), "CUERPO", HORIZONTAL_ALIGNMENT_CENTER, 960.0, 28, Palette.WARM_LIGHT)

	draw_circle(LEFT_CENTER, SLIME_RADIUS, Palette.SLIME_BODY)
	draw_arc(LEFT_CENTER, SLIME_RADIUS, 0.0, TAU, 32, Palette.SLIME_CORE, 3.0)

	var entries: Array[Dictionary] = []
	for id in ABILITY_IDS:
		entries.append({"kind": "ability", "id": id})
	for i in range(Inventory.SLOT_COUNT):
		entries.append({"kind": "part", "index": i})

	var count: int = entries.size()
	var start_angle := -PI / 2.0
	for i in range(count):
		var angle: float = start_angle + TAU * float(i) / float(count)
		var center: Vector2 = LEFT_CENTER + Vector2(cos(angle), sin(angle)) * RING_RADIUS
		var rect := Rect2(center - ITEM_SIZE * 0.5, ITEM_SIZE)
		var entry: Dictionary = entries[i]
		if entry["kind"] == "ability":
			_draw_ability_slot(font, rect, entry["id"])
		else:
			_draw_part_slot(font, rect, entry["index"])

	if Inventory.pending != "":
		var text := "PENDIENTE · %s · [I] para equipar" % PartsDB.display_name(Inventory.pending)
		draw_string(font, Vector2(0, LEFT_CENTER.y + RING_RADIUS + 130.0), text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, 20, Palette.WARM_LIGHT)

func _draw_ability_slot(font: Font, rect: Rect2, id: String) -> void:
	var owned: bool = GameState.has_ability(id)
	draw_rect(rect, Color(Palette.SLIME_CORE, 0.35 if owned else 0.12), true)
	draw_rect(rect, Palette.SLIME_CORE if owned else Palette.WALL, false, 2.0)
	draw_string(font, rect.position + Vector2(10, 26), "HABILIDAD", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 13, Palette.WALL.lightened(0.4))
	draw_string(font, rect.position + Vector2(10, 56), id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 22, Palette.WARM_LIGHT if owned else Palette.WALL)

func _draw_part_slot(font: Font, rect: Rect2, index: int) -> void:
	var id := Inventory.part_at(index)
	draw_rect(rect, Color(Palette.FLOOR, 0.5 if id != "" else 0.18), true)

	# La recarga se vacía de abajo hacia arriba sobre el propio hueco.
	var ratio := Inventory.cooldown_ratio(index)
	if ratio > 0.0:
		var height: float = rect.size.y * ratio
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - height), Vector2(rect.size.x, height)), Color(Palette.VOID, 0.7), true)

	draw_rect(rect, Palette.WALL, false, 2.0)
	draw_string(font, rect.position + Vector2(10, 22), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24, 16, Palette.WALL.lightened(0.4))

	if id == "":
		draw_string(font, rect.position + Vector2(10, 50), "— vacío —", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 16, Palette.WALL)
		return

	var color: Color = Palette.WARM_LIGHT if PartsDB.is_boss_part(id) else Palette.SLIME_CORE
	draw_multiline_string(font, rect.position + Vector2(10, 46), PartsDB.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 15, 2, color)

# --- Distribución del mapa ---

# Devuelve { "rooms": {id: Rect2}, "floors": {nivel: y_etiqueta}, "origin_x", "width" }.
func _build_layout() -> Dictionary:
	var pitch := ROOM_SIZE + ROOM_GAP

	var levels: Array = []
	var min_grid_x := 9999
	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		var level: int = data["level"]
		if not levels.has(level):
			levels.append(level)
		min_grid_x = min(min_grid_x, data["grid"].x)
	# De arriba abajo: el nivel 0 (la salida) queda arriba del todo.
	levels.sort()
	levels.reverse()

	# Filas que ocupa cada piso y su y mínima, para colocar las bandas.
	var rows := {}
	var min_y := {}
	var max_x := -9999
	for level in levels:
		var lo := 9999
		var hi := -9999
		for room_id in RoomDB.ROOMS:
			var data: Dictionary = RoomDB.ROOMS[room_id]
			if data["level"] != level:
				continue
			lo = min(lo, data["grid"].y)
			hi = max(hi, data["grid"].y)
			max_x = max(max_x, data["grid"].x)
		rows[level] = hi - lo + 1
		min_y[level] = lo

	var total_height := 0.0
	for level in levels:
		total_height += rows[level] * pitch.y
	total_height += FLOOR_GAP * max(0, levels.size() - 1)

	var columns: int = max_x - min_grid_x + 1
	var map_width: float = columns * pitch.x - ROOM_GAP.x
	var origin_x: float = MAP_CENTER_X - map_width * 0.5
	var cursor_y: float = 540.0 - total_height * 0.5

	var room_rects := {}
	var floor_labels := {}
	for level in levels:
		floor_labels[level] = cursor_y
		for room_id in RoomDB.ROOMS:
			var data: Dictionary = RoomDB.ROOMS[room_id]
			if data["level"] != level:
				continue
			var grid: Vector2i = data["grid"]
			room_rects[room_id] = Rect2(
				Vector2(
					origin_x + (grid.x - min_grid_x) * pitch.x,
					cursor_y + (grid.y - min_y[level]) * pitch.y
				),
				ROOM_SIZE
			)
		cursor_y += rows[level] * pitch.y + FLOOR_GAP

	return {"rooms": room_rects, "floors": floor_labels, "origin_x": origin_x, "width": map_width}

# Una sala se dibuja si ya se pisó, o si es vecina de una pisada: así el mapa
# muestra hacia dónde se puede seguir sin revelar el complejo entero.
func _is_known(room_id: String) -> bool:
	if GameState.visited.get(room_id, false):
		return true
	for other_id in RoomDB.ROOMS:
		if not GameState.visited.get(other_id, false):
			continue
		if RoomDB.ROOMS[other_id]["doors"].values().has(room_id):
			return true
	return false

# --- Dibujo del mapa ---

func _draw_room(font: Font, layout: Dictionary, room_id: String) -> void:
	var rect: Rect2 = layout["rooms"][room_id]
	var data: Dictionary = RoomDB.ROOMS[room_id]
	var visited: bool = GameState.visited.get(room_id, false)

	var fill: Color = Color(Palette.FLOOR, 0.25)
	var border: Color = Palette.WALL
	if room_id == GameState.current_room:
		fill = Color(Palette.SLIME_CORE, 0.45)
		border = Palette.SLIME_CORE
	elif visited:
		fill = Color(Palette.FLOOR, 0.8)
		border = Palette.WALL.lightened(0.2)

	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 3.0 if room_id == GameState.current_room else 2.0)

	# Huecos de puerta en el borde que toca, igual que en la sala de verdad.
	for dir in data["doors"]:
		_draw_door_notch(rect, dir, border)

	if not visited:
		# Aún sin visitar: solo la silueta y una interrogación.
		draw_string(font, rect.position + Vector2(0, rect.size.y * 0.6), "?", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 26, Palette.WALL)
		return

	var label: String = data["room_name"]
	draw_string(font, rect.position + Vector2(4, 20), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 13, Palette.WARM_LIGHT)

	var tag := ""
	var tag_color: Color = Palette.WARM_LIGHT
	if data.get("is_safe", false):
		tag = "SEGURA"
		tag_color = Palette.SLIME_BODY
	elif data.get("is_exit", false):
		tag = "SALIDA"
	elif data.get("is_boss", false):
		tag = "JEFE"
	elif GameState.is_room_cleared(room_id):
		tag = "LIMPIA"
		tag_color = Palette.SLIME_BODY
	elif _has_enemies(room_id):
		# Por ahora nombra a los experimentos en vez de un genérico "HOSTIL":
		# es la información que de verdad importa antes de entrar.
		tag = _enemy_names_for(room_id)
		tag_color = Color(0.9, 0.55, 0.45)
	if tag != "":
		draw_string(font, rect.position + Vector2(4, rect.size.y - 8), tag, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 12, tag_color)

func _has_enemies(room_id: String) -> bool:
	return not EnemyDB.spawns_for(room_id).is_empty()

func _enemy_names_for(room_id: String) -> String:
	var names: Array[String] = []
	for spawn in EnemyDB.spawns_for(room_id):
		var enemy_name: String = EnemyDB.display_name(spawn["type"])
		if not names.has(enemy_name):
			names.append(enemy_name)
	return " / ".join(names)

func _draw_door_notch(rect: Rect2, dir: String, color: Color) -> void:
	var center := rect.get_center()
	match dir:
		"N":
			draw_rect(Rect2(center.x - DOOR_LENGTH, rect.position.y - DOOR_THICKNESS * 0.5, DOOR_LENGTH * 2.0, DOOR_THICKNESS), color, true)
		"S":
			draw_rect(Rect2(center.x - DOOR_LENGTH, rect.end.y - DOOR_THICKNESS * 0.5, DOOR_LENGTH * 2.0, DOOR_THICKNESS), color, true)
		"O":
			draw_rect(Rect2(rect.position.x - DOOR_THICKNESS * 0.5, center.y - DOOR_LENGTH, DOOR_THICKNESS, DOOR_LENGTH * 2.0), color, true)
		"E":
			draw_rect(Rect2(rect.end.x - DOOR_THICKNESS * 0.5, center.y - DOOR_LENGTH, DOOR_THICKNESS, DOOR_LENGTH * 2.0), color, true)

func _draw_link(layout: Dictionary, room_id: String, target_id: String, _dir: String) -> void:
	if not layout["rooms"].has(target_id):
		return
	var a: Rect2 = layout["rooms"][room_id]
	var b: Rect2 = layout["rooms"][target_id]
	var same_floor: bool = RoomDB.ROOMS[room_id]["level"] == RoomDB.ROOMS[target_id]["level"]
	# Los ascensores cruzan pisos: se marcan más gruesos y en color cálido para
	# que se distingan de una puerta normal de un vistazo.
	var color: Color = Palette.WALL if same_floor else Palette.WARM_LIGHT
	var width: float = 3.0 if same_floor else 5.0
	draw_line(a.get_center(), b.get_center(), Color(color, 0.55), width)

func _draw_floor_labels(font: Font, layout: Dictionary) -> void:
	var names := {}
	for room_id in RoomDB.ROOMS:
		var data: Dictionary = RoomDB.ROOMS[room_id]
		names[data["level"]] = data["level_name"]

	for level in layout["floors"]:
		var y: float = layout["floors"][level]
		var text := "NIVEL %d · %s" % [level, names[level]]
		draw_string(font, Vector2(layout["origin_x"], y - 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, layout["width"], 18, Palette.WARM_LIGHT)

func _draw_legend(font: Font) -> void:
	var lines := [
		"AQUÍ ESTÁS",
		"VISITADA",
		"SIN VISITAR",
		"ASCENSOR ENTRE NIVELES",
	]
	var colors := [Palette.SLIME_CORE, Palette.FLOOR, Palette.WALL, Palette.WARM_LIGHT]
	var origin := Vector2(1040, 900)
	for i in range(lines.size()):
		var y: float = origin.y + i * 30.0
		draw_rect(Rect2(origin.x, y - 11.0, 22.0, 14.0), colors[i], true)
		draw_string(font, Vector2(origin.x + 32.0, y + 2.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 380.0, 16, Palette.WALL.lightened(0.5))
