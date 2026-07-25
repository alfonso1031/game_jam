extends Node2D
class_name Room

const TILE_W := 64.0
const TILE_H := 32.0

@export var grid_width: int = 8
@export var grid_height: int = 6
@export var floor_color: Color = Color(0.55, 0.58, 0.62)
@export var wall_height: float = 40.0
## Perimeter grid cells where the wall is skipped (door openings).
@export var door_gap_cells: Array[Vector2i] = []

func _ready() -> void:
	y_sort_enabled = true
	_build_floor()
	_build_walls()

func grid_to_local(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TILE_W / 2.0, (gx + gy) * TILE_H / 2.0)

func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -h / 2.0), Vector2(w / 2.0, 0),
		Vector2(0, h / 2.0), Vector2(-w / 2.0, 0),
	])

func _build_floor() -> void:
	var floor_node := Node2D.new()
	floor_node.name = "Floor"
	floor_node.y_sort_enabled = false
	floor_node.z_index = -100
	add_child(floor_node)
	for gx in range(grid_width):
		for gy in range(grid_height):
			var tile := Polygon2D.new()
			tile.polygon = _diamond(TILE_W, TILE_H)
			var shade := 0.04 if (gx + gy) % 2 == 0 else 0.0
			tile.color = floor_color.darkened(shade)
			tile.position = grid_to_local(gx, gy)
			floor_node.add_child(tile)

func _is_perimeter(gx: int, gy: int) -> bool:
	return gx == 0 or gy == 0 or gx == grid_width - 1 or gy == grid_height - 1

func _build_walls() -> void:
	var walls_node := Node2D.new()
	walls_node.name = "Walls"
	add_child(walls_node)
	for gx in range(grid_width):
		for gy in range(grid_height):
			if not _is_perimeter(gx, gy):
				continue
			if Vector2i(gx, gy) in door_gap_cells:
				continue
			_add_wall_block(walls_node, gx, gy)

func _add_wall_block(parent: Node2D, gx: int, gy: int) -> void:
	var body := StaticBody2D.new()
	body.position = grid_to_local(gx, gy)
	body.y_sort_enabled = true

	var top := Polygon2D.new()
	top.polygon = _diamond(TILE_W, TILE_H)
	top.position = Vector2(0, -wall_height)
	top.color = Color(0.42, 0.44, 0.5)
	body.add_child(top)

	var left := Polygon2D.new()
	left.polygon = PackedVector2Array([
		Vector2(-TILE_W / 2.0, 0), Vector2(0, TILE_H / 2.0),
		Vector2(0, TILE_H / 2.0 - wall_height), Vector2(-TILE_W / 2.0, -wall_height),
	])
	left.color = Color(0.24, 0.25, 0.3)
	body.add_child(left)

	var right := Polygon2D.new()
	right.polygon = PackedVector2Array([
		Vector2(TILE_W / 2.0, 0), Vector2(0, TILE_H / 2.0),
		Vector2(0, TILE_H / 2.0 - wall_height), Vector2(TILE_W / 2.0, -wall_height),
	])
	right.color = Color(0.32, 0.33, 0.4)
	body.add_child(right)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE_W * 0.9, TILE_H * 0.9)
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)
