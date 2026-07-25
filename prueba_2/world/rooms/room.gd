extends Node2D

const Palette := preload("res://core/palette.gd")

const LampScene := preload("res://world/props/lamp.tscn")
const TankScene := preload("res://world/props/tank.tscn")
const DebrisScene := preload("res://world/props/debris.tscn")
const PuddleScene := preload("res://world/props/puddle.tscn")

# Rejilla jugable 13 x 7, celda de 120 px, interior en x 180..1740 / y 120..960.
const CELL := 120.0
const INTERIOR_ORIGIN := Vector2(180, 120)

const BOUNDS := Rect2(60, 0, 1800, 1080)

@export var lamps: Array[Vector2i] = []
@export var dead_lamps: Array[Vector2i] = []
@export var tanks: Array[Vector2i] = []
@export var debris: Array[Vector2i] = []
@export var puddles: Array[Vector2i] = []
@export var sign_text: String = ""
@export var sign_cell: Vector2i = Vector2i(6, 0)

func _ready() -> void:
	# Orden de abajo hacia arriba: manchas, escombros, tanques, luces.
	_spawn_at(PuddleScene, puddles)
	_spawn_at(DebrisScene, debris)
	_spawn_at(TankScene, tanks)
	_spawn_at(LampScene, lamps)

	for cell in dead_lamps:
		var lamp: Node2D = LampScene.instantiate()
		lamp.dead = true
		lamp.position = cell_center(cell)
		add_child(lamp)

	if sign_text != "":
		_spawn_sign()

func cell_center(cell: Vector2i) -> Vector2:
	return INTERIOR_ORIGIN + Vector2(cell.x, cell.y) * CELL + Vector2(CELL, CELL) * 0.5

func _spawn_at(scene: PackedScene, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var node: Node2D = scene.instantiate()
		node.position = cell_center(cell)
		add_child(node)

func _spawn_sign() -> void:
	var label := Label.new()
	label.text = sign_text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Palette.WARM_LIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(CELL * 4, 40)
	label.position = cell_center(sign_cell) - Vector2(CELL * 2, 20)
	label.modulate.a = 0.75
	add_child(label)
