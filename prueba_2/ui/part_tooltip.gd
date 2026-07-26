extends PanelContainer

const PartsDB := preload("res://core/parts_db.gd")
const CURSOR_OFFSET := Vector2(18.0, 18.0)
const VIEWPORT_MARGIN := 8.0

@onready var title: Label = $Content/Title
@onready var body: Label = $Content/Body

var _active_part := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_part(part_id: String, anchor_position: Vector2) -> void:
	_active_part = part_id
	title.text = PartsDB.display_name(part_id)
	body.text = PartsDB.description(part_id)
	global_position = _clamp_to_viewport(anchor_position + CURSOR_OFFSET)
	show()


func hide_part() -> void:
	_active_part = ""
	hide()


func _input(event: InputEvent) -> void:
	if not visible or _active_part.is_empty():
		return
	if event is InputEventMouseMotion:
		global_position = _clamp_to_viewport(event.position + CURSOR_OFFSET)


func clamped_position() -> Vector2:
	return global_position


func tooltip_rect() -> Rect2:
	return Rect2(global_position, size)


func title_text() -> String:
	return title.text


func body_text() -> String:
	return body.text


func _clamp_to_viewport(desired: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var maximum := Vector2(
		maxf(VIEWPORT_MARGIN, viewport_size.x - size.x - VIEWPORT_MARGIN),
		maxf(VIEWPORT_MARGIN, viewport_size.y - size.y - VIEWPORT_MARGIN)
	)
	return Vector2(
		clampf(desired.x, VIEWPORT_MARGIN, maximum.x),
		clampf(desired.y, VIEWPORT_MARGIN, maximum.y)
	)
