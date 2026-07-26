extends SceneTree

# Procesador reproducible de las hojas de enemigos de Contención.
#
# Toma las tres hojas 3 x 2 con fondo croma de `art_raw/`, les quita el croma,
# separa las seis poses y las deja centradas en el lienzo de runtime que pide
# `docs/superpowers/specs/2026-07-26-assets-enemigos-contencion-design.md`.
# La Quimera ilustrada tiene su propio pipeline de 23 fotogramas en
# `process_chimera_delivered_frames.gd`.
#
#   godot --headless --path prueba_2 --script res://tools/art/process_containment_enemy_sheets.gd
#
# El recorte es COMÚN a las seis poses, igual que en
# `process_exp07_claw_frames.gd`: si cada pose se ajustara por su cuenta al
# lienzo, la embestida estirada y la pose encogida saldrían del mismo tamaño y el
# bicho parecería cambiar de escala entre fotogramas. Un solo rectángulo conserva
# la escala y el punto de apoyo que el generador ya dejó alineados.

const SOURCE_ROOT := "res://../art_raw/enemigos/containment"

# Umbrales del croma. Por encima de `OPAQUE_THRESHOLD` el píxel se considera
# interior y conserva su color exacto; por debajo de `TRANSPARENT_THRESHOLD` es
# fondo y se borra del todo. Entre medias queda solo el borde antialias.
const OPAQUE_THRESHOLD := 0.94
const TRANSPARENT_THRESHOLD := 0.045
const CROP_MARGIN := 6

const CONFIG := {
	"exp01_centipede": {
		"output": "res://assets/enemies/exp01_centipede",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(116, 116),
		"names": [
			"exp01_approach_00", "exp01_approach_01",
			"exp01_windup_00", "exp01_windup_01",
			"exp01_charge_00", "exp01_rest_00",
		],
	},
	"exp02_spider": {
		"output": "res://assets/enemies/exp02_spider",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(112, 112),
		"names": [
			"exp02_reposition_00", "exp02_reposition_01",
			"exp02_shoot_windup_00", "exp02_shoot_release_00",
			"exp02_slam_windup_00", "exp02_slam_impact_00",
		],
	},
	"exp03_saurian": {
		"output": "res://assets/enemies/exp03_saurian",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(108, 108),
		"names": [
			"exp03_walk_00", "exp03_walk_01",
			"exp03_tail_windup_00", "exp03_tail_windup_01",
			"exp03_tail_sweep_00", "exp03_recover_00",
		],
	},
}


func _init() -> void:
	for character: String in CONFIG:
		if not _process_sheet(character, CONFIG[character]):
			quit(1)
			return
	print("CONTAINMENT_POSES_OK  personajes=%d  poses=%d" % [CONFIG.size(), CONFIG.size() * 6])
	quit(0)


func _process_sheet(character: String, config: Dictionary) -> bool:
	var source := "%s/%s/source_sheet.png" % [SOURCE_ROOT, character]
	var absolute_source := ProjectSettings.globalize_path(source).simplify_path()
	var sheet := Image.load_from_file(absolute_source)
	if sheet == null or sheet.is_empty():
		push_error("No se pudo cargar %s" % absolute_source)
		return false
	if sheet.get_width() % 3 != 0 or sheet.get_height() % 2 != 0:
		push_error("%s no admite una rejilla 3 x 2: %s" % [character, sheet.get_size()])
		return false

	var keyed := _remove_chroma(sheet)
	var alpha_dump := absolute_source.get_base_dir() + "/source_sheet_alpha.png"
	var error := keyed.save_png(alpha_dump)
	if error != OK:
		push_error("No se pudo guardar %s: %s" % [alpha_dump, error_string(error)])
		return false

	var cell := Vector2i(keyed.get_width() / 3, keyed.get_height() / 2)
	var cells: Array[Image] = []
	var shared_crop := Rect2i()
	for index in range(6):
		var region := keyed.get_region(Rect2i(Vector2i(index % 3, index / 3) * cell, cell))
		var used := region.get_used_rect()
		if used.size == Vector2i.ZERO:
			push_error("%s: la pose %d salió vacía" % [character, index])
			return false
		cells.append(region)
		shared_crop = used if shared_crop.size == Vector2i.ZERO else shared_crop.merge(used)
	shared_crop = shared_crop.grow(CROP_MARGIN).intersection(Rect2i(Vector2i.ZERO, cell))

	var canvas: Vector2i = config["canvas"]
	var fit: Vector2i = config["fit"]
	var ratio := minf(
		float(fit.x) / float(shared_crop.size.x),
		float(fit.y) / float(shared_crop.size.y)
	)
	var scaled := Vector2i(
		maxi(1, roundi(float(shared_crop.size.x) * ratio)),
		maxi(1, roundi(float(shared_crop.size.y) * ratio))
	)

	var output: String = config["output"]
	var absolute_output := ProjectSettings.globalize_path(output).simplify_path()
	error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("No se pudo crear %s: %s" % [absolute_output, error_string(error)])
		return false

	var names: Array = config["names"]
	for index in range(6):
		var pose := cells[index].get_region(shared_crop)
		var resized := _resize_rgba(pose, scaled)
		var sheet_canvas := Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		sheet_canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
		sheet_canvas.blit_rect(
			resized,
			Rect2i(Vector2i.ZERO, scaled),
			(canvas - scaled) / 2
		)
		var destination := "%s/%s.png" % [absolute_output, names[index]]
		error = sheet_canvas.save_png(destination)
		if error != OK:
			push_error("No se pudo guardar %s: %s" % [destination, error_string(error)])
			return false

	print("  %s  recorte=%s  escala=%s  lienzo=%s" % [character, shared_crop, scaled, canvas])
	return true


