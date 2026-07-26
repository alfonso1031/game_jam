extends SceneTree

const SOURCE_DIR := "res://assets/enemies/exp07_crustacean/source_attack"
const OUTPUT_DIR := "res://assets/enemies/exp07_crustacean"
const OUTPUT_SIZE := Vector2i(192, 108)
const FRAME_COUNT := 5
const CROP_MARGIN := 24


func _init() -> void:
	var images: Array[Image] = []
	var shared_crop := Rect2i()

	for index in range(FRAME_COUNT):
		var source_path := "%s/claw_attack_%02d.png" % [SOURCE_DIR, index]
		var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if image == null or image.is_empty():
			push_error("No se pudo cargar %s" % source_path)
			quit(1)
			return
		var used_rect := image.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			push_error("%s no contiene pixeles visibles" % source_path)
			quit(1)
			return
		images.append(image)
		shared_crop = used_rect if shared_crop.size == Vector2i.ZERO else shared_crop.merge(used_rect)

	shared_crop = shared_crop.grow(CROP_MARGIN).intersection(
		Rect2i(Vector2i.ZERO, images[0].get_size())
	)
	for index in range(images.size()):
		var frame := images[index].get_region(shared_crop)
		frame.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var output_path := "%s/exp07_pinch_%02d.png" % [OUTPUT_DIR, index]
		var error := frame.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("No se pudo guardar %s: %s" % [output_path, error_string(error)])
			quit(1)
			return

	print("EXP07_ART_OK crop=%s output=%s frames=%d" % [
		shared_crop,
		OUTPUT_SIZE,
		images.size(),
	])
	quit(0)
