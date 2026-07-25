#!/usr/bin/env bash
set -euo pipefail
OUT="C:/ALFONSO/projects/Game Jam/prueba_2/actors/enemies"

# nombre_archivo|NodeName|script|radio_colision|poligono|color|vida|daño|velocidad|alcance|partes|rate
emit() {
  local file="$1" node="$2" script="$3" radius="$4" poly="$5" color="$6"
  local hp="$7" dmg="$8" speed="$9" detect="${10}" parts="${11}" rate="${12}"
  cat > "$OUT/$file" <<EOF
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://actors/enemies/$script" id="1"]

[sub_resource type="CircleShape2D" id="1"]
radius = $radius

[sub_resource type="CircleShape2D" id="2"]
radius = $(awk "BEGIN{print $radius + 8}")

[node name="$node" type="CharacterBody2D" groups=["enemies"]]
collision_layer = 8
collision_mask = 1
script = ExtResource("1")
max_health = $hp
contact_damage = $dmg
move_speed = $speed
detect_range = $detect
drop_parts = Array[String]($parts)
drop_rate = $rate

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("1")

[node name="Body" type="Polygon2D" parent="."]
color = $color
polygon = PackedVector2Array($poly)

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 1

[node name="Shape" type="CollisionShape2D" parent="Hitbox"]
shape = SubResource("2")
EOF
  echo "  $file"
}

# --- polígonos (formas primitivas, la textura va aparte) ---
CENTIPEDE="52, 0, 30, 20, -10, 26, -46, 16, -52, 0, -46, -16, -10, -26, 30, -20"
SPIDER="46, 0, 33, 33, 0, 46, -33, 33, -46, 0, -33, -33, 0, -46, 33, -33"
SAURIAN="48, 0, 12, 30, -30, 38, -48, 12, -48, -12, -30, -38, 12, -30"
EEL="42, 0, 14, 16, -18, 22, -42, 8, -42, -8, -18, -22, 14, -16"
CHIMERA="40, 0, -12, 34, -28, 12, -40, 0, -28, -12, -12, -34"
THERMAL="46, 0, 23, 40, -23, 40, -46, 0, -23, -40, 23, -40"
CRUSTACEAN="54, 22, 20, 44, -34, 40, -50, 12, -50, -12, -34, -40, 20, -44, 54, -22"
FUNGAL="40, 0, 28, 28, 0, 44, -28, 28, -40, 0, -28, -28, 0, -40, 28, -28"
GOLEM="56, 26, 26, 56, -26, 56, -56, 26, -56, -26, -26, -56, 26, -56, 56, -26"
PARASITE="50, 0, 26, 30, -8, 44, -40, 26, -48, -6, -26, -32, 4, -40, 32, -26"

# --- colores por experimento ---
C_CENTIPEDE="Color(0.62, 0.68, 0.72, 1)"
C_SPIDER="Color(0.42, 0.44, 0.52, 1)"
C_SAURIAN="Color(0.47, 0.55, 0.5, 1)"
C_EEL="Color(0.45, 0.82, 0.9, 1)"
C_CHIMERA="Color(0.6, 0.5, 0.62, 1)"
C_THERMAL="Color(0.82, 0.42, 0.32, 1)"
C_CRUSTACEAN="Color(0.55, 0.6, 0.66, 1)"
C_FUNGAL="Color(0.5, 0.66, 0.45, 1)"
C_GOLEM="Color(0.38, 0.46, 0.5, 1)"
C_PARASITE="Color(0.68, 0.42, 0.5, 1)"

# Pase de dificultad: menos vida, menos velocidad y menos alcance de detección
# que la primera versión. Los experimentos siguen siendo peligrosos en grupo,
# pero uno a uno se pueden leer y esquivar.
echo "Generando escenas de enemigo:"
emit exp01_centipede.tscn Exp01Centipede exp01_centipede.gd 40 "$CENTIPEDE" "$C_CENTIPEDE" 2 1 170.0 1100.0 '["acid_stinger", "serrated_jaw"]' 0.40
emit exp02_spider.tscn    Exp02Spider    exp02_spider.gd    46 "$SPIDER"    "$C_SPIDER"    3 1 80.0  1200.0 '["hydraulic_legs", "bio_netcaster"]' 0.35
emit exp03_saurian.tscn   Exp03Saurian   exp03_saurian.gd   44 "$SAURIAN"   "$C_SAURIAN"   3 1 110.0 1000.0 '["whip_tail", "scaled_skin"]' 0.40
emit exp04_eel.tscn       Exp04Eel       exp04_eel.gd       36 "$EEL"       "$C_EEL"       2 1 200.0 1200.0 '["electric_gland", "adhesive_pads"]' 0.35
emit exp05_chimera.tscn   Exp05Chimera   exp05_chimera.gd   36 "$CHIMERA"   "$C_CHIMERA"   2 1 190.0 1300.0 '["flight_membrane", "bone_stiletto"]' 0.35
emit exp06_thermal.tscn   Exp06Thermal   exp06_thermal.gd   46 "$THERMAL"   "$C_THERMAL"   4 1 145.0 1400.0 '["igneous_arm", "heat_bulb"]' 0.30
emit exp07_crustacean.tscn Exp07Crustacean exp07_crustacean.gd 50 "$CRUSTACEAN" "$C_CRUSTACEAN" 4 1 75.0 1100.0 '["bone_plate", "crusher_claw"]' 0.30
emit exp08_fungal.tscn    Exp08Fungal    exp08_fungal.gd    42 "$FUNGAL"    "$C_FUNGAL"    3 1 70.0  1200.0 '["spore_sac", "mycelium_hand"]' 0.40
emit exp09_golem.tscn     Exp09Golem     exp09_golem.gd     56 "$GOLEM"     "$C_GOLEM"     6 1 85.0  1500.0 '["magnet_core", "scrap_fist"]' 0.25
emit exp10_parasite.tscn  Exp10Parasite  exp10_parasite.gd  46 "$PARASITE"  "$C_PARASITE"  3 1 95.0  1400.0 '["hook_tentacle", "parasite_eye"]' 0.35
echo "Listo."
