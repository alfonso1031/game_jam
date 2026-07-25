extends Node

const OPPOSITE := {"N": "S", "S": "N", "E": "O", "O": "E"}

const ROOMS := {
	"L3_CELDA": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Celda de Contención",
		"grid": Vector2i(0, 0),
		"scene": "res://scenes/rooms/l3_celda.tscn",
		"doors": {"E": "L3_PASILLO"},
	},
	"L3_PASILLO": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Pasillo de Servicio",
		"grid": Vector2i(1, 0),
		"scene": "res://scenes/rooms/l3_pasillo.tscn",
		"doors": {"O": "L3_CELDA", "N": "L3_ALMACEN", "E": "L3_NUCLEO"},
	},
	"L3_ALMACEN": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Almacén",
		"grid": Vector2i(1, -1),
		"scene": "res://scenes/rooms/l3_almacen.tscn",
		"doors": {"S": "L3_PASILLO"},
	},
	"L3_NUCLEO": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Núcleo de Contención",
		"grid": Vector2i(2, 0),
		"scene": "res://scenes/rooms/l3_nucleo.tscn",
		"doors": {"O": "L3_PASILLO", "N": "L2_ASCENSOR"},
		"is_boss": true,
	},
	"L2_ASCENSOR": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Ascensor",
		"grid": Vector2i(0, 0),
		"scene": "res://scenes/rooms/l2_ascensor.tscn",
		"doors": {"S": "L3_NUCLEO", "E": "L2_BIOLAB"},
	},
	"L2_BIOLAB": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Bio-Laboratorio",
		"grid": Vector2i(1, 0),
		"scene": "res://scenes/rooms/l2_biolab.tscn",
		"doors": {"O": "L2_ASCENSOR", "E": "L2_ESCLUSA"},
	},
	"L2_ESCLUSA": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Esclusa",
		"grid": Vector2i(2, 0),
		"scene": "res://scenes/rooms/l2_esclusa.tscn",
		"doors": {"O": "L2_BIOLAB"},
	},
}

func _ready() -> void:
	_validate()

func _validate() -> void:
	for room_id in ROOMS:
		var doors: Dictionary = ROOMS[room_id]["doors"]
		for dir in doors:
			var target_id: String = doors[dir]
			if not ROOMS.has(target_id):
				push_error("RoomDB: %s.doors.%s apunta a sala inexistente %s" % [room_id, dir, target_id])
				continue
			var back_dir: String = OPPOSITE[dir]
			var target_doors: Dictionary = ROOMS[target_id]["doors"]
			if target_doors.get(back_dir) != room_id:
				push_error("RoomDB: inconsistencia %s.doors.%s -> %s pero %s.doors.%s no vuelve" % [room_id, dir, target_id, target_id, back_dir])
