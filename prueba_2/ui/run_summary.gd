extends Control

const PartsDB := preload("res://core/parts_db.gd")

const BG_DEFAULT := preload("res://assets/ui/summary/run_summary_bg.png")
const BG_DEATH := preload("res://assets/ui/summary/run_summary_death.png")
const BG_ESCAPE := preload("res://assets/ui/summary/run_summary_escape.png")

## Cada final tiene fondo, titular y color propios. La clave es `reason` de
## `RunManager.summary()`; lo que no esté aquí cae en `_`.
const OUTCOMES := {
	&"death": {
		"background": BG_DEATH,
		"title": "TE CONTUVIERON",
		"color": Color(0.768627, 0.270588, 0.247059),
	},
	&"escape": {
		"background": BG_ESCAPE,
		"title": "ESCAPASTE",
		"color": Color(0.45098, 0.937255, 0.909804),
	},
}
const OUTCOME_FALLBACK := {
	"background": BG_DEFAULT,
	"title": "PARTIDA TERMINADA",
	"color": Color(0.92549, 0.952941, 0.690196),
}

const SHADE_ALPHA := 0.62
const BG_FADE_TIME := 0.45
const BG_ZOOM_FROM := 1.06
const PANEL_FADE_TIME := 0.32
const PANEL_RISE := 40.0
const CONTENT_STAGGER := 0.055

@onready var background: TextureRect = $Background
@onready var shade: ColorRect = $Shade
@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/Content
@onready var title_label: Label = $Panel/Content/Title
@onready var zone_label: Label = $Panel/Content/Zone
@onready var rooms_label: Label = $Panel/Content/Rooms
@onready var consumed_label: Label = $Panel/Content/Consumed
@onready var sacrificed_label: Label = $Panel/Content/Sacrificed
@onready var seed_label: Label = $Panel/Content/Seed
@onready var new_run_button: Button = $Panel/Content/Actions/NewRun
@onready var title_button: Button = $Panel/Content/Actions/ToTitle


var _panel_base_y: float = 0.0
var _intro_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel_base_y = panel.position.y
	RunManager.run_ended.connect(_show_summary)
	new_run_button.pressed.connect(_new_run)
	title_button.pressed.connect(_to_title)


func _show_summary(data: Dictionary) -> void:
	zone_label.text = "ZONA · %s" % data["zone"]
	rooms_label.text = "SALAS VISITADAS · %d" % int(data["rooms_visited"])
	consumed_label.text = "PARTES COMIDAS · %s" % _part_names(data["consumed"])
	sacrificed_label.text = "PARTES SACRIFICADAS · %s" % _part_names(data["sacrificed"])
	seed_label.text = "SEED · %d" % int(data["seed"])
	_apply_outcome(StringName(data.get("reason", &"")))
	visible = true
	get_tree().paused = true
	_play_intro()
	new_run_button.grab_focus()


func outcome_for(reason: StringName) -> Dictionary:
	return OUTCOMES.get(reason, OUTCOME_FALLBACK)


func _apply_outcome(reason: StringName) -> void:
	var outcome: Dictionary = outcome_for(reason)
	background.texture = outcome["background"]
	title_label.text = outcome["title"]
	title_label.add_theme_color_override("font_color", outcome["color"])


func _play_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()

	background.pivot_offset = background.size * 0.5
	background.scale = Vector2.ONE * BG_ZOOM_FROM
	background.modulate.a = 0.0
	shade.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.position.y = _panel_base_y + PANEL_RISE
	for child: Node in content.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 0.0

	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(background, "modulate:a", 1.0, BG_FADE_TIME)
	_intro_tween.tween_property(background, "scale", Vector2.ONE, BG_FADE_TIME)
	_intro_tween.tween_property(shade, "modulate:a", 1.0, BG_FADE_TIME * 0.7)
	_intro_tween.tween_property(panel, "modulate:a", 1.0, PANEL_FADE_TIME).set_delay(0.12)
	_intro_tween.tween_property(panel, "position:y", _panel_base_y, PANEL_FADE_TIME).set_delay(0.12)

	var index: int = 0
	for child: Node in content.get_children():
		if not (child is CanvasItem):
			continue
		var delay: float = 0.24 + float(index) * CONTENT_STAGGER
		_intro_tween.tween_property(child, "modulate:a", 1.0, 0.2).set_delay(delay)
		index += 1


func _part_names(ids: Array) -> String:
	if ids.is_empty():
		return "NINGUNA"
	var names: Array[String] = []
	for id_value: Variant in ids:
		names.append(PartsDB.display_name(String(id_value)))
	return ", ".join(names)


func _new_run() -> void:
	get_tree().paused = false
	RunManager.start_new_run()
	get_tree().reload_current_scene()


func _to_title() -> void:
	get_tree().paused = false
	RunManager.active = false
	GameState.reset_run()
	Inventory.reset_run()
	get_tree().change_scene_to_file("res://ui/title.tscn")
