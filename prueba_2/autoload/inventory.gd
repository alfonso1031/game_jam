extends Node

const PartsDB := preload("res://core/parts_db.gd")

signal slots_changed
signal pending_changed(part_id: String)
signal part_consumed(part_id: String)
signal part_equipped(part_id: String, index: int)
signal rejected(reason: String)

# Seis huecos genéricos: cualquier parte entra en cualquiera. El catálogo sigue
# guardando de qué parte del cuerpo salió cada pieza, pero eso es sabor, no una
# restricción — obligar a rellenar una silueta humana va justo en contra de lo
# que es el slime.
const SLOT_COUNT := 6

# Una habilidad activa de jefe a la vez: mientras corre una, las demás de jefe
# quedan bloqueadas (regla de equilibrio del documento).
const BOSS_ACTIVE_LOCK := 0.6

var slots: Array[String] = ["", "", "", "", "", ""]
# Parte recogida que no cabe en ningún hueco libre: espera decisión del jugador.
var pending: String = ""

var _cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _boss_lock := 0.0
# Salvavidas ya gastados. "once" se gasta para siempre; "floor" por piso.
var _death_save_used_once := false
var _death_save_floor: int = 9999
# Usos de habilidades marcadas `once_per_room`, indexados por hueco.
var _room_uses: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameState.room_changed.connect(_on_room_changed)

func _process(delta: float) -> void:
	for i in range(SLOT_COUNT):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = max(0.0, _cooldowns[i] - delta)
	_boss_lock = max(0.0, _boss_lock - delta)

func _on_room_changed(_room_id: String) -> void:
	_room_uses.clear()

# --- Consulta ---

func slot_label(index: int) -> String:
	return "SLOT %d" % (index + 1)

func part_at(index: int) -> String:
	return slots[index] if index >= 0 and index < SLOT_COUNT else ""

func is_empty(index: int) -> bool:
	return part_at(index) == ""

func has_part(part_id: String) -> bool:
	return slots.has(part_id)

func equipped_ids() -> Array[String]:
	var out: Array[String] = []
	for id in slots:
		if id != "":
			out.append(id)
	return out

func cooldown_left(index: int) -> float:
	return _cooldowns[index] if index >= 0 and index < SLOT_COUNT else 0.0

func cooldown_ratio(index: int) -> float:
	var id := part_at(index)
	var total := PartsDB.cooldown_of(id)
	if total <= 0.0:
		return 0.0
	return clampf(cooldown_left(index) / total, 0.0, 1.0)

# --- Reglas de compatibilidad ---

func can_place(part_id: String, index: int) -> bool:
	return placement_error(part_id, index) == ""

# Devuelve "" si la parte entra, o el motivo por el que no.
func placement_error(part_id: String, index: int) -> String:
	if not PartsDB.exists(part_id):
		return "Parte desconocida"
	if index < 0 or index >= SLOT_COUNT:
		return "Hueco inválido"
	if slots[index] == part_id:
		return "Ya la llevas ahí"
	if has_part(part_id):
		return "Ya llevas esa parte"
	var zone := PartsDB.body_zone_of(part_id)
	if zone != "":
		for i in range(SLOT_COUNT):
			if i == index or slots[i] == "":
				continue
			if PartsDB.body_zone_of(slots[i]) == zone:
				return "Choca con %s" % PartsDB.display_name(slots[i])
	return ""

func first_free_slot(part_id: String) -> int:
	for i in range(SLOT_COUNT):
		if slots[i] == "" and placement_error(part_id, i) == "":
			return i
	return -1

# --- Mutación ---

# Intenta guardar una parte recién recogida. Si no hay hueco libre queda
# pendiente y la interfaz de inventario decide qué hacer con ella.
func pick_up(part_id: String) -> bool:
	if not PartsDB.exists(part_id):
		return false
	var index := first_free_slot(part_id)
	if index >= 0:
		_set_slot(index, part_id)
		return true
	_set_pending(part_id)
	return false

# Coloca una parte en un hueco concreto. La parte que estuviera ahí pasa a
# pendiente en vez de perderse.
func place_in_slot(part_id: String, index: int) -> bool:
	var error := placement_error(part_id, index)
	if error != "":
		rejected.emit(error)
		return false
	var displaced := slots[index]
	_set_slot(index, part_id)
	# La parte desplazada ocupa el lugar de la que acaba de entrar: nada se
	# pierde sin que el jugador decida. Solo se pisa la pendiente si era
	# justamente la que se estaba colocando.
	if pending == part_id or displaced != "":
		_set_pending(displaced)
	return true

func clear_slot(index: int) -> String:
	var removed := part_at(index)
	if removed == "":
		return ""
	_set_slot(index, "")
	return removed

# Comer la parte del hueco: medio corazón de vida. Es el destino de las partes
# que no quieres llevar encima.
func lose_slot(index: int) -> String:
	return clear_slot(index)


func sacrifice_slot(index: int) -> String:
	return clear_slot(index)


