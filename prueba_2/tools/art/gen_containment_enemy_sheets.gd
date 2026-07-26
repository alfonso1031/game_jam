extends SceneTree

# Generador reproducible de las hojas fuente de los enemigos de Contención.
#
# Escribe cuatro hojas 3 x 2 con fondo croma `#ff00ff` en `art_raw/`, tal y como
# las pide `docs/superpowers/specs/2026-07-26-assets-enemigos-contencion-design.md`.
# El arte se compone con formas orgánicas superpuestas —el mismo lenguaje vectorial
# del resto del juego— y no con píxeles a mano: así las seis poses de un personaje
# comparten anatomía, escala y punto de apoyo por construcción, que es justo lo que
# el procesador necesita para conservar el registro entre fotogramas.
#
# La hoja es el contrato con diseño: si más adelante llega una hoja pintada a mano
# con el mismo orden de poses, se sustituye el PNG y se vuelve a correr
# `process_containment_enemy_sheets.gd` sin tocar nada más.
#
#   godot --headless --path prueba_2 --script res://tools/art/gen_containment_enemy_sheets.gd

const OUTPUT_ROOT := "res://../art_raw/enemigos/containment"
const CHROMA := Color(1.0, 0.0, 1.0)
# Ancho del degradado de antialias, en píxeles de la hoja.
const AA_WIDTH := 1.0

const ENEMY_CELL := Vector2i(512, 448)
const BOSS_CELL := Vector2i(640, 448)

# --- Paletas ---------------------------------------------------------------
# Ningún blanco llega a #E0E0E0: el destello de daño multiplica x2,2 y un blanco
# puro se comería el golpe.

const C1_PLATE := Color(0.62, 0.68, 0.72)
const C1_PLATE_DARK := Color(0.36, 0.42, 0.48)
const C1_PLATE_LIGHT := Color(0.79, 0.84, 0.86)
const C1_NEEDLE := Color(0.84, 0.86, 0.82)
const C1_GLOW := Color(0.45, 0.94, 0.91)

const C2_SHELL := Color(0.42, 0.44, 0.52)
const C2_SHELL_LIGHT := Color(0.58, 0.61, 0.69)
const C2_SHELL_DARK := Color(0.26, 0.28, 0.36)
const C2_LEG := Color(0.34, 0.36, 0.44)
const C2_ABDOMEN := Color(0.37, 0.41, 0.47)
const C2_GLOW := Color(0.45, 0.94, 0.91)

const C3_HIDE := Color(0.47, 0.55, 0.50)
const C3_HIDE_LIGHT := Color(0.62, 0.69, 0.58)
const C3_HIDE_DARK := Color(0.29, 0.36, 0.33)
const C3_LIMB := Color(0.40, 0.47, 0.43)
const C3_PLATE := Color(0.55, 0.62, 0.54)

const C4_BODY := Color(0.85, 0.83, 0.80)
const C4_BODY_DARK := Color(0.66, 0.64, 0.65)
const C4_MEMBRANE := Color(0.77, 0.74, 0.76)
const C4_BONE := Color(0.87, 0.85, 0.82)
const C4_CLAW := Color(0.58, 0.57, 0.60)
const C4_GLOW := Color(0.45, 0.94, 0.91)

# --- Estado del rasterizador ----------------------------------------------

var _width: int = 0
var _height: int = 0
var _cover: PackedFloat32Array = PackedFloat32Array()
var _color: PackedColorArray = PackedColorArray()


func _init() -> void:
	var sheets: Dictionary = {
		"exp01_centipede": [ENEMY_CELL, _centipede_poses()],
		"exp02_spider": [ENEMY_CELL, _spider_poses()],
		"exp03_saurian": [ENEMY_CELL, _saurian_poses()],
		"boss_chimera": [BOSS_CELL, _chimera_poses()],
	}
	for name: String in sheets:
		var entry: Array = sheets[name]
		var cell: Vector2i = entry[0]
		var poses: Array = entry[1]
		if poses.size() != 6:
			push_error("%s declara %d poses y hacen falta 6" % [name, poses.size()])
			quit(1)
			return
		if not _write_sheet(name, cell, poses):
			quit(1)
			return
	print("CONTAINMENT_SHEETS_OK  hojas=4  celda_enemigo=%s  celda_jefe=%s" % [
		ENEMY_CELL,
		BOSS_CELL,
	])
	quit(0)


