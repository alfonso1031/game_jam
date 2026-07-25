extends Control

# Pantalla de las seis partes. Se abre con [I] y pausa el juego.
#
# Controles:
#   WASD/flechas  mover la selección
#   [E]           equipar la parte pendiente en el hueco seleccionado
#   [F]           consumir: la parte se digiere y da medio corazón de vida
#   [I] / [Esc]   cerrar
#
# Todo se dibuja a mano con primitivas, igual que el resto de la interfaz del
# proyecto: no hay temas ni texturas de por medio.

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

const PANEL := Rect2(260, 130, 1400, 820)
const SLOT_SIZE := Vector2(400, 150)
const SLOT_GAP := Vector2(40, 26)
const GRID_ORIGIN := Vector2(340, 300)
const COLUMNS := 2
# Índice extra que representa la parte pendiente, debajo de la rejilla.
const PENDING_INDEX := 6

var _selected: int = 0
var _message: String = ""
var _message_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Inventory.slots_changed.connect(_on_inventory_changed)
	Inventory.pending_changed.connect(_on_pending_changed)
	Inventory.rejected.connect(_on_rejected)
	GameState.health_changed.connect(_on_inventory_changed)

func _process(delta: float) -> void:
	if _message_time <= 0.0:
		return
	_message_time -= delta
	if _message_time <= 0.0:
		_message = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		# Si otro overlay ya pausó (mapa, pausa, final), no se abre encima.
		if not visible and get_tree().paused:
			return
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return

	if event.is_action_pressed("pause"):
		_toggle()
	elif event.is_action_pressed("move_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("move_right"):
		_move_selection(1, 0)
	elif event.is_action_pressed("move_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("move_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("interact"):
		_equip_pending()
	elif event.is_action_pressed("consume"):
		_consume()
	else:
		return
	get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_selected = 0
		_message = ""
		queue_redraw()

func _move_selection(dx: int, dy: int) -> void:
	# La parte pendiente es una fila más al fondo de la rejilla.
	if _selected == PENDING_INDEX:
		if dy < 0:
			_selected = 4
		queue_redraw()
		return

	var column: int = _selected % COLUMNS
	var row: int = _selected / COLUMNS
	if dy > 0 and row == 2 and Inventory.pending != "":
		_selected = PENDING_INDEX
		queue_redraw()
		return

	column = clampi(column + dx, 0, COLUMNS - 1)
	row = clampi(row + dy, 0, 2)
	_selected = row * COLUMNS + column
	queue_redraw()

func _equip_pending() -> void:
	if Inventory.pending == "":
		_notify("No hay parte pendiente")
		return
	if _selected == PENDING_INDEX:
		_notify("Elige un hueco donde ponerla")
		return
	if Inventory.place_in_slot(Inventory.pending, _selected):
		_notify("Parte equipada")

func _consume() -> void:
	if _selected == PENDING_INDEX:
		if Inventory.consume_pending():
			_notify("Parte consumida · +½ corazón")
		return
	var id := Inventory.part_at(_selected)
	if id == "":
		_notify("Ese hueco está vacío")
		return
	if GameState.health_halves >= GameState.max_health_halves:
		_notify("Vida al máximo: consumirla sería tirarla")
		return
	if Inventory.consume_slot(_selected):
		_notify("%s consumida · +½ corazón" % PartsDB.display_name(id))

func _notify(text: String) -> void:
	_message = text
	_message_time = 2.5
	queue_redraw()

func _on_inventory_changed(_arg = null) -> void:
	if visible:
		queue_redraw()

func _on_pending_changed(_part_id: String) -> void:
	if visible:
		queue_redraw()

func _on_rejected(reason: String) -> void:
	_notify(reason)

# --- Dibujo ---

func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(Palette.VOID, 0.93), true)
	draw_rect(PANEL, Color(Palette.VOID, 0.85), true)
	draw_rect(PANEL, Palette.WALL, false, 3.0)

	draw_string(font, PANEL.position + Vector2(0, 66), "PARTES ASIMILADAS", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 44, Palette.WARM_LIGHT)
	draw_string(font, PANEL.position + Vector2(0, 112), _health_line(), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 26, Palette.SLIME_CORE)

	for i in range(Inventory.SLOT_COUNT):
		_draw_slot(font, i)
	_draw_pending(font)
	_draw_footer(font)

func _health_line() -> String:
	var hearts: float = GameState.health_halves * 0.5
	var max_hearts: float = GameState.max_health_halves * 0.5
	var bonus: float = (GameState.base_damage_multiplier() - 1.0) * 100.0
	return "VIDA %.1f / %.1f · BONO DE DAÑO +%.1f%%" % [hearts, max_hearts, bonus]

func _slot_rect(index: int) -> Rect2:
	var column: int = index % COLUMNS
	var row: int = index / COLUMNS
	var origin: Vector2 = GRID_ORIGIN + Vector2(
		column * (SLOT_SIZE.x + SLOT_GAP.x),
		row * (SLOT_SIZE.y + SLOT_GAP.y)
	)
	return Rect2(origin, SLOT_SIZE)

func _draw_slot(font: Font, index: int) -> void:
	var rect := _slot_rect(index)
	var id := Inventory.part_at(index)
	var selected: bool = _selected == index

	draw_rect(rect, Color(Palette.FLOOR, 0.55 if id != "" else 0.25), true)
	draw_rect(rect, Palette.SLIME_CORE if selected else Palette.WALL, false, 4.0 if selected else 2.0)

	draw_string(font, rect.position + Vector2(16, 32), Inventory.slot_label(index), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 20, Palette.WALL.lightened(0.4))
	if id != "":
		# El origen es sabor, no requisito: se muestra a la derecha y pequeño.
		draw_string(font, rect.position + Vector2(rect.size.x - 230, 32), PartsDB.get_part(id).get("source", ""), HORIZONTAL_ALIGNMENT_RIGHT, 214, 16, Palette.WALL.lightened(0.3))

	if id == "":
		draw_string(font, rect.position + Vector2(16, 84), "— vacío —", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 26, Palette.WALL)
		return

	var name_color: Color = Palette.WARM_LIGHT if PartsDB.is_boss_part(id) else Palette.SLIME_CORE
	draw_string(font, rect.position + Vector2(16, 74), PartsDB.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 28, name_color)
	draw_multiline_string(font, rect.position + Vector2(16, 106), PartsDB.get_part(id).get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 17, 2, Palette.WALL.lightened(0.55))

	if not PartsDB.is_active(id):
		draw_string(font, rect.position + Vector2(rect.size.x - 108, 32), "PASIVA", HORIZONTAL_ALIGNMENT_LEFT, 100, 18, Palette.SLIME_BODY)

func _draw_pending(font: Font) -> void:
	var rect := Rect2(GRID_ORIGIN.x, GRID_ORIGIN.y + 3 * (SLOT_SIZE.y + SLOT_GAP.y), SLOT_SIZE.x * 2 + SLOT_GAP.x, 92)
	if Inventory.pending == "":
		draw_rect(rect, Color(Palette.FLOOR, 0.18), true)
		draw_rect(rect, Palette.WALL, false, 2.0)
		draw_string(font, rect.position + Vector2(16, 56), "SIN PARTE PENDIENTE", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 24, Palette.WALL)
		return

	var selected: bool = _selected == PENDING_INDEX
	draw_rect(rect, Color(Palette.WARM_LIGHT, 0.18), true)
	draw_rect(rect, Palette.SLIME_CORE if selected else Palette.WARM_LIGHT, false, 4.0 if selected else 2.0)
	var text := "PENDIENTE · %s (%s)" % [
		PartsDB.display_name(Inventory.pending),
		PartsDB.get_part(Inventory.pending).get("source", ""),
	]
	draw_string(font, rect.position + Vector2(16, 56), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 26, Palette.WARM_LIGHT)

func _draw_footer(font: Font) -> void:
	var y: float = PANEL.position.y + PANEL.size.y - 34.0
	if _message != "":
		draw_string(font, Vector2(PANEL.position.x, y - 42), _message, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 26, Palette.SLIME_CORE)
	var help := "[WASD] mover   [E] equipar pendiente   [F] consumir (+½ corazón)   [I] cerrar"
	draw_string(font, Vector2(PANEL.position.x, y), help, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 24, Palette.WALL.lightened(0.5))
