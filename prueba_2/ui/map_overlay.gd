extends Control

const Palette := preload("res://core/palette.gd")

const MAP_MARGIN := 42.0
const ROOM_MAX_WIDTH := 132.0
const ROOM_ASPECT := 16.0 / 9.0
const ROOM_GAP := 24.0
const DOOR_LENGTH := 9.0
const DOOR_THICKNESS := 5.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	RunManager.map_generated.connect(_on_map_generated)
	GameState.room_changed.connect(_on_room_changed)
	GameState.grate_discovered.connect(_on_grate_discovered)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
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


func _on_map_generated(_run_map: RefCounted) -> void:
	queue_redraw()


func _on_room_changed(_room_id: String) -> void:
	queue_redraw()


func _on_grate_discovered(_source_id: String) -> void:
	queue_redraw()


func map_panel_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(
		Vector2(viewport_size.x * 0.52, 105.0),
		Vector2(viewport_size.x * 0.45, viewport_size.y - 245.0)
	)


func build_layout(run_map: RefCounted, panel_rect: Rect2) -> Dictionary:
	var room_data: Dictionary = run_map.get("rooms")
	if room_data.is_empty():
		return {"rooms": {}, "room_size": Vector2.ZERO}

	var min_x := 9999
	var max_x := -9999
	var min_y := 9999
	var max_y := -9999
	for data: Dictionary in room_data.values():
		var grid: Vector2i = data["grid"]
		min_x = mini(min_x, grid.x)
		max_x = maxi(max_x, grid.x)
		min_y = mini(min_y, grid.y)
		max_y = maxi(max_y, grid.y)

	var cols := max_x - min_x + 1
	var rows := max_y - min_y + 1
	var inner_size := panel_rect.size - Vector2.ONE * MAP_MARGIN * 2.0
	var available_width := inner_size.x - ROOM_GAP * float(maxi(0, cols - 1))
	var available_height := inner_size.y - ROOM_GAP * float(maxi(0, rows - 1))
	var room_width := minf(
		ROOM_MAX_WIDTH,
		minf(
			available_width / float(cols),
			available_height / float(rows) * ROOM_ASPECT
		)
	)
	room_width = maxf(24.0, room_width)
	var room_size := Vector2(room_width, room_width / ROOM_ASPECT)
	var pitch := room_size + Vector2.ONE * ROOM_GAP
	var used_size := Vector2(
		room_size.x * cols + ROOM_GAP * maxi(0, cols - 1),
		room_size.y * rows + ROOM_GAP * maxi(0, rows - 1)
	)
	var origin := panel_rect.position + (panel_rect.size - used_size) * 0.5

	var room_rects: Dictionary = {}
	for room_id: String in room_data:
		var grid: Vector2i = room_data[room_id]["grid"]
		room_rects[room_id] = Rect2(
			origin + Vector2(grid.x - min_x, grid.y - min_y) * pitch,
			room_size
		)
	return {"rooms": room_rects, "room_size": room_size}


func visible_room_ids() -> Array[String]:
	var result: Array[String] = []
	if RunManager.current_map == null:
		return result
	var rooms: Dictionary = RunManager.current_map.rooms

	_add_visible(result, GameState.current_room, rooms)
	for room_id: String in GameState.visited:
		if not GameState.visited[room_id]:
			continue
		_add_visible(result, room_id, rooms)
		if not rooms.has(room_id):
			continue
		var doors: Dictionary = rooms[room_id]["doors"]
		for target_id: String in doors.values():
			_add_visible(result, target_id, rooms)

	for source_id: String in GameState.discovered_grates:
		if not GameState.discovered_grates[source_id] or not rooms.has(source_id):
			continue
		var target_id: String = rooms[source_id]["grate_target"]
		_add_visible(result, target_id, rooms)

	result.sort()
	return result


func _add_visible(result: Array[String], room_id: String, rooms: Dictionary) -> void:
	if room_id.is_empty() or not rooms.has(room_id) or result.has(room_id):
		return
	result.append(room_id)


func _draw() -> void:
	if not visible:
		return
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(Palette.VOID, 0.96), true)
	draw_line(
		Vector2(viewport_size.x * 0.5, 110.0),
		Vector2(viewport_size.x * 0.5, viewport_size.y - 85.0),
		Color(Palette.WALL, 0.45),
		2.0
	)

	var panel := map_panel_rect()
	draw_rect(panel, Color(Palette.VOID.darkened(0.3), 0.45), true)
	draw_rect(panel, Color(Palette.WALL, 0.7), false, 2.0)
	if RunManager.current_map == null:
		return

	var layout := build_layout(RunManager.current_map, panel)
	var visible_ids := visible_room_ids()
	_draw_room_links(layout, visible_ids)
	_draw_grate_links(layout, visible_ids)
	var font := ThemeDB.fallback_font
	for room_id: String in visible_ids:
		if layout["rooms"].has(room_id):
			_draw_room(font, layout["rooms"][room_id], room_id)


