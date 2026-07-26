extends Node

var failures: Array[String] = []


func _ready() -> void:
	for path: String in [
		"res://assets/ui/title/title_contained.png",
		"res://assets/ui/title/title_escaped.png",
	]:
		_check(ResourceLoader.exists(path), "%s existe" % path)
		var texture := load(path) as Texture2D
		_check(texture != null, "%s importa como textura" % path)
		if texture != null:
			_check(texture.get_size() == Vector2(1920, 1080), "%s conserva 1080p" % path)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: title intro" if failures.is_empty() else "FAIL: title intro")
	get_tree().quit(0 if failures.is_empty() else 1)
