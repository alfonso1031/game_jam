# Fondos de sala pre-renderizados (1920 x 1080, uno por combinación de puertas).
#
# Sin `class_name`, igual que el resto de `core/`: se consume con
# `preload("res://core/room_backgrounds.gd")`.
#
# La clave se arma recorriendo N,E,S,O en ese orden fijo y concatenando las
# direcciones que tengan puerta. Así `room.gd` no necesita que cada escena
# declare su fondo a mano: alcanza con que `RoomDB` tenga las puertas correctas
# y que exista arte para esa combinación.
#
# El set entregado trae exactamente un archivo por combinación (incluidas las
# 4 formas de "3 puertas": para cada lado que se pueda cerrar hay una imagen
# distinta), no variantes intercambiables de un mismo layout — verificado
# muestreando los píxeles del hueco de puerta en cada PNG, no a ojo.
const DIRECTION_ORDER := ["N", "E", "S", "O"]

const BACKGROUNDS := {
	"O": "res://assets/environment/rooms/room_1door_O.png",
	"E": "res://assets/environment/rooms/room_1door_E.png",
	"N": "res://assets/environment/rooms/room_1door_N.png",
	"S": "res://assets/environment/rooms/room_1door_S.png",
	"EO": "res://assets/environment/rooms/room_2door_OE.png",
	"NS": "res://assets/environment/rooms/room_2door_NS.png",
	"ES": "res://assets/environment/rooms/room_2door_SE.png",
	"NO": "res://assets/environment/rooms/room_2door_ON.png",
	"NES": "res://assets/environment/rooms/room_3door_NES.png",
	"NEO": "res://assets/environment/rooms/room_3door_NEO.png",
	"NSO": "res://assets/environment/rooms/room_3door_NSO.png",
	"ESO": "res://assets/environment/rooms/room_3door_ESO.png",
	"NESO": "res://assets/environment/rooms/room_4door_ONES.png",
}

static func key_for(doors: Dictionary) -> String:
	var key := ""
	for dir in DIRECTION_ORDER:
		if doors.has(dir):
			key += dir
	return key

static func texture_for(room_id: String, doors: Dictionary) -> Texture2D:
	var key := key_for(doors)
	var path: String = BACKGROUNDS.get(key, "")
	if path == "":
		push_error("RoomBackgrounds: sin fondo para la combinación de puertas '%s' (sala %s)" % [key, room_id])
		return null
	return load(path)
