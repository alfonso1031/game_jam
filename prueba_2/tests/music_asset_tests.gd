extends Node

const MENU_PATH := "res://assets/audio/music/main_menu.ogg"
const GAMEPLAY_PATH := "res://assets/audio/music/containment_ambience.ogg"
const CHIMERA_IDLE_PATH := "res://assets/bosses/containment_chimera/animations/chimera_idle_00.png"
const CHIMERA_ANGRY_PATH := "res://assets/bosses/containment_chimera/animations/chimera_angry_00.png"
const ARENA_PATH := "res://assets/environment/containment/chimera_arena.png"
const TitleScene := preload("res://ui/title.tscn")
const MainScene := preload("res://game/main.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_check_asset(MENU_PATH, "carga la música del menú")
	_check_asset(GAMEPLAY_PATH, "carga la música de Contención")
	_check_texture(CHIMERA_IDLE_PATH, "carga la animación Idle de la Quimera")
	_check_texture(CHIMERA_ANGRY_PATH, "carga la animación Angry de la Quimera")
	_check_texture(ARENA_PATH, "carga el decal de la arena")
	_check_music_player(TitleScene, MENU_PATH, "menú")
	_check_music_player(MainScene, GAMEPLAY_PATH, "partida")
	_finish()


func _check_asset(path: String, message: String) -> void:
	_check(ResourceLoader.exists(path), message)
	if ResourceLoader.exists(path):
		_check(load(path) != null, "%s como recurso" % message)


func _check_texture(path: String, message: String) -> void:
	_check_asset(path, message)
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	_check(texture != null and texture.get_size().x > 0.0, "%s con dimensiones" % message)


func _check_music_player(scene: PackedScene, stream_path: String, label: String) -> void:
	var root: Node = scene.instantiate()
	var music := root.get_node_or_null("Music") as AudioStreamPlayer
	_check(music != null, "%s incluye reproductor Music" % label)
	_check(
		music != null
		and music.stream != null
		and music.stream.resource_path == stream_path,
		"%s usa la pista correcta" % label
	)
	_check(music != null and music.autoplay, "%s inicia la música automáticamente" % label)
	_check(root.has_method("_on_music_finished"), "%s mantiene reproducción continua" % label)
	root.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print(
		"PASS: music and presentation assets"
		if failures.is_empty()
		else "FAIL: music and presentation assets"
	)
	get_tree().quit(0 if failures.is_empty() else 1)
