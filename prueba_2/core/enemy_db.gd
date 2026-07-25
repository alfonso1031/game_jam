# Qué experimentos aparecen en cada sala y dónde.
#
# Vive fuera de los .tscn a propósito: el reparto de enemigos es lo que más se
# toca al equilibrar, y tenerlo todo junto evita abrir siete escenas para mover
# un bicho. `room.gd` lee esta tabla usando su propio nombre de nodo, que
# `Transition` fija al id de la sala.
#
# Cada entrada:
#   type   clave de SCENES
#   cell   celda de la rejilla 13x7 (x 0..12, y 0..6)
#   leader true en el jefe de sala: sella las puertas, tiene más vida y
#          SIEMPRE suelta parte

const SCENES := {
	"exp01": preload("res://actors/enemies/exp01_centipede.tscn"),
	"exp02": preload("res://actors/enemies/exp02_spider.tscn"),
	"exp03": preload("res://actors/enemies/exp03_saurian.tscn"),
	"exp04": preload("res://actors/enemies/exp04_eel.tscn"),
	"exp05": preload("res://actors/enemies/exp05_chimera.tscn"),
	"exp06": preload("res://actors/enemies/exp06_thermal.tscn"),
	"exp07": preload("res://actors/enemies/exp07_crustacean.tscn"),
	"exp08": preload("res://actors/enemies/exp08_fungal.tscn"),
	"exp09": preload("res://actors/enemies/exp09_golem.tscn"),
	"exp10": preload("res://actors/enemies/exp10_parasite.tscn"),
}

const SPAWNS := {
	# L3_CELDA no aparece: es la sala segura. Nunca genera experimentos, nunca
	# sella sus puertas, y es donde se puede reorganizar el inventario con calma.
	"L3_PASILLO": [
		{"type": "exp01", "cell": Vector2i(4, 1)},
		{"type": "exp01", "cell": Vector2i(8, 2)},
		{"type": "exp01", "cell": Vector2i(6, 4), "leader": true},
	],
	# El Arácnido dispara desde lejos y los Saurios presionan de cerca: obliga
	# a moverse en vez de campear en una esquina.
	"L3_ALMACEN": [
		{"type": "exp02", "cell": Vector2i(3, 4)},
		{"type": "exp03", "cell": Vector2i(9, 1)},
		{"type": "exp03", "cell": Vector2i(6, 2), "leader": true},
	],
	# L3_NUCLEO no lleva experimentos: es la sala del boss.
	"L2_ASCENSOR": [
		{"type": "exp04", "cell": Vector2i(3, 2)},
		{"type": "exp04", "cell": Vector2i(9, 2)},
		{"type": "exp04", "cell": Vector2i(6, 3), "leader": true},
	],
	# Sala del hueco: las Quimeras vuelan por encima, así que el hueco te
	# estorba solo a ti.
	"L2_BIOLAB": [
		{"type": "exp05", "cell": Vector2i(3, 4)},
		{"type": "exp05", "cell": Vector2i(9, 1)},
		{"type": "exp08", "cell": Vector2i(10, 4), "leader": true},
	],
	# Cierre del nivel -2: presión (Térmica) más un muro móvil (Crustáceo).
	"L2_ESCLUSA": [
		{"type": "exp06", "cell": Vector2i(4, 2)},
		{"type": "exp07", "cell": Vector2i(8, 4), "leader": true},
	],

	# --- Nivel -1: MANTENIMIENTO ---
	"L1_ASCENSOR": [
		{"type": "exp01", "cell": Vector2i(4, 4)},
		{"type": "exp03", "cell": Vector2i(8, 2), "leader": true},
	],
	# El Crustáceo tapa el paso mientras las Anguilas te pican por los lados:
	# obliga a estrenar una parte que rompa escudos o a rodearlo.
	"L1_TALLER": [
		{"type": "exp04", "cell": Vector2i(4, 1)},
		{"type": "exp04", "cell": Vector2i(8, 5)},
		{"type": "exp07", "cell": Vector2i(6, 3), "leader": true},
	],
	# Sala opcional: el Parásito te arrastra a las nubes del Fúngico.
	"L1_DEPOSITO": [
		{"type": "exp08", "cell": Vector2i(4, 3)},
		{"type": "exp10", "cell": Vector2i(8, 3), "leader": true},
	],
	"L1_COMPUERTA": [
		{"type": "exp02", "cell": Vector2i(9, 4)},
		{"type": "exp06", "cell": Vector2i(4, 2), "leader": true},
	],

	# --- Nivel 0: SUPERFICIE ---
	# Última pelea antes de la salida: Quimeras que vuelan y un Gólem imparable.
	"L0_VESTIBULO": [
		{"type": "exp05", "cell": Vector2i(3, 1)},
		{"type": "exp05", "cell": Vector2i(9, 5)},
		{"type": "exp09", "cell": Vector2i(6, 3), "leader": true},
	],
	# L0_SALIDA no aparece: se llega, se sale, se acabó.
}

const DISPLAY_NAMES := {
	"exp01": "Ciempiés de Agujas",
	"exp02": "Arácnido Blindado",
	"exp03": "Saurio Escamado",
	"exp04": "Anguila Voltaica",
	"exp05": "Quimera Alada",
	"exp06": "Bestia Térmica",
	"exp07": "Crustáceo Escudo",
	"exp08": "Cuerpo Fúngico",
	"exp09": "Gólem de Metal Sólido",
	"exp10": "Mutante Parásito",
}

static func spawns_for(room_id: String) -> Array:
	return SPAWNS.get(room_id, [])

static func scene_for(type_id: String) -> PackedScene:
	return SCENES.get(type_id, null)

static func display_name(type_id: String) -> String:
	return DISPLAY_NAMES.get(type_id, type_id)
