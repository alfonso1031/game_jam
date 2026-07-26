extends SceneTree

# Convierte las cuatro hojas RGBA entregadas en los frames de runtime del slime.
# El recorte se calcula una sola vez para las 25 celdas: así cada cambio de
# animación conserva escala y pivote aunque la silueta se estire o se aplaste.
#
#   godot --headless --path prueba_2 --script \
#     res://tools/art/process_slime_delivered_sheets.gd

const SOURCE_ROOT := "res://../art_raw/personaje/slime"
const OUTPUT_DIR := "res://assets/player/slime/animations"
const CELL_SIZE := Vector2i(320, 320)
const CANVAS_SIZE := Vector2i(128, 128)
const FIT_SIZE := Vector2i(96, 96)
const CROP_MARGIN := 8

const SEQUENCES := [
	{"animation": "idle", "source": "slime_idle_sheet.png", "frames": 5},
	{"animation": "walk", "source": "slime_walk_sheet.png", "frames": 2},
	{"animation": "jump", "source": "slime_jump_sheet.png", "frames": 6},
	{"animation": "recover", "source": "slime_recover_sheet.png", "frames": 12},
]


func _init() -> void:
	var frames: Array[Image] = []
	var names: Array[String] = []
	for sequence: Dictionary in SEQUENCES:
		var animation: String = str(sequence["animation"])
		var source: String = str(sequence["source"])
		var frame_count: int = int(sequence["frames"])
		if not _append_sheet(animation, source, frame_count, frames, names):
			quit(1)
			return

	var shared_crop: Rect2i = Rect2i()
	for frame: Image in frames:
		var used_rect: Rect2i = frame.get_used_rect()
		shared_crop = (
			used_rect
			if shared_crop.size == Vector2i.ZERO
			else shared_crop.merge(used_rect)
		)
	shared_crop = shared_crop.grow(CROP_MARGIN).intersection(
		Rect2i(Vector2i.ZERO, CELL_SIZE)
	)

	var ratio: float = minf(
		float(FIT_SIZE.x) / float(shared_crop.size.x),
		float(FIT_SIZE.y) / float(shared_crop.size.y)
	)
	var scaled_size: Vector2i = Vector2i(
		maxi(1, roundi(float(shared_crop.size.x) * ratio)),
		maxi(1, roundi(float(shared_crop.size.y) * ratio))
	)
	var absolute_output: String = ProjectSettings.globalize_path(OUTPUT_DIR).simplify_path()
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("No se pudo crear %s: %s" % [absolute_output, error_string(error)])
		quit(1)
		return

	for index: int in range(frames.size()):
		var cropped: Image = frames[index].get_region(shared_crop)
		var resized: Image = _resize_rgba(cropped, scaled_size)
		var canvas: Image = Image.create_empty(
			CANVAS_SIZE.x,
			CANVAS_SIZE.y,
			false,
			Image.FORMAT_RGBA8
		)
		canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
		canvas.blit_rect(
			resized,
			Rect2i(Vector2i.ZERO, scaled_size),
			(CANVAS_SIZE - scaled_size) / 2
		)
		var destination: String = "%s/%s.png" % [absolute_output, names[index]]
		error = canvas.save_png(destination)
		if error != OK:
			push_error("No se pudo guardar %s: %s" % [destination, error_string(error)])
			quit(1)
			return

	print("SLIME_ANIMATION_CROP crop=%s scale=%s canvas=%s" % [
		shared_crop,
		scaled_size,
		CANVAS_SIZE,
	])
	print("SLIME_ANIMATION_OK idle=5 walk=2 jump=6 recover=12")
	quit(0)


func _append_sheet(
	animation: String,
	filename: String,
	expected_frames: int,
	frames: Array[Image],
	names: Array[String]
) -> bool:
	var source_path: String = "%s/%s" % [SOURCE_ROOT, filename]
	var absolute_source: String = ProjectSettings.globalize_path(source_path).simplify_path()
	var sheet: Image = Image.load_from_file(absolute_source)
	if sheet == null or sheet.is_empty():
		push_error("No se pudo cargar %s" % source_path)
		return false
	if sheet.get_width() % CELL_SIZE.x != 0 or sheet.get_height() % CELL_SIZE.y != 0:
		push_error("%s no admite celdas exactas de %s" % [source_path, CELL_SIZE])
		return false
	if sheet.detect_alpha() == Image.ALPHA_NONE:
		push_error("%s no contiene canal alfa" % source_path)
		return false
	if sheet.get_format() != Image.FORMAT_RGBA8:
		sheet.convert(Image.FORMAT_RGBA8)

	var columns: int = sheet.get_width() / CELL_SIZE.x
	var rows: int = sheet.get_height() / CELL_SIZE.y
	var frame_count: int = columns * rows
	if frame_count != expected_frames:
		push_error("%s tiene %d celdas; se esperaban %d" % [
			source_path,
			frame_count,
			expected_frames,
		])
		return false

	for index: int in range(frame_count):
		var origin := Vector2i(index % columns, index / columns) * CELL_SIZE
		var frame: Image = sheet.get_region(Rect2i(origin, CELL_SIZE))
		if frame.get_used_rect().size == Vector2i.ZERO:
			push_error("%s: el frame %d tiene alfa vacío" % [source_path, index])
			return false
		frames.append(frame)
		names.append("slime_%s_%02d" % [animation, index])
	return true


# `Image.resize()` interpola el RGB transparente como negro. Premultiplicar
# alfa antes de Lanczos y deshacerlo después evita halos en los bordes.
func _resize_rgba(source: Image, size: Vector2i) -> Image:
	var work: Image = _multiply_alpha(source, true)
	work.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return _multiply_alpha(work, false)


func _multiply_alpha(source: Image, forward: bool) -> Image:
	var data: PackedByteArray = source.get_data()
	var count: int = source.get_width() * source.get_height()
	var output: PackedByteArray = PackedByteArray()
	output.resize(count * 4)
	for index: int in range(count):
		var offset: int = index * 4
		var alpha: float = float(data[offset + 3]) / 255.0
		output[offset + 3] = data[offset + 3]
		if alpha <= 0.0:
			continue
		var factor: float = alpha if forward else 1.0 / alpha
		for channel: int in range(3):
			var value: float = float(data[offset + channel]) / 255.0
			output[offset + channel] = int(
				round(clampf(value * factor, 0.0, 1.0) * 255.0)
			)
	return Image.create_from_data(
		source.get_width(),
		source.get_height(),
		false,
		Image.FORMAT_RGBA8,
		output
	)
