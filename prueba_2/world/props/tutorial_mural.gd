extends Node2D

const SIZE := Vector2(760, 190)


func footprint() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)
