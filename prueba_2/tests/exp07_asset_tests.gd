extends Node

var failures: Array[String] = []


func _ready() -> void:
	for index in range(5):
		var path := "res://assets/enemies/exp07_crustacean/exp07_pinch_%02d.png" % index
		_check(ResourceLoader.exists(path), "%s existe" % path)
		var texture := load(path) as Texture2D
		_check(texture != null, "%s importa como textura" % path)
		if texture != null:
			_check(texture.get_size() == Vector2(192, 108), "%s usa tamaño runtime" % path)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: EXP07 attack assets" if failures.is_empty() else "FAIL: EXP07 attack assets")
	get_tree().quit(0 if failures.is_empty() else 1)
