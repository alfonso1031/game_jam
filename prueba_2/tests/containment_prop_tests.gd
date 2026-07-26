extends Node

const ASSET_PATHS: Array[String] = [
	"res://assets/environment/containment/cabinet.png",
	"res://assets/environment/containment/grate.png",
	"res://assets/environment/containment/pipe.png",
	"res://assets/environment/containment/glass_tube.png",
	"res://assets/environment/containment/broken_glass_tube.png",
]

const PROP_SCENES: Dictionary = {
	"cabinet": "res://world/props/containment/cabinet.tscn",
	"pipe": "res://world/props/containment/pipe.tscn",
	"glass_tube": "res://world/props/containment/glass_tube.tscn",
	"broken_glass_tube": "res://world/props/containment/broken_glass_tube.tscn",
}

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset_path: String in ASSET_PATHS:
		_check(ResourceLoader.exists(asset_path), "%s existe" % asset_path)
		if ResourceLoader.exists(asset_path):
			_check(load(asset_path) is Texture2D, "%s importa como textura" % asset_path)

	for prop_id: String in PROP_SCENES:
		_test_prop(prop_id, PROP_SCENES[prop_id])

	_finish()


func _test_prop(prop_id: String, scene_path: String) -> void:
	_check(ResourceLoader.exists(scene_path), "%s tiene escena reutilizable" % prop_id)
	if not ResourceLoader.exists(scene_path):
		return

	var scene: PackedScene = load(scene_path)
	var prop: StaticBody2D = scene.instantiate()
	var sprite: Sprite2D = prop.get_node_or_null("Sprite") as Sprite2D
	_check(sprite != null, "%s usa Sprite2D" % prop_id)
	_check(sprite != null and sprite.texture != null, "%s asigna una textura al Sprite2D" % prop_id)
	_check(prop.has_method("footprint"), "%s expone footprint()" % prop_id)
	if prop.has_method("footprint"):
		var prop_footprint: Rect2 = prop.footprint()
		_check(prop_footprint.size.x > 0.0 and prop_footprint.size.y > 0.0, "%s tiene huella positiva" % prop_id)
		_test_base_collision(prop_id, prop, sprite, prop_footprint)
	else:
		_test_base_collision(prop_id, prop, sprite, Rect2())
	if prop_id == "broken_glass_tube":
		_check(prop.get_meta("story_prop", false) == true, "el tubo roto es narrativo")
	prop.free()


func _test_base_collision(
	prop_id: String,
	prop: StaticBody2D,
	sprite: Sprite2D,
	prop_footprint: Rect2
) -> void:
	var collision_shapes: Array[Node] = []
	for child: Node in prop.get_children():
		if child is CollisionShape2D:
			collision_shapes.append(child)
	_check(collision_shapes.size() == 1, "%s solo tiene una colision de base" % prop_id)
	if (
		collision_shapes.size() != 1
		or prop_footprint.size.y <= 0.0
		or sprite == null
		or sprite.texture == null
	):
		return

	var collision: CollisionShape2D = collision_shapes[0] as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	_check(rectangle != null, "%s usa colision rectangular" % prop_id)
	if rectangle == null:
		return
	var texture_size: Vector2 = sprite.texture.get_size()
	var visual_height: float = texture_size.y * abs(sprite.scale.y)
	_check(
		collision.position.y - rectangle.size.y * 0.5 >= -visual_height / 6.0,
		"%s ubica la colision en el tercio inferior visual" % prop_id
	)
	_check(
		rectangle.size.y <= visual_height / 3.0,
		"%s limita la colision al tercio inferior" % prop_id
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: containment props")
		get_tree().quit(0)
		return
	get_tree().quit(1)
