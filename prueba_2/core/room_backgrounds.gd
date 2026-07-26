# Catálogo canónico de fondos de sala pre-renderizados (1920 x 1080).
#
# Sin `class_name`, igual que el resto de `core/`: se consume con
# `preload("res://core/room_backgrounds.gd")`.
#
# La clave se arma recorriendo N,E,S,O. Las esquinas NE y SO reutilizan el arte
# opuesto con espejo horizontal; así la topología procedural puede usar las
# seis parejas cardinales sin duplicar PNG.
#
# La clave vacía pertenece exclusivamente a destinos de rejilla: no crea una
# puerta normal, pero reserva visualmente la abertura E para la futura rejilla.
const DIRECTION_ORDER := ["N", "E", "S", "O"]

const TEMPLATES := {
	"": {
		"background": "res://assets/environment/rooms/room_1door_E.png",
		"virtual_opening": "E",
	},
	"E": {"background": "res://assets/environment/rooms/room_1door_E.png"},
	"N": {"background": "res://assets/environment/rooms/room_1door_N.png"},
	"O": {"background": "res://assets/environment/rooms/room_1door_O.png"},
	"S": {"background": "res://assets/environment/rooms/room_1door_S.png"},
	"NE": {
		"background": "res://assets/environment/rooms/room_2door_ON.png",
		"flip_h": true,
	},
	"NS": {"background": "res://assets/environment/rooms/room_2door_NS.png"},
	"NO": {"background": "res://assets/environment/rooms/room_2door_ON.png"},
	"ES": {"background": "res://assets/environment/rooms/room_2door_SE.png"},
	"EO": {"background": "res://assets/environment/rooms/room_2door_OE.png"},
	"SO": {
		"background": "res://assets/environment/rooms/room_2door_SE.png",
		"flip_h": true,
	},
	"ESO": {"background": "res://assets/environment/rooms/room_3door_ESO.png"},
	"NEO": {"background": "res://assets/environment/rooms/room_3door_NEO.png"},
	"NES": {"background": "res://assets/environment/rooms/room_3door_NES.png"},
	"NSO": {"background": "res://assets/environment/rooms/room_3door_NSO.png"},
	"NESO": {"background": "res://assets/environment/rooms/room_4door_ONES.png"},
}

static func key_for(doors: Dictionary) -> String:
	var key := ""
	for dir in DIRECTION_ORDER:
		if doors.has(dir):
			key += dir
	return key


static func key_for_directions(directions: Array[String]) -> String:
	var present: Dictionary = {}
	for direction in directions:
		present[direction] = true
	return key_for(present)


static func template_for_doors(doors: Dictionary) -> Dictionary:
	return TEMPLATES.get(key_for(doors), {})


static func template_for_directions(directions: Array[String]) -> Dictionary:
	return TEMPLATES.get(key_for_directions(directions), {})


static func has_template(doors: Dictionary) -> bool:
	return not template_for_doors(doors).is_empty()


static func texture_for(room_id: String, doors: Dictionary) -> Texture2D:
	var key := key_for(doors)
	var template: Dictionary = TEMPLATES.get(key, {})
	if template.is_empty():
		push_error("RoomBackgrounds: sin fondo para la combinación de puertas '%s' (sala %s)" % [key, room_id])
		return null
	return load(template["background"])
