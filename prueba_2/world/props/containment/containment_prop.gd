extends StaticBody2D

@export var footprint_size := Vector2(180.0, 120.0)


func footprint() -> Rect2:
	return Rect2(position - footprint_size * 0.5, footprint_size)