func consume_slot(index: int) -> bool:
	var id := part_at(index)
	if id == "":
		return false
	_set_slot(index, "")
	_digest(id)
	return true

func consume_pending() -> bool:
	if pending == "":
		return false
	var id := pending
	_set_pending("")
	_digest(id)
	return true

func _digest(part_id: String) -> void:
	GameState.heal_half_heart()
	if PartsDB.is_boss_part(part_id):
		GameState.register_boss_part_consumed(part_id)
	part_consumed.emit(part_id)

func _set_pending(part_id: String) -> void:
	if pending == part_id:
		return
	pending = part_id
	pending_changed.emit(pending)

func _set_slot(index: int, part_id: String) -> void:
	slots[index] = part_id
	_cooldowns[index] = 0.0
	_room_uses.erase(index)
	_refresh_passives()
	slots_changed.emit()
	if part_id != "":
		part_equipped.emit(part_id, index)

# --- Activación ---

func can_activate(index: int) -> bool:
	var id := part_at(index)
	if id == "" or not PartsDB.is_active(id):
		return false
	if _cooldowns[index] > 0.0:
		return false
	if PartsDB.is_boss_part(id) and _boss_lock > 0.0:
		return false
	var effect: Dictionary = PartsDB.get_part(id).get("effect", {})
	if effect.get("once_per_room", false) and _room_uses.get(index, false):
		return false
	return true

# La llama el slime cuando la habilidad se ejecutó de verdad.
func notify_activated(index: int) -> void:
	var id := part_at(index)
	if id == "":
		return
	_cooldowns[index] = PartsDB.cooldown_of(id)
	if PartsDB.is_boss_part(id):
		_boss_lock = BOSS_ACTIVE_LOCK
	var effect: Dictionary = PartsDB.get_part(id).get("effect", {})
	if effect.get("once_per_room", false):
		_room_uses[index] = true

# --- Modificadores agregados ---

# Modificadores que se acumulan sumando (vida máxima, aturdimiento extra...).
func mod_sum(key: String) -> float:
	var total := 0.0
	for id in slots:
		if id == "":
			continue
		total += float(PartsDB.mods_of(id).get(key, 0.0))
	return total

# Modificadores que se acumulan multiplicando (tiempo de carga, penalización de
# daño del Corazón...).
func mod_product(key: String) -> float:
	var total := 1.0
	for id in slots:
		if id == "":
			continue
		total *= float(PartsDB.mods_of(id).get(key, 1.0))
	return total

# Multiplicadores OFENSIVOS: no se multiplican entre sí, solo cuenta el más
# alto (regla explícita de equilibrio).
func mod_best(key: String) -> float:
	var best := 1.0
	for id in slots:
		if id == "":
			continue
		best = max(best, float(PartsDB.mods_of(id).get(key, 1.0)))
	return best

func mod_flag(key: String) -> bool:
	for id in slots:
		if id == "":
			continue
		if PartsDB.mods_of(id).get(key, false):
			return true
	return false

func mod_max_int(key: String, default_value: int = 0) -> int:
	var best := default_value
	for id in slots:
		if id == "":
			continue
		best = max(best, int(PartsDB.mods_of(id).get(key, default_value)))
	return best

# Daño de las habilidades: el mejor multiplicador ofensivo, castigado por las
# penalizaciones. El bono permanente por partes de jefe consumidas solo aplica
# a los ataques básicos, así que no entra acá.
func ability_damage_multiplier(melee: bool) -> float:
	var offensive := mod_best("melee_mult") if melee else 1.0
	return offensive * mod_product("damage_mult")

func _refresh_passives() -> void:
	GameState.set_max_health_mod(int(mod_sum("max_health_halves")))

# --- Salvavidas ---

# La llama GameState al llegar a 0 de vida. Devuelve true si alguna parte
# equipada evita la muerte.
func consume_death_save() -> bool:
	for id in slots:
		if id == "":
			continue
		var kind: String = str(PartsDB.mods_of(id).get("death_save", ""))
		if kind == "once" and not _death_save_used_once:
			_death_save_used_once = true
			_boss_lock = max(_boss_lock, float(PartsDB.mods_of(id).get("lockout_on_save", 0.0)))
			return true
		if kind == "floor":
			var floor_id := _current_floor()
			if _death_save_floor != floor_id:
				_death_save_floor = floor_id
				_boss_lock = max(_boss_lock, float(PartsDB.mods_of(id).get("lockout_on_save", 0.0)))
				return true
	return false

func _current_floor() -> int:
	var data: Dictionary = RoomDB.ROOMS.get(GameState.current_room, {})
	return int(data.get("level", 0))

func reset_run() -> void:
	for i in range(SLOT_COUNT):
		slots[i] = ""
		_cooldowns[i] = 0.0
	pending = ""
	_boss_lock = 0.0
	_death_save_used_once = false
	_death_save_floor = 9999
	_room_uses.clear()
	_refresh_passives()
	slots_changed.emit()
	pending_changed.emit("")
