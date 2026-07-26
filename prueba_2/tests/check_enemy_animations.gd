extends Node

# Herramienta de desarrollo: comprueba que los nombres que devuelve
# `_visual_state()` existen de verdad en el SpriteFrames del experimento.
#
# Hace falta porque `enemy_base.gd` cae al `autoplay` cuando el nombre no
# existe: eso es lo que permite entregar el arte estado a estado, pero también
# esconde una errata. Un `pinch_windp` mal escrito no rompe nada, solo deja al
# bicho atacando con la animación de caminar y sin aviso previo.
#
# Va como escena y no como `--script` porque `enemy_base.gd` usa el autoload
# `Inventory`, y los autoloads no existen fuera del bucle principal. Se lanza:
#   godot --headless --path <proyecto> res://tests/check_enemy_animations.tscn

const EnemyDB := preload("res://core/enemy_db.gd")

func _ready() -> void:
	var problems: Array[String] = []
	var checked := 0

	for type_id in EnemyDB.SCENES:
		var enemy: Node = EnemyDB.SCENES[type_id].instantiate()
		var sprite: AnimatedSprite2D = enemy.get_node_or_null("Sprite")
		if sprite == null:
			# Todavía va con polígono de bloque: no hay nada que comprobar.
			enemy.free()
			continue
		checked += 1

		var frames := sprite.sprite_frames
		if frames == null:
			problems.append("%s: el nodo Sprite no tiene SpriteFrames" % type_id)
			enemy.free()
			continue
		# El `autoplay` es la red de seguridad de `_update_sprite()`. Si falla él,
		# no queda nada abajo.
		if sprite.autoplay == "" or not frames.has_animation(sprite.autoplay):
			problems.append("%s: autoplay '%s' no está en el SpriteFrames" % [type_id, sprite.autoplay])

		# `State` es el enum de la máquina del experimento. Se recorre entero para
		# que ningún estado se quede sin animación declarada.
		var constants: Dictionary = enemy.get_script().get_script_constant_map()
		if constants.has("State"):
			for state_value in constants["State"].values():
				enemy.set("_state", state_value)
				var wanted: StringName = enemy._visual_state()
				if wanted != &"" and not frames.has_animation(wanted):
					problems.append("%s: estado %d pide '%s' y no existe" % [type_id, state_value, wanted])
				elif wanted != &"" and frames.get_frame_count(wanted) == 0:
					problems.append("%s: estado %d pide '%s' sin fotogramas" % [type_id, state_value, wanted])
		enemy.free()

	if problems.is_empty():
		print("ANIM_CHECK_OK  experimentos con arte: %d" % checked)
		get_tree().quit(0)
		return
	for problem in problems:
		printerr("ANIM_CHECK_FAIL  " + problem)
	get_tree().quit(1)