func _write_sheet(name: String, cell: Vector2i, poses: Array) -> bool:
	var sheet := Image.create_empty(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGB8)
	sheet.fill(CHROMA)
	for index in range(6):
		var pose: Array[Dictionary] = poses[index]
		var rendered := _render_cell(cell, pose)
		var at := Vector2i(index % 3, index / 3) * cell
		sheet.blit_rect(rendered, Rect2i(Vector2i.ZERO, cell), at)

	var directory := "%s/%s" % [OUTPUT_ROOT, name]
	var absolute_dir := ProjectSettings.globalize_path(directory).simplify_path()
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("No se pudo crear %s: %s" % [absolute_dir, error_string(error)])
		return false
	var destination := "%s/source_sheet.png" % absolute_dir
	error = sheet.save_png(destination)
	if error != OK:
		push_error("No se pudo guardar %s: %s" % [destination, error_string(error)])
		return false
	return true


# --- Rasterizador ----------------------------------------------------------
#
# Cobertura por unión (`max`) y color por orden de pintado. Unir con `max` en vez
# de acumular alfa es lo que evita las costuras: dos formas del mismo color que
# comparten borde suman coberturas parciales y, si se compusieran una sobre otra,
# dejarían una línea de fondo croma visible en mitad del bicho.

func _render_cell(size: Vector2i, shapes: Array[Dictionary]) -> Image:
	_width = size.x
	_height = size.y
	var count := _width * _height
	_cover = PackedFloat32Array()
	_cover.resize(count)
	_color = PackedColorArray()
	_color.resize(count)

	var origin := Vector2(_width, _height) * 0.5
	for shape: Dictionary in shapes:
		_draw_shape(shape, origin)

	var data := PackedByteArray()
	data.resize(count * 3)
	for index in range(count):
		var pixel := CHROMA.lerp(_color[index], _cover[index])
		data[index * 3] = _byte(pixel.r)
		data[index * 3 + 1] = _byte(pixel.g)
		data[index * 3 + 2] = _byte(pixel.b)
	return Image.create_from_data(_width, _height, false, Image.FORMAT_RGB8, data)


func _byte(value: float) -> int:
	return int(round(clampf(value, 0.0, 1.0) * 255.0))


