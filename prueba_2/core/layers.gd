# Sin `class_name`, igual que `palette.gd`: se consume siempre con
# `preload("res://core/layers.gd")`.
#
# Capas de física 2D. Los nombres legibles viven en project.godot
# ([layer_names]); acá están los números para usarlos desde código sin
# constantes mágicas sueltas por ahí.
#
# BIT   -> índice para set_collision_layer_value() / set_collision_mask_value()
# MASK  -> valor de bits para collision_layer / collision_mask en los .tscn

const WORLD_BIT := 1
const BOSS_BIT := 2
const GAP_BIT := 3
const ENEMY_BIT := 4

const WORLD_MASK := 1
const BOSS_MASK := 2
const GAP_MASK := 4
const ENEMY_MASK := 8

# Quién es quién:
#   world : muros, props sólidos y el jugador
#   boss  : el boss, para que no empuje físicamente al jugador
#           (su contacto lo resuelve un Area2D, no la colisión)
#   gap   : huecos del suelo; solo se atraviesan durante el DASH,
#           que apaga GAP_BIT en la máscara del jugador
#   enemy : los experimentos. Misma idea que el boss — no comparten capa con
#           `world`, así que no empujan al jugador ni se atascan entre ellos;
#           el contacto lo resuelve el Area2D `Hitbox` de cada enemigo.
const PLAYER_MASK := WORLD_MASK | GAP_MASK

# Cuerpo de enemigo: choca contra muros, ignora al jugador y a sus pares.
const ENEMY_BODY_MASK := WORLD_MASK
# Ataques del jugador: buscan enemigos y muros (los muros cortan proyectiles).
const PLAYER_ATTACK_MASK := WORLD_MASK | ENEMY_MASK
