class_name SlimePrototypeArena
extends Node2D

const VIEW_SIZE := Vector2(1920.0, 1080.0)
const PLAY_RECT := Rect2(128.0, 128.0, 1664.0, 824.0)
const WALL_THICKNESS := 64.0

const BACKGROUND_COLOR := Color("#09171c")
const FLOOR_COLOR := Color("#123039")
const GRID_COLOR := Color(0.18, 0.47, 0.52, 0.16)
const WALL_COLOR := Color("#294b52")
const WALL_EDGE_COLOR := Color("#4b7378")
const OBSTACLE_COLOR := Color("#1c5960")


func _ready() -> void:
	_create_boundaries()
	_create_barrier(Rect2(480.0, 320.0, 192.0, 96.0), OBSTACLE_COLOR)
	_create_barrier(Rect2(1240.0, 640.0, 240.0, 96.0), OBSTACLE_COLOR)
	_create_barrier(Rect2(860.0, 470.0, 200.0, 140.0), OBSTACLE_COLOR)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), BACKGROUND_COLOR)
	draw_rect(PLAY_RECT, FLOOR_COLOR)

	var grid_spacing := 64.0
	var x := PLAY_RECT.position.x
	while x <= PLAY_RECT.end.x:
		draw_line(
			Vector2(x, PLAY_RECT.position.y),
			Vector2(x, PLAY_RECT.end.y),
			GRID_COLOR,
			2.0
		)
		x += grid_spacing

	var y := PLAY_RECT.position.y
	while y <= PLAY_RECT.end.y:
		draw_line(
			Vector2(PLAY_RECT.position.x, y),
			Vector2(PLAY_RECT.end.x, y),
			GRID_COLOR,
			2.0
		)
		y += grid_spacing

	draw_rect(PLAY_RECT, Color("#4b7378"), false, 4.0)
	_draw_hazard_stripes(Rect2(128.0, 930.0, 360.0, 22.0))
	_draw_hazard_stripes(Rect2(1432.0, 128.0, 360.0, 22.0))


func _create_boundaries() -> void:
	_create_barrier(
		Rect2(
			PLAY_RECT.position.x - WALL_THICKNESS,
			PLAY_RECT.position.y - WALL_THICKNESS,
			PLAY_RECT.size.x + WALL_THICKNESS * 2.0,
			WALL_THICKNESS
		),
		WALL_COLOR
	)
	_create_barrier(
		Rect2(
			PLAY_RECT.position.x - WALL_THICKNESS,
			PLAY_RECT.end.y,
			PLAY_RECT.size.x + WALL_THICKNESS * 2.0,
			WALL_THICKNESS
		),
		WALL_COLOR
	)
	_create_barrier(
		Rect2(
			PLAY_RECT.position.x - WALL_THICKNESS,
			PLAY_RECT.position.y,
			WALL_THICKNESS,
			PLAY_RECT.size.y
		),
		WALL_COLOR
	)
	_create_barrier(
		Rect2(
			PLAY_RECT.end.x,
			PLAY_RECT.position.y,
			WALL_THICKNESS,
			PLAY_RECT.size.y
		),
		WALL_COLOR
	)


func _create_barrier(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.name = "Barrier%d" % (get_child_count() + 1)
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)

	var half_size := rect.size * 0.5
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	polygon.color = color
	body.add_child(polygon)

	var edge := Line2D.new()
	edge.points = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(-half_size.x, -half_size.y),
	])
	edge.width = 4.0
	edge.default_color = WALL_EDGE_COLOR
	body.add_child(edge)
	add_child(body)


func _draw_hazard_stripes(rect: Rect2) -> void:
	draw_rect(rect, Color("#14282d"))
	var stripe_width := 34.0
	var cursor := rect.position.x - rect.size.y
	while cursor < rect.end.x:
		var stripe := PackedVector2Array([
			Vector2(cursor, rect.position.y),
			Vector2(cursor + stripe_width * 0.55, rect.position.y),
			Vector2(cursor + stripe_width, rect.end.y),
			Vector2(cursor + stripe_width * 0.45, rect.end.y),
		])
		draw_colored_polygon(stripe, Color("#d7a93f"))
		cursor += stripe_width
