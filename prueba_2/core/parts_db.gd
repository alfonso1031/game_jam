# Catálogo de partes obtenibles.
#
# Sin `class_name`, igual que `palette.gd` y `layers.gd`: se consume con
# `preload("res://core/parts_db.gd")`.
#
# Cada parte es data, no código: el `effect` describe QUÉ hace y
# `actors/player/abilities/ability_runner.gd` sabe CÓMO ejecutarlo. Añadir una
# parte nueva es añadir una entrada acá, no escribir un script.
#
# Campos de una entrada:
#   name       texto visible
#   slot       parte del cuerpo de la que salió. Es SABOR, no una restricción:
#              los seis huecos del inventario son genéricos y admiten cualquier
#              parte. Se conserva porque describe la pieza y ordena el catálogo.
#   tier       TIER_BASIC (monstruo normal) | TIER_BOSS (jefe)
#   source     de qué experimento/jefe sale, solo informativo
#   desc       descripción corta para la interfaz
#   cooldown   segundos entre usos (0.0 = no es activable)
#   effect     spec de efecto, ver EFFECT_* más abajo (vacío = pasiva pura)
#   mods       modificadores permanentes mientras está equipada (opcional)
#   body_zone  zona corporal ocupada; dos partes con la misma zona no conviven
#              (opcional; solo lo usan las partes de jefe con contrapartida)

const SLOT_CABEZA := "cabeza"
const SLOT_BRAZO := "brazo"
const SLOT_PIERNA := "pierna"
const SLOT_TORSO := "torso"

const TIER_BASIC := 0
const TIER_BOSS := 1

# Tipos de efecto que entiende el runner.
const EFFECT_PROJECTILE := "projectile"   # dispara uno o varios proyectiles
const EFFECT_MELEE := "melee"             # golpe instantáneo en arco frontal
const EFFECT_RADIAL := "radial"           # pulso de 360° centrado en el slime
const EFFECT_DASH := "dash"               # impulso propio
const EFFECT_PLACE := "place"             # deja un objeto en el suelo
const EFFECT_BEAM := "beam"               # línea instantánea hacia delante
const EFFECT_BUFF := "buff"               # estado temporal sobre el slime

# Estados alterados que las partes aplican a los enemigos.
const STATUS_STUN := "stun"       # aturdido: no actúa
const STATUS_ROOT := "root"       # inmovilizado: actúa pero no se mueve
const STATUS_BURN := "burn"       # daño por segundo
const STATUS_SLOW := "slow"       # velocidad reducida
const STATUS_MARK := "mark"       # el siguiente golpe es crítico

