extends Node2D

# Ejecuta las partes equipadas. Todo lo que hace una parte está descrito como
# datos en `core/parts_db.gd`; acá solo vive el "cómo" de cada tipo de efecto.
# Añadir una parte nueva no debería tocar este archivo salvo que estrene un tipo.
#
# Cuelga del slime: los efectos que lo mueven o le ponen estados se los delega
# a él, los que instancian algo en el mundo los cuelga de la sala actual para
# que se limpien solos al cambiar de sala.

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

const ProjectileScene := preload("res://actors/player/abilities/player_projectile.tscn")
const MeleeArcScene := preload("res://actors/player/abilities/melee_arc.tscn")
const RadialPulseScene := preload("res://actors/player/abilities/radial_pulse.tscn")
const BeamScene := preload("res://actors/player/abilities/ability_beam.tscn")
const BarrierScene := preload("res://actors/player/abilities/barrier.tscn")
const ZoneScene := preload("res://world/props/hazard_zone.tscn")

const MUZZLE_OFFSET := 62.0

@onready var slime: Node2D = get_parent()

func _unhandled_input(event: InputEvent) -> void:
	for i in range(Inventory.SLOT_COUNT):
		if not event.is_action_pressed("ability_%d" % (i + 1)):
			continue
		try_activate(i)
		get_viewport().set_input_as_handled()
		return

func try_activate(index: int) -> bool:
	if not Inventory.can_activate(index):
		return false
	var part: Dictionary = PartsDB.get_part(Inventory.part_at(index))
	var effect: Dictionary = part.get("effect", {})
	if not _run(effect):
		return false
	Inventory.notify_activated(index)
	return true

func _run(effect: Dictionary) -> bool:
	match effect.get("kind", ""):
		PartsDB.EFFECT_PROJECTILE:
			_fire_projectiles(effect)
		PartsDB.EFFECT_MELEE:
			_swing(effect)
		PartsDB.EFFECT_RADIAL:
			_pulse(effect)
		PartsDB.EFFECT_BEAM:
			_beam(effect)
		PartsDB.EFFECT_PLACE:
			_place(effect)
		PartsDB.EFFECT_DASH:
			return slime.begin_part_dash(effect)
		PartsDB.EFFECT_BUFF:
			return slime.apply_part_buff(effect)
		_:
			return false
	return true

# --- Tipos de efecto ---

func _fire_projectiles(effect: Dictionary) -> void:
	var aim := _aim()
	var count: int = effect.get("count", 1)
	var spread: float = deg_to_rad(effect.get("spread_deg", 0.0))
	for i in range(count):
		# Reparte el abanico centrado en la mira: con count 1 sale recto.
		var offset_angle := 0.0
		if count > 1:
			offset_angle = -spread * 0.5 + spread * float(i) / float(count - 1)
		var direction := aim.rotated(offset_angle)

		var projectile: Node2D = ProjectileScene.instantiate()
		projectile.direction = direction
		projectile.speed = effect.get("speed", 800.0)
		projectile.damage = _scaled_damage(effect, false)
		projectile.radius = effect.get("radius", 16.0)
		projectile.max_range = effect.get("range", 700.0)
		projectile.pierce = effect.get("pierce", false)
		projectile.knockback = effect.get("knockback", 0.0)
		projectile.status = effect.get("status", "")
		projectile.status_time = effect.get("status_time", 0.0)
		projectile.leaves = effect.get("leaves", {})
		projectile.plants = effect.get("plants", {})
		projectile.color = Palette.SLIME_CORE
		projectile.position = slime.global_position + direction * MUZZLE_OFFSET
		_world().add_child(projectile)

func _swing(effect: Dictionary) -> void:
	var arc: Node2D = MeleeArcScene.instantiate()
	arc.aim = _aim()
	arc.range_px = effect.get("range", 150.0)
	arc.arc_deg = effect.get("arc_deg", 60.0)
	arc.hollow_deg = effect.get("hollow_deg", 0.0)
	arc.damage = _scaled_damage(effect, true)
	arc.knockback = effect.get("knockback", 0.0)
	arc.status = effect.get("status", "")
	arc.status_time = effect.get("status_time", 0.0)
	# La Garra de Oso rompe barricadas aunque la parte no lo hiciera de serie.
	arc.break_shield = effect.get("break_shield", false) or Inventory.mod_flag("break_walls")
	arc.hits = effect.get("hits", 1)
	arc.interval = effect.get("interval", 0.15)
	arc.position = slime.global_position
	_world().add_child(arc)
	slime.notify_melee_swing(arc)

