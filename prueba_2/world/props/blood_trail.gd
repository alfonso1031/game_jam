extends Node2D

const DROPS := preload("res://assets/environment/blood/blood_drops.png")
const DRAG := preload("res://assets/environment/blood/blood_drag.png")
const POOL := preload("res://assets/environment/blood/blood_pool.png")

const DROP_REGIONS: Array[Rect2] = [
	Rect2(430, 140, 350, 250),
	Rect2(490, 340, 300, 260),
	Rect2(430, 580, 350, 240),
	Rect2(430, 820, 350, 260),
]


func configure(start: Vector2, finish: Vector2, include_pool: bool) -> void:
	position = Vector2.ZERO
	var direction := start.direction_to(finish)
	var distance := start.distance_to(finish)
	var drop_index := 0
	for index in range(5):
		var sprite := Sprite2D.new()
		sprite.position = start.lerp(finish, float(index + 1) / 6.0)
		sprite.z_index = -4
		if index == 2:
			sprite.name = "Drag"
			sprite.texture = DRAG
			sprite.rotation = direction.angle()
			sprite.scale = Vector2(clampf(distance / 1500.0, 0.18, 0.55), 0.18)
		else:
			sprite.name = "Drops%d" % drop_index
			sprite.texture = DROPS
			sprite.region_enabled = true
			sprite.region_rect = DROP_REGIONS[drop_index]
			sprite.rotation = direction.angle() - PI * 0.5
			sprite.scale = Vector2(0.28, 0.28)
			drop_index += 1
		add_child(sprite)
	if include_pool:
		var pool := Sprite2D.new()
		pool.name = "Pool"
		pool.texture = POOL
		pool.position = finish
		pool.scale = Vector2(0.22, 0.22)
		pool.z_index = -4
		add_child(pool)
