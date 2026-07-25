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

# Centro de cada banda de muro: las lámparas van empotradas ahí, no sueltas en
# el suelo — así se leen como parte del laboratorio y no como objetos que
# se puedan recoger.
const WALL_N_Y := 60.0
const WALL_S_Y := 1020.0
const WALL_O_X := 120.0
const WALL_E_X := 1800.0

# Índice de celda a lo largo del muro: 0..12 en N/S, 0..6 en E/O.
@export var lamps_n: Array[int] = []
@export var lamps_s: Array[int] = []
@export var lamps_e: Array[int] = []
@export var lamps_o: Array[int] = []
@export var dead_lamps_n: Array[int] = []
@export var dead_lamps_s: Array[int] = []
@export var dead_lamps_e: Array[int] = []
@export var dead_lamps_o: Array[int] = []

@export var tanks: Array[Vector2i] = []
@export var debris: Array[Vector2i] = []
@export var puddles: Array[Vector2i] = []
@export var sign_text: String = ""
@export var sign_cell: Vector2i = Vector2i(6, 0)

func _ready() -> void:
	# Orden de abajo hacia arriba: manchas, escombros, tanques.
	_spawn_at(PuddleScene, puddles)
	_spawn_at(DebrisScene, debris)
	_spawn_at(TankScene, tanks)

	_spawn_wall_lamps("N", lamps_n, false)
	_spawn_wall_lamps("S", lamps_s, false)
	_spawn_wall_lamps("E", lamps_e, false)
	_spawn_wall_lamps("O", lamps_o, false)
	_spawn_wall_lamps("N", dead_lamps_n, true)
	_spawn_wall_lamps("S", dead_lamps_s, true)
	_spawn_wall_lamps("E", dead_lamps_e, true)
	_spawn_wall_lamps("O", dead_lamps_o, true)

	if sign_text != "":
		_spawn_sign()

func cell_center(cell: Vector2i) -> Vector2:
	return INTERIOR_ORIGIN + Vector2(cell.x, cell.y) * CELL + Vector2(CELL, CELL) * 0.5

func _spawn_at(scene: PackedScene, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var node: Node2D = scene.instantiate()
		node.position = cell_center(cell)
		add_child(node)

func _spawn_wall_lamps(side: String, indices: Array[int], dead: bool) -> void:
	for index in indices:
		var lamp: Node2D = LampScene.instantiate()
		lamp.dead = dead
		lamp.position = wall_lamp_position(side, index)
		# En los muros laterales el aplique va vertical.
		lamp.rotation = PI / 2.0 if side == "E" or side == "O" else 0.0
		add_child(lamp)

func wall_lamp_position(side: String, index: int) -> Vector2:
	var along: float = INTERIOR_ORIGIN.x + index * CELL + CELL * 0.5
	match side:
		"N":
			return Vector2(along, WALL_N_Y)
		"S":
			return Vector2(along, WALL_S_Y)
		"O":
			return Vector2(WALL_O_X, INTERIOR_ORIGIN.y + index * CELL + CELL * 0.5)
		_:
			return Vector2(WALL_E_X, INTERIOR_ORIGIN.y + index * CELL + CELL * 0.5)

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
