extends Node

const PartsDB := preload("res://core/parts_db.gd")

signal room_changed(room_id: String)
signal ability_gained(id: String)
signal health_changed(halves: int)
signal died
signal death_saved

# La vida se contabiliza en MEDIOS corazones, porque consumir una parte cura
# exactamente medio. `max_health` / `health` siguen expuestos en corazones para
# no romper a quien solo quiera leer el número redondo.
const HALVES_PER_HEART := 2

# Cada parte de jefe distinta consumida da +0,5% de daño base, hasta 6 partes.
const BOSS_PART_DAMAGE_BONUS := 0.005
const BOSS_PART_BONUS_CAP := 6

var current_room: String = ""
var visited: Dictionary = {}
var abilities: Dictionary = {}
var bosses_defeated: Dictionary = {}
# room_id -> true cuando ya se mataron todos sus enemigos; no reaparecen.
var rooms_cleared: Dictionary = {}
# Partes de jefe distintas ya consumidas: la bonificación es permanente y única.
var boss_parts_consumed: Dictionary = {}

var max_health_halves: int = 5 * HALVES_PER_HEART
var health_halves: int = 5 * HALVES_PER_HEART

# Modificador de vida máxima que aportan las partes equipadas (ej. Tentáculo
# resta un corazón). Se guarda aparte para poder recalcular al desequipar.
var _max_health_mod: int = 0
var _base_max_halves: int = 5 * HALVES_PER_HEART

var max_health: int:
	get:
		return max_health_halves / HALVES_PER_HEART

var health: int:
	get:
		return int(ceil(float(health_halves) / float(HALVES_PER_HEART)))

func _ready() -> void:
	# Debe seguir escuchando el toggle de pantalla completa con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("fullscreen"):
		return
	var windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED
	)
	get_viewport().set_input_as_handled()

func has_ability(id: String) -> bool:
	return abilities.has(id)

func reset_run() -> void:
	current_room = ""
	visited.clear()
	abilities.clear()
	bosses_defeated.clear()
	rooms_cleared.clear()
	boss_parts_consumed.clear()
	_max_health_mod = 0
	max_health_halves = _base_max_halves
	health_halves = max_health_halves

func gain_ability(id: String) -> void:
	if abilities.has(id):
		return
	abilities[id] = true
	ability_gained.emit(id)

# --- Vida ---

func damage(amount: int) -> void:
	damage_halves(amount * HALVES_PER_HEART)

func damage_halves(halves: int) -> void:
	if health_halves <= 0:
		return
	health_halves = max(0, health_halves - halves)
	health_changed.emit(health_halves)
	if health_halves > 0:
		return
	# El salvavidas (Núcleo Biológico / Corazón de la Humanidad Verdadera) se
	# consulta antes de dar la muerte por buena.
	if Inventory.consume_death_save():
		health_halves = HALVES_PER_HEART
		health_changed.emit(health_halves)
		death_saved.emit()
		return
	died.emit()

func heal_halves(halves: int) -> void:
	if halves <= 0:
		return
	health_halves = min(max_health_halves, health_halves + halves)
	health_changed.emit(health_halves)

func heal_half_heart() -> void:
	heal_halves(1)

func reset_health() -> void:
	health_halves = max_health_halves
	health_changed.emit(health_halves)

func is_low_health() -> bool:
	return health_halves <= HALVES_PER_HEART

# Lo llama el inventario cuando cambian las partes equipadas: hay partes que
# suben o bajan la vida máxima (Tentáculo: -1 corazón).
func set_max_health_mod(halves_delta: int) -> void:
	if halves_delta == _max_health_mod:
		return
	_max_health_mod = halves_delta
	max_health_halves = max(HALVES_PER_HEART, _base_max_halves + _max_health_mod)
	health_halves = min(health_halves, max_health_halves)
	health_changed.emit(health_halves)

# --- Bonificación por consumir partes de jefe ---

func register_boss_part_consumed(part_id: String) -> void:
	if boss_parts_consumed.has(part_id):
		return
	boss_parts_consumed[part_id] = true

# Multiplicador permanente sobre los ataques BÁSICOS del slime. No toca daño
# fijo (embestidas, trampas, habilidades) — eso lo filtra quien lo aplica.
func base_damage_multiplier() -> float:
	var count: int = min(boss_parts_consumed.size(), BOSS_PART_BONUS_CAP)
	return 1.0 + count * BOSS_PART_DAMAGE_BONUS

# --- Progreso de sala ---

func mark_room_cleared(room_id: String) -> void:
	rooms_cleared[room_id] = true

func is_room_cleared(room_id: String) -> bool:
	return rooms_cleared.get(room_id, false)