func _draw_shape(shape: Dictionary, origin: Vector2) -> void:
	var kind: String = shape["kind"]
	var color: Color = shape["color"]
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO

	match kind:
		"ellipse":
			var center: Vector2 = shape["c"]
			var radii: Vector2 = shape["r"]
			var reach := maxf(radii.x, radii.y) + 2.0
			minimum = center - Vector2(reach, reach)
			maximum = center + Vector2(reach, reach)
		"cone":
			var a: Vector2 = shape["a"]
			var b: Vector2 = shape["b"]
			var reach: float = maxf(shape["ra"], shape["rb"]) + 2.0
			minimum = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
			maximum = Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
		"poly":
			var points: PackedVector2Array = shape["points"]
			minimum = points[0]
			maximum = points[0]
			for point: Vector2 in points:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
			minimum -= Vector2(2.0, 2.0)
			maximum += Vector2(2.0, 2.0)

	var from_x := maxi(0, int(floor(minimum.x + origin.x)))
	var to_x := mini(_width - 1, int(ceil(maximum.x + origin.x)))
	var from_y := maxi(0, int(floor(minimum.y + origin.y)))
	var to_y := mini(_height - 1, int(ceil(maximum.y + origin.y)))

	for y in range(from_y, to_y + 1):
		for x in range(from_x, to_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) - origin
			var distance := 0.0
			match kind:
				"ellipse":
					distance = _sd_ellipse(point, shape["c"], shape["r"], shape["rot"])
				"cone":
					distance = _sd_cone(point, shape["a"], shape["b"], shape["ra"], shape["rb"])
				"poly":
					distance = _sd_polygon(point, shape["points"])
			var coverage := clampf(0.5 - distance / AA_WIDTH, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var index := y * _width + x
			var united := maxf(_cover[index], coverage)
			_color[index] = _color[index].lerp(color, coverage / united)
			_cover[index] = united


func _sd_ellipse(point: Vector2, center: Vector2, radii: Vector2, rotation: float) -> float:
	var q := (point - center).rotated(-rotation)
	var normalized := Vector2(q.x / radii.x, q.y / radii.y)
	var k1 := normalized.length()
	if k1 < 0.00001:
		return -minf(radii.x, radii.y)
	var gradient := Vector2(q.x / (radii.x * radii.x), q.y / (radii.y * radii.y))
	return (k1 - 1.0) * k1 / gradient.length()


# Cápsula de radio variable: sirve igual para una pata, una espina o un tramo de
# cola, que es todo lo que necesitan estos cuatro bichos.
func _sd_cone(point: Vector2, a: Vector2, b: Vector2, ra: float, rb: float) -> float:
	var ba := b - a
	var length_squared := ba.length_squared()
	if length_squared < 0.000001:
		return (point - a).length() - maxf(ra, rb)
	var difference := ra - rb
	var a2 := length_squared - difference * difference
	var inverse := 1.0 / length_squared
	var pa := point - a
	var y := pa.dot(ba)
	var z := y - length_squared
	var x2 := (pa * length_squared - ba * y).length_squared()
	var y2 := y * y * length_squared
	var z2 := z * z * length_squared
	var k := signf(difference) * difference * difference * x2
	if signf(z) * a2 * z2 > k:
		return sqrt(x2 + z2) * inverse - rb
	if signf(y) * a2 * y2 < k:
		return sqrt(x2 + y2) * inverse - ra
	return (sqrt(x2 * a2 * inverse) + y * difference) * inverse - ra


func _sd_polygon(point: Vector2, points: PackedVector2Array) -> float:
	var count := points.size()
	var distance := (point - points[0]).length_squared()
	var sign_value := 1.0
	var previous := count - 1
	for index in range(count):
		var edge := points[previous] - points[index]
		var offset := point - points[index]
		var projected := offset - edge * clampf(offset.dot(edge) / edge.dot(edge), 0.0, 1.0)
		distance = minf(distance, projected.dot(projected))
		var above := point.y >= points[index].y
		var below := point.y < points[previous].y
		var left := edge.x * offset.y > edge.y * offset.x
		if (above and below and left) or ((not above) and (not below) and (not left)):
			sign_value = -sign_value
		previous = index
	return sign_value * sqrt(distance)


# --- Constructores de formas ----------------------------------------------

func _ellipse(out: Array[Dictionary], center: Vector2, radii: Vector2, rotation: float, color: Color) -> void:
	out.append({"kind": "ellipse", "c": center, "r": radii, "rot": rotation, "color": color})


func _cone(out: Array[Dictionary], a: Vector2, b: Vector2, ra: float, rb: float, color: Color) -> void:
	out.append({"kind": "cone", "a": a, "b": b, "ra": ra, "rb": rb, "color": color})


func _poly(out: Array[Dictionary], points: PackedVector2Array, color: Color) -> void:
	out.append({"kind": "poly", "points": points, "color": color})


func _chain(out: Array[Dictionary], points: PackedVector2Array, radii: PackedFloat32Array, color: Color) -> void:
	for index in range(points.size() - 1):
		_cone(out, points[index], points[index + 1], radii[index], radii[index + 1], color)


func _tangent(points: PackedVector2Array, index: int) -> Vector2:
	var previous := maxi(0, index - 1)
	var next := mini(points.size() - 1, index + 1)
	var direction := points[next] - points[previous]
	if direction.is_zero_approx():
		return Vector2.RIGHT
	return direction.normalized()


# --- EXP01 · Ciempiés de Agujas -------------------------------------------

func _centipede_poses() -> Array:
	return [
		_centipede(280.0, 34.0, 0.0, 1.15, 26.0, 0.0),
		_centipede(280.0, -34.0, 0.0, 1.15, 26.0, 0.0),
		_centipede(224.0, 16.0, 0.6, 1.45, 32.0, 6.0),
		_centipede(200.0, 8.0, 1.1, 1.6, 48.0, 20.0),
		_centipede(330.0, 3.0, 0.0, 0.9, 14.0, 0.0),
		_centipede(206.0, 54.0, 0.35, 0.62, 10.0, 34.0),
	]


# `needle` estira las agujas y `head_drop` baja la cabeza: son los dos gestos que
# separan el aviso del avance sin depender de texto.
func _centipede(length: float, amplitude: float, phase: float, frequency: float, needle: float, head_drop: float) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var segments := 12
	var spine := PackedVector2Array()
	var radii := PackedFloat32Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var envelope := pow(sin(t * PI), 0.45)
		var x := (t - 0.5) * length
		var y := amplitude * sin(t * TAU * frequency + phase) * envelope
		y += head_drop * smoothstep(0.55, 1.0, t)
		spine.append(Vector2(x, y))
		radii.append(15.0 + 11.0 * t)

	# Patas y agujas van debajo del cuerpo para que las placas las tapen en la base.
	for index in range(1, segments):
		var point := spine[index]
		var tangent := _tangent(spine, index)
		var normal := Vector2(-tangent.y, tangent.x)
		var radius := radii[index]
		var swing := sin(float(index) * 1.7 + phase) * 7.0
		for side: float in [-1.0, 1.0]:
			var foot := point + normal * side * (radius + 22.0) - tangent * (10.0 + swing * side)
			_cone(shapes, point + normal * side * radius * 0.4, foot, 6.0, 3.0, C1_PLATE_DARK)

	for index in range(1, segments):
		var point := spine[index]
		var tangent := _tangent(spine, index)
		var normal := Vector2(-tangent.y, tangent.x)
		var radius := radii[index]
		for side: float in [-1.0, 1.0]:
			var base := point + normal * side * radius * 0.6
			var tip := base + normal * side * needle - tangent * needle * 0.85
			_cone(shapes, base, tip, 5.5, 1.2, C1_NEEDLE)

	_chain(shapes, spine, radii, C1_PLATE)

	# Franja dorsal: el plano claro que da la lectura cenital 3/4.
	var dorsal := PackedVector2Array()
	var dorsal_radii := PackedFloat32Array()
	for index in range(spine.size()):
		var tangent := _tangent(spine, index)
		var normal := Vector2(-tangent.y, tangent.x)
		dorsal.append(spine[index] - normal * radii[index] * 0.28)
		dorsal_radii.append(radii[index] * 0.44)
	_chain(shapes, dorsal, dorsal_radii, C1_PLATE_LIGHT)

	var head := spine[segments]
	var forward := _tangent(spine, segments)
	var side_vector := Vector2(-forward.y, forward.x)
	var head_center := head + forward * 14.0
	_ellipse(shapes, head_center, Vector2(34.0, 27.0), forward.angle(), C1_PLATE)
	_ellipse(shapes, head_center - side_vector * 6.0, Vector2(22.0, 15.0), forward.angle(), C1_PLATE_LIGHT)
	for side: float in [-1.0, 1.0]:
		var jaw_base := head_center + forward * 20.0 + side_vector * side * 11.0
		var jaw_tip := jaw_base + forward * 26.0 + side_vector * side * 12.0
		_cone(shapes, jaw_base, jaw_tip, 6.0, 2.0, C1_PLATE_DARK)
	_ellipse(shapes, head_center + forward * 8.0 - side_vector * 11.0, Vector2(9.0, 7.0), 0.0, C1_GLOW)
	return shapes


# --- EXP02 · Arácnido Blindado --------------------------------------------

func _spider_poses() -> Array:
	return [
		_spider(1.0, Vector2(1.0, 1.0), 1.0, 0.0, 0.0, 0.0, 0.55),
		_spider(1.0, Vector2(1.0, 1.0), 1.0, 0.0, PI, 0.0, 0.55),
		_spider(0.96, Vector2(0.97, 1.03), 1.48, 1.0, 0.4, -6.0, 0.35),
		_spider(1.0, Vector2(1.06, 0.96), 0.86, 0.5, 0.4, 34.0, 0.8),
		_spider(1.08, Vector2(1.0, 1.0), 1.02, 0.0, 0.0, 0.0, 0.95),
		_spider(0.94, Vector2(1.2, 0.82), 0.94, 0.0, 0.0, -8.0, 0.0),
	]


# `stance` es la clave de lectura: negativo encoge las patas contra el cuerpo
# (impacto) y muy positivo las abre en estrella (aviso de aplastamiento). Los dos
# avisos del arácnido tienen que distinguirse de un vistazo o el bicho es injusto.
func _spider(
	shell_scale: float,
	shell_squash: Vector2,
	abdomen: float,
	mouth: float,
	gait: float,
	head_out: float,
	stance: float
) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var radius := 56.0 * shell_scale

	for side: float in [-1.0, 1.0]:
		var base_angles := [30.0, 68.0, 112.0, 150.0]
		for slot in range(base_angles.size()):
			var angle := deg_to_rad(float(base_angles[slot]) * side)
			var step := sin(gait + float(slot) * 1.9 + (0.0 if side > 0.0 else PI)) * 0.16
			var femur := 46.0 + stance * 26.0
			var tibia := 50.0 + stance * 30.0
			var bend := 1.0 - stance * 0.62 + step
			var joint := Vector2.RIGHT.rotated(angle) * radius * 0.92
			var knee := joint + Vector2.RIGHT.rotated(angle + bend * side) * femur
			var foot := knee + Vector2.RIGHT.rotated(angle - bend * 1.5 * side) * tibia
			_cone(shapes, joint, knee, 11.0, 8.0, C2_LEG)
			_cone(shapes, knee, foot, 8.0, 3.0, C2_LEG)

	# El abdomen retrocede al inflarse: si creciera en el sitio quedaría tapado por
	# el caparazón y el aviso de disparo no se leería.
	var abdomen_center := Vector2(-radius * 0.72 - 26.0 * abdomen, 0.0)
	_ellipse(shapes, abdomen_center, Vector2(52.0, 44.0) * abdomen, 0.0, C2_ABDOMEN)
	_ellipse(shapes, abdomen_center - Vector2(2.0, 12.0), Vector2(30.0, 21.0) * abdomen, 0.0, C2_SHELL_LIGHT)

	var shell := PackedVector2Array()
	for slot in range(8):
		var angle := deg_to_rad(22.5 + 45.0 * float(slot))
		var point := Vector2.RIGHT.rotated(angle) * radius
		shell.append(Vector2(point.x * shell_squash.x, point.y * shell_squash.y))
	_poly(shapes, shell, C2_SHELL)

	var inner := PackedVector2Array()
	for point: Vector2 in shell:
		inner.append(point * 0.62 + Vector2(0.0, -8.0))
	_poly(shapes, inner, C2_SHELL_LIGHT)
	_ellipse(shapes, Vector2(0.0, 14.0), Vector2(26.0, 14.0) * shell_scale, 0.0, C2_SHELL_DARK)

	var head_center := Vector2(radius * shell_squash.x * 0.86 + head_out, 0.0)
	_ellipse(shapes, head_center, Vector2(26.0, 22.0), 0.0, C2_SHELL_DARK)
	for side: float in [-1.0, 1.0]:
		var fang_base := head_center + Vector2(14.0, side * 11.0)
		_cone(shapes, fang_base, fang_base + Vector2(26.0, side * 9.0), 6.0, 1.6, C2_SHELL_LIGHT)
	if mouth > 0.0:
		_ellipse(shapes, head_center + Vector2(9.0, 0.0), Vector2(11.0, 9.0) * mouth, 0.0, C2_GLOW)
	return shapes


# --- EXP03 · Saurio Escamado ----------------------------------------------

func _saurian_poses() -> Array:
	return [
		_saurian(Vector2(1.0, 1.0), 0.0, 0.05, 0.10, 0.0),
		_saurian(Vector2(1.0, 1.0), PI, -0.05, -0.10, 0.0),
		_saurian(Vector2(0.98, 1.02), 0.5, 0.26, -0.10, 0.0),
		_saurian(Vector2(0.92, 1.12), 1.0, 0.46, -0.55, 0.0),
		_saurian(Vector2(1.06, 0.94), 1.4, 0.30, -1.50, 0.0),
		_saurian(Vector2(1.04, 0.98), 2.2, -0.14, 0.60, 0.16),
	]


func _saurian(
	body_scale: Vector2,
	gait: float,
	tail_curl: float,
	tail_sway: float,
	tilt: float
) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []

	# Cola: cadena que nace en la grupa y acumula curvatura paso a paso. Con
	# `tail_curl` alto envuelve el cuerpo, que es el fotograma del barrido.
	var tail := PackedVector2Array()
	var tail_radii := PackedFloat32Array()
	var point := Vector2(-64.0, 0.0).rotated(tilt)
	var angle := PI + tail_sway + tilt
	for index in range(9):
		tail.append(point)
		tail_radii.append(30.0 - float(index) * 3.0)
		angle += tail_curl
		point += Vector2.RIGHT.rotated(angle) * 21.0
	_chain(shapes, tail, tail_radii, C3_HIDE)

	for side: float in [-1.0, 1.0]:
		for slot in range(2):
			var hip := Vector2(48.0 - 96.0 * float(slot), side * 28.0).rotated(tilt)
			var step := sin(gait + float(slot) * PI + (0.0 if side > 0.0 else PI)) * 26.0
			var knee := hip + Vector2(step * 0.5, side * 34.0).rotated(tilt)
			var foot := knee + Vector2(step, side * 32.0).rotated(tilt)
			_cone(shapes, hip, knee, 15.0, 11.0, C3_LIMB)
			_cone(shapes, knee, foot, 11.0, 7.0, C3_HIDE_DARK)

	var body_center := Vector2.ZERO
	_ellipse(shapes, body_center, Vector2(84.0, 48.0) * body_scale, tilt, C3_HIDE)
	_ellipse(shapes, Vector2(-6.0, -8.0).rotated(tilt), Vector2(58.0, 26.0) * body_scale, tilt, C3_HIDE_LIGHT)

	# Fila de escamas dorsales: repite el plano claro y marca hacia dónde va.
	for slot in range(5):
		var t := float(slot) / 4.0
		var scale_center := Vector2(-52.0 + 104.0 * t, -6.0).rotated(tilt)
		_ellipse(shapes, scale_center, Vector2(15.0 - 4.0 * t, 9.0), tilt, C3_PLATE)

	var head := PackedVector2Array([
		Vector2(64.0, -44.0).rotated(tilt),
		Vector2(122.0, -26.0).rotated(tilt),
		Vector2(164.0, -9.0).rotated(tilt),
		Vector2(164.0, 9.0).rotated(tilt),
		Vector2(122.0, 26.0).rotated(tilt),
		Vector2(64.0, 44.0).rotated(tilt),
	])
	_poly(shapes, head, C3_HIDE)
	_ellipse(shapes, Vector2(100.0, -9.0).rotated(tilt), Vector2(34.0, 14.0), tilt, C3_PLATE)
	# Sin ojos: el surco de la mandíbula es el único rasgo de la cabeza y es lo
	# que comunica que el saurio es ciego.
	_cone(
		shapes,
		Vector2(78.0, 15.0).rotated(tilt),
		Vector2(158.0, 5.0).rotated(tilt),
		9.0,
		3.0,
		C3_HIDE_DARK
	)
	return shapes


# --- Quimera Albina · jefe -------------------------------------------------

func _chimera_poses() -> Array:
	# La envergadura se mantiene por debajo de la mitad del ancho: la silueta del
	# jefe tiene que caber en 350 x 205 px, que es la huella que ya ocupaba el
	# `Sprite2D` estático en pantalla.
	return [
		_chimera(Vector2(1.0, 1.0), 66.0, 24.0, 0.0, 1.0),
		_chimera(Vector2(1.0, 1.0), 34.0, -18.0, 0.0, 1.0),
		_chimera(Vector2(0.95, 1.06), 20.0, -30.0, 0.0, 1.3),
		_chimera(Vector2(0.90, 1.12), 10.0, -40.0, 0.0, 1.8),
		_chimera(Vector2(1.18, 0.86), 40.0, 60.0, 20.0, 1.1),
		_chimera(Vector2(1.12, 1.18), 78.0, -12.0, -22.0, 0.6),
	]


func _chimera(
	body_scale: Vector2,
	wing_spread: float,
	wing_sweep: float,
	head_out: float,
	organ: float
) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []

	for side: float in [-1.0, 1.0]:
		var shoulder := Vector2(58.0, side * 22.0)
		var tip := Vector2(10.0 + wing_sweep * 0.8, side * (50.0 + wing_spread * 0.92))
		var trailing := Vector2(-52.0 + wing_sweep * 0.45, side * (46.0 + wing_spread))
		var membrane := PackedVector2Array([
			shoulder,
			Vector2(44.0 + wing_sweep, side * (36.0 + wing_spread * 0.42)),
			tip,
			trailing,
			Vector2(-116.0 + wing_sweep * 0.15, side * (32.0 + wing_spread * 0.68)),
			Vector2(-146.0, side * 26.0),
			Vector2(-64.0, side * 18.0),
		])
		_poly(shapes, membrane, C4_MEMBRANE)
		# Panel interior: separa el ala del torso sin cerrar la silueta, para que
		# no se lea como una pared sólida por delante de la cápsula de contacto.
		var inner := PackedVector2Array()
		for point: Vector2 in membrane:
			inner.append(shoulder + (point - shoulder) * 0.66)
		_poly(shapes, inner, C4_BONE)
		_cone(shapes, shoulder, tip, 13.0, 5.0, C4_BONE)
		_cone(shapes, tip, trailing, 5.0, 3.0, C4_BONE)

	for side: float in [-1.0, 1.0]:
		for slot in range(2):
			var hip := Vector2(52.0 - 116.0 * float(slot), side * 40.0)
			var paw := hip + Vector2(18.0 - 26.0 * float(slot), side * 40.0)
			_cone(shapes, hip, paw, 17.0, 11.0, C4_BODY_DARK)
			for claw in range(3):
				var spread := (float(claw) - 1.0) * 9.0
				_cone(
					shapes,
					paw,
					paw + Vector2(16.0 + spread, side * 16.0),
					5.0,
					1.6,
					C4_CLAW
				)

	var tail := PackedVector2Array([
		Vector2(-118.0, 0.0),
		Vector2(-166.0, 10.0),
		Vector2(-204.0, 4.0),
	])
	_chain(shapes, tail, PackedFloat32Array([22.0, 12.0, 5.0]), C4_BODY_DARK)

	_ellipse(shapes, Vector2.ZERO, Vector2(118.0, 66.0) * body_scale, 0.0, C4_BODY)
	_ellipse(shapes, Vector2(-6.0, -12.0), Vector2(78.0, 34.0) * body_scale, 0.0, C4_BONE)

	var head_center := Vector2(128.0 + head_out, 0.0)
	_ellipse(shapes, head_center, Vector2(52.0, 42.0), 0.0, C4_BODY)
	var snout := PackedVector2Array([
		head_center + Vector2(24.0, -26.0),
		head_center + Vector2(66.0, -12.0),
		head_center + Vector2(66.0, 12.0),
		head_center + Vector2(24.0, 26.0),
	])
	_poly(shapes, snout, C4_BODY_DARK)
	for side: float in [-1.0, 1.0]:
		var horn_base := head_center + Vector2(-6.0, side * 30.0)
		_cone(shapes, horn_base, horn_base + Vector2(28.0, side * 26.0), 8.0, 2.0, C4_BONE)
	# Órgano frontal: es el único punto luminoso y crece al apuntar, así el
	# jugador sabe hacia dónde va el salto antes de que empiece.
	_ellipse(shapes, head_center + Vector2(28.0, 0.0), Vector2(17.0, 14.0) * organ, 0.0, C4_GLOW)
	return shapes
