extends SceneTree

const OUTPUT_PATH := "res://artifacts/slime_charge_preview.png"


func _initialize() -> void:
	call_deferred("_capture_preview")


func _capture_preview() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		push_error("Preview capture could not load the main scene.")
		quit(1)
		return

	var preview_viewport := SubViewport.new()
	preview_viewport.size = Vector2i(1920, 1080)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.gui_disable_input = true
	root.add_child(preview_viewport)

	var main_instance := main_scene.instantiate()
	preview_viewport.add_child(main_instance)
	await process_frame

	var player := main_instance.get_node("Player") as SlimePlayer
	player.set_physics_process(false)
	player.begin_charge(Vector2.RIGHT)
	player.update_charge(Vector2.RIGHT, 0.75)
	await process_frame
	await process_frame

	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image := preview_viewport.get_texture().get_image()
	var error := image.save_png(absolute_output)
	if error != OK:
		push_error("Preview capture failed with error %s." % error)
		quit(1)
		return

	print("PREVIEW: %s" % absolute_output)
	quit(0)
