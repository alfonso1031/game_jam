class_name Layers

# Capas de física 2D. Los nombres legibles viven en project.godot
# ([layer_names]); acá están los números para usarlos desde código sin
# constantes mágicas sueltas por ahí.
#
# BIT   -> índice para set_collision_layer_value() / set_collision_mask_value()
# MASK  -> valor de bits para collision_layer / collision_mask en los .tscn

const WORLD_BIT := 1
const BOSS_BIT := 2
const GAP_BIT := 3

const WORLD_MASK := 1
const BOSS_MASK := 2
const GAP_MASK := 4

# Quién es quién:
#   world : muros, props sólidos y el jugador
#   boss  : el boss, para que no empuje físicamente al jugador
#           (su contacto lo resuelve un Area2D, no la colisión)
#   gap   : huecos del suelo; solo se atraviesan durante el DASH,
#           que apaga GAP_BIT en la máscara del jugador
const PLAYER_MASK := WORLD_MASK | GAP_MASK
