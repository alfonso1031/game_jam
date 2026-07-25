extends Node

const OPPOSITE := {"N": "S", "S": "N", "E": "O", "O": "E"}

const ROOMS := {
	"L3_CELDA": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Celda de Contención",
		"grid": Vector2i(0, 0),
		"scene": "res://world/rooms/l3_celda.tscn",
		"doors": {"E": "L3_PASILLO"},
		"is_safe": true,
		"is_checkpoint": true,
	},
	"L3_PASILLO": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Pasillo de Servicio",
		"grid": Vector2i(1, 0),
		"scene": "res://world/rooms/l3_pasillo.tscn",
		"doors": {"O": "L3_CELDA", "N": "L3_ALMACEN", "E": "L3_NUCLEO"},
	},
	"L3_ALMACEN": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Almacén",
		"grid": Vector2i(1, -1),
		"scene": "res://world/rooms/l3_almacen.tscn",
		"doors": {"S": "L3_PASILLO"},
	},
	"L3_NUCLEO": {
		"level": -3,
		"level_name": "CONTENCIÓN",
		"room_name": "Núcleo de Contención",
		"grid": Vector2i(2, 0),
		"scene": "res://world/rooms/l3_nucleo.tscn",
		"doors": {"O": "L3_PASILLO", "N": "L2_ASCENSOR"},
		"is_boss": true,
	},
	"L2_ASCENSOR": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Ascensor",
		"grid": Vector2i(0, 0),
		"scene": "res://world/rooms/l2_ascensor.tscn",
		"doors": {"S": "L3_NUCLEO", "E": "L2_BIOLAB"},
		"is_checkpoint": true,
	},
	"L2_BIOLAB": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Bio-Laboratorio",
		"grid": Vector2i(1, 0),
		"scene": "res://world/rooms/l2_biolab.tscn",
		"doors": {"O": "L2_ASCENSOR", "E": "L2_ESCLUSA"},
	},
	"L2_ESCLUSA": {
		"level": -2,
		"level_name": "BIO-LABORATORIOS",
		"room_name": "Esclusa",
		"grid": Vector2i(2, 0),
		"scene": "res://world/rooms/l2_esclusa.tscn",
		"doors": {"O": "L2_BIOLAB", "N": "L1_ASCENSOR"},
	},

	# --- Nivel -1: MANTENIMIENTO ---
	# La columna x de cada ascensor coincide con la del piso de abajo, para que
	# en el mapa el salto entre niveles se lea como una escalera y no como un
	# cable cruzando la pantalla.
	"L1_ASCENSOR": {
		"level": -1,
		"level_name": "MANTENIMIENTO",
		"room_name": "Ascensor de Servicio",
		"grid": Vector2i(2, 0),
		"scene": "res://world/rooms/l1_ascensor.tscn",
		"doors": {"S": "L2_ESCLUSA", "E": "L1_TALLER"},
		"is_checkpoint": true,
	},
	"L1_TALLER": {
		"level": -1,
		"level_name": "MANTENIMIENTO",
		"room_name": "Taller de Piezas",
		"grid": Vector2i(3, 0),
		"scene": "res://world/rooms/l1_taller.tscn",
		"doors": {"O": "L1_ASCENSOR", "N": "L1_DEPOSITO", "E": "L1_COMPUERTA"},
	},
	"L1_DEPOSITO": {
		"level": -1,
		"level_name": "MANTENIMIENTO",
		"room_name": "Depósito de Residuos",
		"grid": Vector2i(3, -1),
		"scene": "res://world/rooms/l1_deposito.tscn",
		"doors": {"S": "L1_TALLER"},
	},
	"L1_COMPUERTA": {
		"level": -1,
		"level_name": "MANTENIMIENTO",
		"room_name": "Compuerta de Presión",
		"grid": Vector2i(4, 0),
		"scene": "res://world/rooms/l1_compuerta.tscn",
		"doors": {"O": "L1_TALLER", "N": "L0_VESTIBULO"},
	},

	# --- Nivel 0: SUPERFICIE ---
	"L0_VESTIBULO": {
		"level": 0,
		"level_name": "SUPERFICIE",
		"room_name": "Vestíbulo",
		"grid": Vector2i(4, 0),
		"scene": "res://world/rooms/l0_vestibulo.tscn",
		"doors": {"S": "L1_COMPUERTA", "E": "L0_SALIDA"},
		"is_checkpoint": true,
	},
	"L0_SALIDA": {
		"level": 0,
		"level_name": "SUPERFICIE",
		"room_name": "Salida",
		"grid": Vector2i(5, 0),
		"scene": "res://world/rooms/l0_salida.tscn",
		"doors": {"O": "L0_VESTIBULO"},
		"is_exit": true,
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
