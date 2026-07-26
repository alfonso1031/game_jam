extends SceneTree

# Procesa la entrega ilustrada de la Quimera sin importar los PNG fuente
# de 1920 x 1080 al proyecto Godot.
#
#   godot --headless --path prueba_2 --script \
#     res://tools/art/process_chimera_delivered_frames.gd
#
# Un solo recorte para los 23 fotogramas conserva la escala y el pivote
# durante el cambio entre Idle y Angry.

const SOURCE_ROOT := "res://../art_raw/enemigos/containment/boss_chimera"
const OUTPUT_DIR := "res://assets/bosses/containment_chimera/animations"
const CANVAS_SIZE := Vector2i(384, 256)
const FIT_SIZE := Vector2i(350, 205)
const CROP_MARGIN := 12
const IDLE_COUNT := 7
const ANGRY_COUNT := 16


func _init() -> void:
	var images: Array[Image] = []
	var names: Array[String] = []
	if not _append_sequence("idle", IDLE_COUNT, images, names):
		quit(1)
		return
	if not _append_sequence("angry", ANGRY_COUNT, images, names):
		quit(1)
		return

	var shared_crop: Rect2i = Rect2i()
	for image: Image in images:
		var used_rect: Rect2i = image.get_used_rect()
		shared_crop = (
			used_rect
			if shared_crop.size == Vector2i.ZERO
			else shared_crop.merge(used_rect)
		)
	shared_crop = shared_crop.grow(CROP_MARGIN).intersection(
		Rect2i(Vector2i.ZERO, images[0].get_size())
	)

	var ratio: float = minf(
		float(FIT_SIZE.x) / float(shared_crop.size.x),
		float(FIT_SIZE.y) / float(shared_crop.size.y)
	)
	var scaled_size := Vector2i(
		maxi(1, roundi(float(shared_crop.size.x) * ratio)),
		maxi(1, roundi(float(shared_crop.size.y) * ratio))
	)
	var absolute_output: String = ProjectSettings.globalize_path(OUTPUT_DIR).simplify_path()
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("No se pudo crear %s: %s" % [absolute_output, error_string(error)])
		quit(1)
		return

	for index in range(images.size()):
		var frame: Image = images[index].get_region(shared_crop)
		var resized: Image = _resize_rgba(frame, scaled_size)
		var canvas := Image.create_empty(
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
		var destination := "%s/%s.png" % [absolute_output, names[index]]
		error = canvas.save_png(destination)
		if error != OK:
			push_error("No se pudo guardar %s: %s" % [destination, error_string(error)])
			quit(1)
			return

	print("CHIMERA_ANIMATION_CROP crop=%s scale=%s canvas=%s" % [
		shared_crop,
		scaled_size,
		CANVAS_SIZE,
	])
	print("CHIMERA_ANIMATION_OK idle=%d angry=%d" % [IDLE_COUNT, ANGRY_COUNT])
	quit(0)


func _append_sequence(
	animation: String,
	count: int,
	images: Array[Image],
	names: Array[String]
) -> bool:
	for index in range(count):
		var source_path := "%s/%s/chimera_%s_source_%02d.png" % [
			SOURCE_ROOT,
			animation,
			animation,
			index,
		]
		var image: Image = Image.load_from_file(
			ProjectSettings.globalize_path(source_path)
		)
		if image == null or image.is_empty():
			push_error("No se pudo cargar %s" % source_path)
			return false
		if image.detect_alpha() == Image.ALPHA_NONE:
			push_error("%s no contiene un canal alfa" % source_path)
			return false
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		if not images.is_empty() and image.get_size() != images[0].get_size():
			push_error("%s no mide %s" % [source_path, images[0].get_size()])
			return false
		if image.get_used_rect().size == Vector2i.ZERO:
			push_error("%s no contiene pixeles visibles" % source_path)
			return false
		images.append(image)
		names.append("chimera_%s_%02d" % [animation, index])
	return true


# `Image.resize()` interpola el RGB transparente como negro. Premultiplicar
# el alfa antes del Lanczos y deshacerlo después evita halos en el contorno.
func _resize_rgba(source: Image, size: Vector2i) -> Image:
	var work: Image = _multiply_alpha(source, true)
	work.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return _multiply_alpha(work, false)


func _multiply_alpha(source: Image, forward: bool) -> Image:
	var data: PackedByteArray = source.get_data()
	var count: int = source.get_width() * source.get_height()
	var output := PackedByteArray()
	output.resize(count * 4)
	for index in range(count):
		var offset: int = index * 4
		var alpha: float = float(data[offset + 3]) / 255.0
		output[offset + 3] = data[offset + 3]
		if alpha <= 0.0:
			continue
		var factor: float = alpha if forward else 1.0 / alpha
		for channel in range(3):
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
