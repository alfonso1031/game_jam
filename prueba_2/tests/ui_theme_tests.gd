extends Node

const THEME_PATH := "res://ui/game_theme.tres"
const SCENE_PATHS: Array[String] = [
	"res://ui/title.tscn",
	"res://ui/hud.tscn",
	"res://ui/map_overlay.tscn",
	"res://ui/pause_menu.tscn",
	"res://ui/run_summary.tscn",
	"res://ui/floor_route_overlay.tscn",
	"res://ui/grate_cost_overlay.tscn",
	"res://ui/ending.tscn",
]

var _failures: Array[String] = []


func _ready() -> void:
	_check(ResourceLoader.exists(THEME_PATH), "existe el tema visual compartido")
	var shared_theme: Theme = load(THEME_PATH) as Theme if ResourceLoader.exists(THEME_PATH) else null
	_check(shared_theme != null, "el tema visual carga como Theme")
	if shared_theme != null:
		_check(
			shared_theme.get_stylebox("normal", "Button") != null,
			"el tema define botones de laboratorio"
		)
		_check(
			shared_theme.get_stylebox("panel", "Panel") != null,
			"el tema define paneles de diagnóstico"
		)

	for path: String in SCENE_PATHS:
		_check_scene_theme(path, shared_theme)

	var title: Node = load("res://ui/title.tscn").instantiate()
	_check(title.get_node_or_null("MenuPlate") != null, "el menú tiene una placa visual")
	title.free()

	var hud: Node = load("res://ui/hud.tscn").instantiate()
	_check(hud.get_node_or_null("Health/Biomass") != null, "el HUD identifica la biomasa")
	hud.free()

	var main: Node = load("res://game/main.tscn").instantiate()
	var darkness := main.get_node_or_null("Darkness") as CanvasModulate
	_check(
		darkness != null and darkness.color.get_luminance() >= 0.33,
		"la luz ambiente permite leer el cuarto completo en penumbra"
	)
	main.free()
	_finish()


func _check_scene_theme(path: String, shared_theme: Theme) -> void:
	var scene: PackedScene = load(path) as PackedScene
	_check(scene != null, "%s carga" % path)
	if scene == null:
		return
	var root: Control = scene.instantiate() as Control
	_check(root != null and root.theme == shared_theme, "%s usa el tema compartido" % path)
	root.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure: String in _failures:
		push_error(failure)
	print("PASS: UI theme" if _failures.is_empty() else "FAIL: UI theme")
	get_tree().quit(0 if _failures.is_empty() else 1)