func _pulse(effect: Dictionary) -> void:
	var pulse: Node2D = RadialPulseScene.instantiate()
	pulse.radius = effect.get("radius", 220.0)
	pulse.damage = _scaled_damage(effect, false)
	pulse.knockback = effect.get("knockback", 0.0)
	pulse.status = effect.get("status", "")
	pulse.status_time = effect.get("status_time", 0.0)
	pulse.position = slime.global_position
	_world().add_child(pulse)

func _beam(effect: Dictionary) -> void:
	var beam: Node2D = BeamScene.instantiate()
	beam.aim = _aim()
	beam.length = effect.get("length", 700.0)
	beam.width = effect.get("width", 40.0)
	beam.damage = _scaled_damage(effect, false)
	beam.status = effect.get("status", "")
	beam.status_time = effect.get("status_time", 0.0)
	beam.first_only = effect.get("first_only", false)
	beam.clear_projectiles = effect.get("clear_projectiles", false)
	beam.pull = effect.get("pull", 0.0)
	beam.position = slime.global_position
	_world().add_child(beam)

func _place(effect: Dictionary) -> void:
	var at: Vector2 = slime.global_position
	var offset: float = effect.get("offset", 0.0)
	if offset > 0.0:
		at += _aim() * offset

	match effect.get("object", "zone"):
		"barrier":
			var barrier: Node2D = BarrierScene.instantiate()
			barrier.duration = effect.get("duration", 6.0)
			barrier.size = effect.get("size", Vector2(120, 40))
			# Se planta cruzada a la mira: es cobertura, no una pared que estorbe.
			barrier.rotation = _aim().angle() + PI / 2.0
			barrier.position = at
			_world().add_child(barrier)
		"mine":
			# La mina es un pulso radial con retardo: mismo actor, otro ajuste.
			var mine: Node2D = RadialPulseScene.instantiate()
			mine.radius = effect.get("radius", 190.0)
			mine.damage = _scaled_damage(effect, false)
			mine.knockback = effect.get("knockback", 0.0)
			mine.status = effect.get("status", "")
			mine.status_time = effect.get("status_time", 0.0)
			mine.delay = effect.get("delay", 1.0)
			mine.color = Palette.SLIME_BODY
			mine.position = at
			_world().add_child(mine)
		_:
			var zone: Node2D = ZoneScene.instantiate()
			zone.affects = zone.AFFECT_ENEMIES
			zone.duration = effect.get("duration", 3.0)
			zone.radius = effect.get("radius", 200.0)
			zone.dps = effect.get("dps", 2.0)
			zone.status = effect.get("status", "")
			zone.status_time = effect.get("status_time", 1.0)
			zone.color = Palette.SLIME_BODY
			zone.position = at
			_world().add_child(zone)

# --- Utilidades ---

# `slime` es un Node2D sin tipo concreto, así que sus métodos devuelven Variant.
# Envolverlo acá deja tipada la mira en todos los efectos.
func _aim() -> Vector2:
	return slime.aim_direction()

# El daño fijo (embestidas, Pistón de Compresión) no recibe multiplicadores:
# es una regla explícita de equilibrio, no un olvido.
func _scaled_damage(effect: Dictionary, melee: bool) -> int:
	var base: int = effect.get("damage", 0)
	if base <= 0 or effect.get("fixed_damage", false):
		return base
	return int(round(base * Inventory.ability_damage_multiplier(melee)))

# Los efectos se cuelgan de la sala, no del slime: al cambiar de sala la
# `Transition` borra sus hijos y se limpian solos.
func _world() -> Node:
	var room := get_tree().get_first_node_in_group("room")
	return room if room != null else slime.get_parent()