# --- Croma ------------------------------------------------------------------
#
# El fondo es `#ff00ff`: rojo y azul al máximo con el verde a cero. `spill` mide
# cuánto de esa firma queda en el píxel, así que sirve directamente como inverso
# del alfa. Después se deshace la composición sobre el croma, que es lo que
# elimina la orla magenta del borde sin recortarlo a diente de sierra.

func _remove_chroma(source: Image) -> Image:
	var image := source.duplicate() as Image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var count := image.get_width() * image.get_height()
	var out := PackedByteArray()
	out.resize(count * 4)

	for index in range(count):
		var offset := index * 4
		var r := float(data[offset]) / 255.0
		var g := float(data[offset + 1]) / 255.0
		var b := float(data[offset + 2]) / 255.0
		var spill := minf(r, b) - g
		var alpha := clampf(1.0 - spill, 0.0, 1.0)

		if alpha <= TRANSPARENT_THRESHOLD:
			continue
		if alpha < OPAQUE_THRESHOLD:
			var inverse := 1.0 - alpha
			r = clampf((r - inverse) / alpha, 0.0, 1.0)
			g = clampf(g / alpha, 0.0, 1.0)
			b = clampf((b - inverse) / alpha, 0.0, 1.0)
		else:
			alpha = 1.0
		out[offset] = int(round(r * 255.0))
		out[offset + 1] = int(round(g * 255.0))
		out[offset + 2] = int(round(b * 255.0))
		out[offset + 3] = int(round(alpha * 255.0))

	return Image.create_from_data(
		image.get_width(),
		image.get_height(),
		false,
		Image.FORMAT_RGBA8,
		out
	)


# `Image.resize()` interpola el RGB sin mirar el alfa, así que los píxeles
# transparentes —que son negros— tiñen el borde de oscuro. Premultiplicar antes
# y deshacerlo después es lo que evita ese halo.
func _resize_rgba(source: Image, size: Vector2i) -> Image:
	var work := _multiply_alpha(source, true)
	work.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return _multiply_alpha(work, false)


func _multiply_alpha(source: Image, forward: bool) -> Image:
	var data := source.get_data()
	var count := source.get_width() * source.get_height()
	var out := PackedByteArray()
	out.resize(count * 4)
	for index in range(count):
		var offset := index * 4
		var alpha := float(data[offset + 3]) / 255.0
		out[offset + 3] = data[offset + 3]
		if alpha <= 0.0:
			continue
		var factor := alpha if forward else 1.0 / alpha
		for channel in range(3):
			var value := float(data[offset + channel]) / 255.0
			out[offset + channel] = int(round(clampf(value * factor, 0.0, 1.0) * 255.0))
	return Image.create_from_data(
		source.get_width(),
		source.get_height(),
		false,
		Image.FORMAT_RGBA8,
		out
	)