func _draw_room_links(layout: Dictionary, visible_ids: Array[String]) -> void:
	var drawn: Dictionary = {}
	var rooms: Dictionary = RunManager.current_map.rooms
	for room_id: String in visible_ids:
		if not rooms.has(room_id) or not layout["rooms"].has(room_id):
			continue
		for target_id: String in rooms[room_id]["doors"].values():
			if not visible_ids.has(target_id) or not layout["rooms"].has(target_id):
				continue
			var pair := [room_id, target_id]
			pair.sort()
			var key := "%s|%s" % pair
			if drawn.has(key):
				continue
			drawn[key] = true
			var from_rect: Rect2 = layout["rooms"][room_id]
			var to_rect: Rect2 = layout["rooms"][target_id]
			draw_line(
				from_rect.get_center(),
				to_rect.get_center(),
				Color(Palette.WALL, 0.75),
				5.0
			)


func _draw_grate_links(layout: Dictionary, visible_ids: Array[String]) -> void:
	var rooms: Dictionary = RunManager.current_map.rooms
	for source_id: String in GameState.discovered_grates:
		if (
			not GameState.discovered_grates[source_id]
			or not rooms.has(source_id)
			or not layout["rooms"].has(source_id)
		):
			continue
		var target_id: String = rooms[source_id]["grate_target"]
		if not visible_ids.has(target_id) or not layout["rooms"].has(target_id):
			continue
		_draw_dashed_line(
			layout["rooms"][source_id].get_center(),
			layout["rooms"][target_id].get_center(),
			Palette.WARM_LIGHT
		)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < distance:
		var end := minf(cursor + 12.0, distance)
		draw_line(from + direction * cursor, from + direction * end, color, 4.0)
		cursor += 22.0


func _draw_room(font: Font, rect: Rect2, room_id: String) -> void:
	var data: Dictionary = RunManager.current_map.rooms[room_id]
	var visited: bool = GameState.visited.get(room_id, false)
	var fill := Color(Palette.FLOOR, 0.28)
	var border := Palette.WALL
	if room_id == GameState.current_room:
		fill = Color(Palette.SLIME_CORE, 0.48)
		border = Palette.SLIME_CORE
	elif visited:
		fill = Color(Palette.FLOOR, 0.82)
		border = Palette.WALL.lightened(0.2)

	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 4.0 if room_id == GameState.current_room else 2.0)
	for direction: String in data["doors"]:
		_draw_door_notch(rect, direction, border)

	if not visited:
		draw_string(
			font,
			rect.position + Vector2(0.0, rect.size.y * 0.65),
			"?",
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			24,
			Palette.WALL.lightened(0.3)
		)
		return

	var role := String(data.get("role", &"normal")).replace("_", " ").to_upper()
	var content := String(data.get("content_type", &"empty")).replace("_", " ").to_upper()
	draw_string(
		font,
		rect.position + Vector2(5.0, 22.0),
		role,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x - 10.0,
		14,
		Palette.WARM_LIGHT
	)
	draw_string(
		font,
		rect.position + Vector2(5.0, rect.size.y - 8.0),
		content,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x - 10.0,
		12,
		Palette.SLIME_BODY.lightened(0.25)
	)


func _draw_door_notch(rect: Rect2, direction: String, color: Color) -> void:
	var center := rect.get_center()
	match direction:
		"N":
			draw_rect(
				Rect2(
					center.x - DOOR_LENGTH,
					rect.position.y - DOOR_THICKNESS * 0.5,
					DOOR_LENGTH * 2.0,
					DOOR_THICKNESS
				),
				color
			)
		"S":
			draw_rect(
				Rect2(
					center.x - DOOR_LENGTH,
					rect.end.y - DOOR_THICKNESS * 0.5,
					DOOR_LENGTH * 2.0,
					DOOR_THICKNESS
				),
				color
			)
		"O":
			draw_rect(
				Rect2(
					rect.position.x - DOOR_THICKNESS * 0.5,
					center.y - DOOR_LENGTH,
					DOOR_THICKNESS,
					DOOR_LENGTH * 2.0
				),
				color
			)
		"E":
			draw_rect(
				Rect2(
					rect.end.x - DOOR_THICKNESS * 0.5,
					center.y - DOOR_LENGTH,
					DOOR_THICKNESS,
					DOOR_LENGTH * 2.0
				),
				color
			)