const PARTS := {
	# ------------------------------------------------------------------
	# EXPERIMENTO 01 — Ciempiés de Agujas
	# ------------------------------------------------------------------
	"acid_stinger": {
		"name": "Aguijón de Ácido",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-01 Ciempiés de Agujas",
		"desc": "Chorro de ácido recto que deja un charco dañino.",
		"cooldown": 1.6,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"speed": 820.0,
			"damage": 1,
			"radius": 16.0,
			"range": 760.0,
			"leaves": {"duration": 3.0, "radius": 78.0, "dps": 2.0, "status": STATUS_SLOW},
		},
	},
	"serrated_jaw": {
		"name": "Mandíbula Serrada",
		"slot": SLOT_CABEZA,
		"tier": TIER_BASIC,
		"source": "EXP-01 Ciempiés de Agujas",
		"desc": "Mordisco a corta distancia.",
		"cooldown": 0.9,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 130.0,
			"arc_deg": 70.0,
			"damage": 2,
			"knockback": 240.0,
			"break_shield": true,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 02 — Arácnido Blindado
	# ------------------------------------------------------------------
	"hydraulic_legs": {
		"name": "Patas Hidráulicas",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-02 Arácnido Blindado",
		"desc": "Dash corto que atraviesa y empuja a los enemigos.",
		"cooldown": 1.4,
		"effect": {
			"kind": EFFECT_DASH,
			"distance": 300.0,
			"speed": 1900.0,
			"pierce": true,
			"push": 520.0,
			"damage": 1,
			"invuln": 0.18,
		},
	},
	"bio_netcaster": {
		"name": "Lanzaredes Biológico",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-02 Arácnido Blindado",
		"desc": "Red que inmoviliza brevemente al objetivo.",
		"cooldown": 2.4,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"speed": 700.0,
			"damage": 0,
			"radius": 26.0,
			"range": 820.0,
			"status": STATUS_ROOT,
			"status_time": 1.8,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 03 — Saurio Escamado
	# ------------------------------------------------------------------
	"whip_tail": {
		"name": "Cola de Látigo",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-03 Saurio Escamado",
		"desc": "Barrido giratorio de 360 grados que repele a los enemigos alrededor.",
		"cooldown": 1.8,
		"effect": {
			"kind": EFFECT_RADIAL,
			"radius": 210.0,
			"damage": 1,
			"knockback": 620.0,
		},
	},
	"scaled_skin": {
		"name": "Pierna Escamada",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-03 Saurio Escamado",
		"desc": "Levanta una costra de escamas que bloquea el siguiente impacto recibido.",
		"cooldown": 6.0,
		"effect": {
			"kind": EFFECT_BUFF,
			"duration": 5.0,
			"flags": {"shield": 1},
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 04 — Anguila Voltaica
	# ------------------------------------------------------------------
	"electric_gland": {
		"name": "Glándula Eléctrica",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-04 Anguila Voltaica",
		"desc": "Pulso radial que paraliza a los enemigos cercanos.",
		"cooldown": 3.2,
		"effect": {
			"kind": EFFECT_RADIAL,
			"radius": 260.0,
			"damage": 0,
			"status": STATUS_STUN,
			"status_time": 2.0,
		},
	},
	"adhesive_pads": {
		"name": "Ventosas Adhesivas",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-04 Anguila Voltaica",
		"desc": "Te impulsa hacia la pared más cercana y te pega a ella.",
		"cooldown": 2.0,
		"effect": {
			"kind": EFFECT_DASH,
			"to_wall": true,
			"speed": 2100.0,
			"distance": 900.0,
			"stick": 1.2,
			"invuln": 0.2,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 05 — Quimera Alada
	# ------------------------------------------------------------------
	"flight_membrane": {
		"name": "Membrana de Vuelo",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-05 Quimera Alada",
		"desc": "Planeo rápido que supera pozos, trampas y proyectiles bajos.",
		"cooldown": 2.2,
		"effect": {
			"kind": EFFECT_DASH,
			"distance": 520.0,
			"speed": 1500.0,
			"glide": true,
			"invuln": 0.45,
		},
	},
	"bone_stiletto": {
		"name": "Estilete Óseo",
		"slot": SLOT_CABEZA,
		"tier": TIER_BASIC,
		"source": "EXP-05 Quimera Alada",
		"desc": "Tres espinas de hueso en abanico frontal.",
		"cooldown": 1.5,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"count": 3,
			"spread_deg": 26.0,
			"speed": 980.0,
			"damage": 1,
			"radius": 12.0,
			"range": 700.0,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 06 — Bestia Térmica
	# ------------------------------------------------------------------
	"igneous_arm": {
		"name": "Brazo Ígneo",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-06 Bestia Térmica",
		"desc": "Puñetazo que prende fuego al enemigo golpeado.",
		"cooldown": 1.3,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 150.0,
			"arc_deg": 55.0,
			"damage": 1,
			"knockback": 300.0,
			"status": STATUS_BURN,
			"status_time": 3.0,
		},
	},
	"heat_bulb": {
		"name": "Bulbo de Calor",
		"slot": SLOT_CABEZA,
		"tier": TIER_BASIC,
		"source": "EXP-06 Bestia Térmica",
		"desc": "Ráfaga de fuego frontal de corto alcance durante 1 segundo.",
		"cooldown": 3.0,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 200.0,
			"arc_deg": 60.0,
			"damage": 1,
			"hits": 5,
			"interval": 0.2,
			"status": STATUS_BURN,
			"status_time": 2.0,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 07 — Crustáceo Triturador
	# ------------------------------------------------------------------
	"bone_plate": {
		"name": "Placa de Hueso",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-07 Crustáceo Triturador",
		"desc": "Coloca un obstáculo rígido temporal en tu posición.",
		"cooldown": 4.0,
		"effect": {
			"kind": EFFECT_PLACE,
			"object": "barrier",
			"duration": 6.0,
			"size": Vector2(120, 40),
		},
	},
	"crusher_claw": {
		"name": "Tenaza Trituradora",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-07 Crustáceo Triturador",
		"desc": "Ataque cónico frontal.",
		"cooldown": 1.7,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 190.0,
			"arc_deg": 34.0,
			"damage": 3,
			"knockback": 480.0,
			"break_shield": true,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 08 — Cuerpo Fúngico
	# ------------------------------------------------------------------
	"spore_sac": {
		"name": "Saco de Esporas",
		"slot": SLOT_CABEZA,
		"tier": TIER_BASIC,
		"source": "EXP-08 Cuerpo Fúngico",
		"desc": "Suelta un saco que explota tras 1 segundo.",
		"cooldown": 3.0,
		"effect": {
			"kind": EFFECT_PLACE,
			"object": "mine",
			"delay": 1.0,
			"radius": 190.0,
			"damage": 2,
			"knockback": 420.0,
		},
	},
	"mycelium_hand": {
		"name": "Mano de Micelio",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-08 Cuerpo Fúngico",
		"desc": "Dispara una línea de raíz que inmoviliza al primer enemigo tocado.",
		"cooldown": 2.6,
		"effect": {
			"kind": EFFECT_BEAM,
			"length": 720.0,
			"width": 34.0,
			"first_only": true,
			"status": STATUS_ROOT,
			"status_time": 2.5,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 09 — Gólem de Metal Sólido
	# ------------------------------------------------------------------
	"magnet_core": {
		"name": "Núcleo Imán",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-09 Gólem de Metal Sólido",
		"desc": "Onda magnética radial que empuja lejos a todos los enemigos.",
		"cooldown": 4.0,
		"effect": {
			"kind": EFFECT_RADIAL,
			"radius": 420.0,
			"damage": 0,
			"knockback": 1100.0,
		},
	},
	"scrap_fist": {
		"name": "Puño de Chatarra",
		"slot": SLOT_BRAZO,
		"tier": TIER_BASIC,
		"source": "EXP-09 Gólem de Metal Sólido",
		"desc": "Proyectil grande y lento que atraviesa a los enemigos menores.",
		"cooldown": 2.8,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"speed": 380.0,
			"damage": 2,
			"radius": 40.0,
			"range": 1600.0,
			"pierce": true,
			"knockback": 320.0,
		},
	},

	# ------------------------------------------------------------------
	# EXPERIMENTO 10 — Mutante Parásito
	# ------------------------------------------------------------------
	"hook_tentacle": {
		"name": "Tentáculo Garfio",
		"slot": SLOT_PIERNA,
		"tier": TIER_BASIC,
		"source": "EXP-10 Mutante Parásito",
		"desc": "Garfio recto: si clava en pared, te jala hasta ella.",
		"cooldown": 2.0,
		"effect": {
			"kind": EFFECT_DASH,
			"to_wall": true,
			"aim": "facing",
			"speed": 2400.0,
			"distance": 1200.0,
			"invuln": 0.2,
		},
	},
	"parasite_eye": {
		"name": "Ojo Parásito",
		"slot": SLOT_CABEZA,
		"tier": TIER_BASIC,
		"source": "EXP-10 Mutante Parásito",
		"desc": "Rayo que marca puntos débiles: el siguiente golpe es crítico.",
		"cooldown": 3.4,
		"effect": {
			"kind": EFFECT_BEAM,
			"length": 900.0,
			"width": 60.0,
			"status": STATUS_MARK,
			"status_time": 6.0,
		},
	},

	# ==================================================================
	# PARTES DE JEFE
	# ==================================================================

	# BOSS 01 — Ursídeo Hidráulico
	"compression_piston": {
		"name": "Pistón de Compresión",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-01 Ursídeo Hidráulico",
		"desc": "Onda de choque corta: gran daño y rompe puertas frágiles.",
		"cooldown": 3.0,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 240.0,
			"arc_deg": 46.0,
			"damage": 4,
			"fixed_damage": true,
			"knockback": 900.0,
			"break_shield": true,
			"break_walls": true,
		},
	},
	"impact_helm": {
		"name": "Casco de Impacto",
		"slot": SLOT_CABEZA,
		"tier": TIER_BOSS,
		"source": "JEFE-01 Ursídeo Hidráulico",
		"desc": "Cabezazo cónico que aturde 1 segundo.",
		"cooldown": 3.6,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 200.0,
			"arc_deg": 80.0,
			"damage": 2,
			"status": STATUS_STUN,
			"status_time": 1.0,
			"knockback": 420.0,
		},
	},

	# BOSS 02 — Quimera Albina
	"silent_claws": {
		"name": "Garras Silenciosas",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "JEFE-02 Quimera Albina",
		"desc": "Duplica la velocidad base durante 3 segundos.",
		"cooldown": 8.0,
		"effect": {
			"kind": EFFECT_BUFF,
			"duration": 3.0,
			"flags": {"speed_mult": 2.0},
		},
	},
	"double_tail": {
		"name": "Cola Doble",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-02 Quimera Albina",
		"desc": "Dos latigazos simultáneos en V frontal.",
		"cooldown": 2.0,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 220.0,
			"arc_deg": 120.0,
			"hollow_deg": 30.0,
			"damage": 2,
			"knockback": 380.0,
		},
	},

	# BOSS 03 — Replicante Fúngico
	"mycelium_sprout": {
		"name": "Brote de Micelio",
		"slot": SLOT_CABEZA,
		"tier": TIER_BOSS,
		"source": "JEFE-03 Replicante Fúngico",
		"desc": "Semilla que planta una flor que dispara sola durante 4 s.",
		"cooldown": 6.0,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"speed": 700.0,
			"damage": 0,
			"radius": 18.0,
			"range": 620.0,
			"plants": {"object": "turret", "duration": 4.0, "interval": 0.6, "damage": 1},
		},
	},
	"parasite_cloak": {
		"name": "Capa Parásita",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "JEFE-03 Replicante Fúngico",
		"desc": "Zona infectada bajo tus pies que daña por 3 segundos.",
		"cooldown": 6.0,
		"effect": {
			"kind": EFFECT_PLACE,
			"object": "zone",
			"duration": 3.0,
			"radius": 200.0,
			"dps": 3.0,
			"status": STATUS_SLOW,
		},
	},

	# BOSS 04 — Robovigilante de Contención
	"disruptor_eye": {
		"name": "Ojo Disruptor",
		"slot": SLOT_CABEZA,
		"tier": TIER_BOSS,
		"source": "JEFE-04 Robovigilante",
		"desc": "Cono de luz que destruye los proyectiles enemigos en vuelo.",
		"cooldown": 5.0,
		"effect": {
			"kind": EFFECT_BEAM,
			"length": 760.0,
			"width": 320.0,
			"clear_projectiles": true,
		},
	},
	"voltaic_cell": {
		"name": "Pila Voltaica",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "JEFE-04 Robovigilante",
		"desc": "Impulso recto que deja chispas dañinas 2 segundos.",
		"cooldown": 4.0,
		"effect": {
			"kind": EFFECT_DASH,
			"distance": 420.0,
			"speed": 1800.0,
			"pierce": true,
			"damage": 1,
			"invuln": 0.2,
			"trail": {"duration": 2.0, "radius": 60.0, "dps": 4.0},
		},
	},

	# BOSS 05 — Quimera Aracnoide
	"viscosity_sac": {
		"name": "Saco de Viscosidad",
		"slot": SLOT_CABEZA,
		"tier": TIER_BOSS,
		"source": "JEFE-05 Quimera Aracnoide",
		"desc": "Estalla en un charco pegajoso: nadie se mueve por 2 segundos.",
		"cooldown": 5.0,
		"effect": {
			"kind": EFFECT_PROJECTILE,
			"speed": 600.0,
			"damage": 0,
			"radius": 28.0,
			"range": 640.0,
			"leaves": {"duration": 4.0, "radius": 190.0, "dps": 0.0, "status": STATUS_ROOT, "status_time": 2.0},
		},
	},
	"cutting_claw": {
		"name": "Tenaza Cortante",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-05 Quimera Aracnoide",
		"desc": "Dos cortes horizontales rápidos de corto alcance.",
		"cooldown": 1.1,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 150.0,
			"arc_deg": 90.0,
			"damage": 2,
			"hits": 2,
			"interval": 0.12,
			"knockback": 200.0,
		},
	},

	# BOSS 06 — Sujeto 00: Bestia Térmica
	"steam_vent": {
		"name": "Escape de Vapor",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "JEFE-06 Bestia Térmica",
		"desc": "Te impulsa hacia adelante quemando a lo que quede detrás.",
		"cooldown": 3.4,
		"effect": {
			"kind": EFFECT_DASH,
			"distance": 460.0,
			"speed": 2000.0,
			"invuln": 0.25,
			"backblast": {"radius": 200.0, "damage": 2, "status": STATUS_BURN, "status_time": 3.0},
		},
	},
	"igneous_fist": {
		"name": "Puño Ígneo",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-06 Bestia Térmica",
		"desc": "Puñetazo que aplica quemadura continua.",
		"cooldown": 1.6,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 160.0,
			"arc_deg": 50.0,
			"damage": 2,
			"status": STATUS_BURN,
			"status_time": 5.0,
			"knockback": 300.0,
		},
	},

	# BOSS 07 — El Guardián: Crustáceo de Aleación
	"mech_wall": {
		"name": "Muro Mecánico",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-07 Crustáceo de Aleación",
		"desc": "Clava una placa metálica que hace de cobertura temporal.",
		"cooldown": 5.0,
		"effect": {
			"kind": EFFECT_PLACE,
			"object": "barrier",
			"duration": 8.0,
			"offset": 140.0,
			"size": Vector2(180, 44),
			"blocks_projectiles": true,
		},
	},
	"hip_plate": {
		"name": "Placa de Cadera",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "JEFE-07 Crustáceo de Aleación",
		"desc": "Inmune a empujes y a los efectos del suelo por 2 segundos.",
		"cooldown": 7.0,
		"effect": {
			"kind": EFFECT_BUFF,
			"duration": 2.0,
			"flags": {"immune_push": true, "immune_floor": true},
		},
	},

	# BOSS 08 — La Humanidad Verdadera
	"bio_core": {
		"name": "Núcleo Biológico",
		"slot": SLOT_CABEZA,
		"tier": TIER_BOSS,
		"source": "JEFE-08 La Humanidad Verdadera",
		"desc": "Pasiva: una vez, evita la muerte al llegar a 0 de vida.",
		"cooldown": 0.0,
		"effect": {},
		"mods": {"death_save": "once"},
	},
	"full_access_arm": {
		"name": "Brazo de Acceso Total",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "JEFE-08 La Humanidad Verdadera",
		"desc": "Empuje físico y llave universal para puertas y escáneres.",
		"cooldown": 1.8,
		"effect": {
			"kind": EFFECT_MELEE,
			"range": 170.0,
			"arc_deg": 70.0,
			"damage": 2,
			"knockback": 700.0,
		},
		"mods": {"master_key": true},
	},

	# ==================================================================
	# PARTES DE CUERPO DE JEFE — poder alto con contrapartida explícita
	# ==================================================================
	"bear_claw": {
		"name": "Garra de Oso",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "Extremidad pesada",
		"desc": "x2 daño cuerpo a cuerpo y rompe barricadas. +35% recuperación; fallar deja inmóvil 0,4 s.",
		"cooldown": 0.0,
		"body_zone": "brazo_pesado",
		"effect": {},
		"mods": {
			"melee_mult": 2.0,
			"break_walls": true,
			"recovery_mult": 1.35,
			"whiff_lock": 0.4,
		},
	},
	"tentacle_limb": {
		"name": "Tentáculo",
		"slot": SLOT_BRAZO,
		"tier": TIER_BOSS,
		"source": "Extremidad flexible",
		"desc": "Te adhieres a paredes y agarras enemigos. Cuesta un corazón de vida máxima.",
		"cooldown": 2.2,
		"body_zone": "brazo_flexible",
		"effect": {
			"kind": EFFECT_BEAM,
			"length": 520.0,
			"width": 40.0,
			"first_only": true,
			"status": STATUS_ROOT,
			"status_time": 2.0,
			"pull": 900.0,
		},
		"mods": {"max_health_halves": -2, "wall_cling": true},
	},
	"fox_leg": {
		"name": "Pierna de Zorro",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "Extremidad ágil",
		"desc": "Hasta 3 DASH por sala, invulnerable durante el DASH. Solo recargan al cambiar de sala.",
		"cooldown": 0.0,
		"body_zone": "pierna_agil",
		"effect": {},
		"mods": {"dash_charges": 3, "dash_invuln": true},
	},
	"pale_leg": {
		"name": "Pierna de Pálido",
		"slot": SLOT_PIERNA,
		"tier": TIER_BOSS,
		"source": "Extremidad silenciosa",
		"desc": "-30% detección enemiga y aterrizaje sin ruido. +15% tiempo de carga.",
		"cooldown": 0.0,
		"body_zone": "pierna_sigilo",
		"effect": {},
		"mods": {"detection_mult": 0.7, "charge_time_mult": 1.15, "silent_landing": true},
	},
	"ram_shell": {
		"name": "Caparazón del Ariete",
		"slot": SLOT_TORSO,
		"tier": TIER_BOSS,
		"source": "Estructura frontal endurecida",
		"desc": "La carga máxima embiste por 1 de daño fijo y rompe obstáculos agrietados. Choque contra pared más largo.",
		"cooldown": 0.0,
		"body_zone": "torso",
		"effect": {},
		"mods": {
			"ram_damage": 1,
			"charge_poise": true,
			"break_walls": true,
			"wall_stun_add": 0.2,
			"recovery_add": 0.15,
		},
	},
	"fungal_replicant": {
		"name": "Cabeza y Torso del Replicante Fúngico",
		"slot": SLOT_TORSO,
		"tier": TIER_BOSS,
		"source": "JEFE-03 Replicante Fúngico",
		"desc": "Genera micelio que ralentiza y esporas que dañan alrededor. Regenera solo fuera de combate.",
		"cooldown": 7.0,
		"body_zone": "torso",
		"effect": {
			"kind": EFFECT_PLACE,
			"object": "zone",
			"duration": 5.0,
			"radius": 260.0,
			"dps": 2.0,
			"status": STATUS_SLOW,
		},
		"mods": {"regen_out_of_combat": true, "vision_fog": 0.15},
	},
	"robowatcher_core": {
		"name": "Cabeza y Torso del Robovigilante",
		"slot": SLOT_TORSO,
		"tier": TIER_BOSS,
		"source": "JEFE-04 Robovigilante",
		"desc": "Escanea la sala 4 s (una vez por sala) e intercepta el primer proyectil de cada sala. +10% tiempo de carga.",
		"cooldown": 0.0,
		"body_zone": "torso",
		"effect": {
			"kind": EFFECT_BUFF,
			"duration": 4.0,
			"once_per_room": true,
			"flags": {"scan": true},
		},
		"mods": {"charge_time_mult": 1.1, "projectile_block_per_room": 1},
	},
	"true_heart": {
		"name": "Corazón de la Humanidad Verdadera",
		"slot": SLOT_TORSO,
		"tier": TIER_BOSS,
		"source": "JEFE-08 La Humanidad Verdadera",
		"desc": "Una vez por piso evita la muerte con un corazón. Con un corazón la carga es 20% más rápida, pero las partes hacen 20% menos daño.",
		"cooldown": 0.0,
		"body_zone": "torso",
		"effect": {},
		"mods": {
			"death_save": "floor",
			"damage_mult": 0.8,
			"low_health_charge_mult": 0.8,
			"lockout_on_save": 5.0,
		},
	},
}

static func get_part(id: String) -> Dictionary:
	return PARTS.get(id, {})

static func exists(id: String) -> bool:
	return PARTS.has(id)

static func slot_of(id: String) -> String:
	return PARTS.get(id, {}).get("slot", "")

static func is_boss_part(id: String) -> bool:
	return PARTS.get(id, {}).get("tier", TIER_BASIC) == TIER_BOSS

static func display_name(id: String) -> String:
	return PARTS.get(id, {}).get("name", id)

static func description(id: String) -> String:
	return PARTS.get(id, {}).get("desc", "")

static func cooldown_of(id: String) -> float:
	return PARTS.get(id, {}).get("cooldown", 0.0)

static func mods_of(id: String) -> Dictionary:
	return PARTS.get(id, {}).get("mods", {})

static func body_zone_of(id: String) -> String:
	return PARTS.get(id, {}).get("body_zone", "")

# Una parte es activable si trae un efecto ejecutable. Las pasivas puras
# (Núcleo Biológico, Garra de Oso, ...) solo aportan `mods`.
static func is_active(id: String) -> bool:
	var effect: Dictionary = PARTS.get(id, {}).get("effect", {})
	return effect.has("kind")

static func ids_for_slot(slot: String) -> Array[String]:
	var out: Array[String] = []
	for id in PARTS:
		if PARTS[id]["slot"] == slot:
			out.append(id)
	return out
