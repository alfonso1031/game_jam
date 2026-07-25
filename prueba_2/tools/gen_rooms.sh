#!/usr/bin/env bash
# Genera las escenas de sala a partir de una descripción corta.
#
# Todas las salas comparten la misma caja: interior 180..1740 x 120..960, muros
# de 120 px y un hueco de 240 px centrado en cada lado que tenga salida. Escribir
# eso a mano en cada .tscn es puro copiar y pegar, así que vive acá.
#
# Uso: bash tools/gen_rooms.sh
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/world/rooms"

FLOOR_COLOR="Color(0.196078, 0.32549, 0.372549, 1)"
WALL_COLOR="Color(0.039216, 0.466667, 0.478431, 1)"

# emit_room <archivo> <NodoRaiz> <"N:elevator E:door ..."> <propiedades-extra>
emit_room() {
  local file="$1" node="$2" doors="$3" props="$4"

  local has_n=0 has_s=0 has_e=0 has_o=0
  local uses_door=0 uses_elevator=0
  local spec dir kind
  for spec in $doors; do
    dir="${spec%%:*}"; kind="${spec##*:}"
    case "$dir" in
      N) has_n=1 ;; S) has_s=1 ;; E) has_e=1 ;; O) has_o=1 ;;
    esac
    [ "$kind" = "door" ] && uses_door=1
    [ "$kind" = "elevator" ] && uses_elevator=1
  done

  # --- cabecera: recursos externos y formas de colisión ---
  local ext_id=2 door_id="" elevator_id=""
  local ext_block=""
  if [ "$uses_door" = 1 ]; then
    door_id=$ext_id
    ext_block+="[ext_resource type=\"PackedScene\" path=\"res://world/props/door.tscn\" id=\"$ext_id\"]\n"
    ext_id=$((ext_id + 1))
  fi
  if [ "$uses_elevator" = 1 ]; then
    elevator_id=$ext_id
    ext_block+="[ext_resource type=\"PackedScene\" path=\"res://world/props/elevator.tscn\" id=\"$ext_id\"]\n"
    ext_id=$((ext_id + 1))
  fi

  # Formas: 1 muro horizontal entero, 2 medio horizontal, 3 vertical entero,
  # 4 medio vertical. Se declaran siempre las cuatro; sobra una y no molesta.
  local subres="[sub_resource type=\"RectangleShape2D\" id=\"1\"]
size = Vector2(1800, 120)

[sub_resource type=\"RectangleShape2D\" id=\"2\"]
size = Vector2(780, 120)

[sub_resource type=\"RectangleShape2D\" id=\"3\"]
size = Vector2(120, 840)

[sub_resource type=\"RectangleShape2D\" id=\"4\"]
size = Vector2(120, 300)"

  local load_steps=$((ext_id + 4))

  # --- cuerpo ---
  local body=""
  body+="[node name=\"$node\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\n$props\n\n"
  body+="[node name=\"Floor\" type=\"ColorRect\" parent=\".\"]\noffset_left = 180.0\noffset_top = 120.0\noffset_right = 1740.0\noffset_bottom = 960.0\ncolor = $FLOOR_COLOR\n\n"

  # Muros horizontales (N arriba, S abajo).
  local side y_top y_bottom center_y label
  for side in N S; do
    if [ "$side" = "N" ]; then
      y_top=0.0; y_bottom=120.0; center_y=60.0; label="Top"; local open=$has_n
    else
      y_top=960.0; y_bottom=1080.0; center_y=1020.0; label="Bottom"; local open=$has_s
    fi
    if [ "$open" = 1 ]; then
      body+="[node name=\"Wall${label}Left\" type=\"ColorRect\" parent=\".\"]\noffset_left = 60.0\noffset_top = $y_top\noffset_right = 840.0\noffset_bottom = $y_bottom\ncolor = $WALL_COLOR\n\n"
      body+="[node name=\"Wall${label}Right\" type=\"ColorRect\" parent=\".\"]\noffset_left = 1080.0\noffset_top = $y_top\noffset_right = 1860.0\noffset_bottom = $y_bottom\ncolor = $WALL_COLOR\n\n"
    else
      body+="[node name=\"Wall${label}\" type=\"ColorRect\" parent=\".\"]\noffset_left = 60.0\noffset_top = $y_top\noffset_right = 1860.0\noffset_bottom = $y_bottom\ncolor = $WALL_COLOR\n\n"
    fi
  done

  # Muros verticales (O izquierda, E derecha).
  local x_left x_right center_x
  for side in O E; do
    if [ "$side" = "O" ]; then
      x_left=60.0; x_right=180.0; center_x=120.0; label="Left"; local open=$has_o
    else
      x_left=1740.0; x_right=1860.0; center_x=1800.0; label="Right"; local open=$has_e
    fi
    if [ "$open" = 1 ]; then
      body+="[node name=\"Wall${label}Upper\" type=\"ColorRect\" parent=\".\"]\noffset_left = $x_left\noffset_top = 120.0\noffset_right = $x_right\noffset_bottom = 420.0\ncolor = $WALL_COLOR\n\n"
      body+="[node name=\"Wall${label}Lower\" type=\"ColorRect\" parent=\".\"]\noffset_left = $x_left\noffset_top = 660.0\noffset_right = $x_right\noffset_bottom = 960.0\ncolor = $WALL_COLOR\n\n"
    else
      body+="[node name=\"Wall${label}\" type=\"ColorRect\" parent=\".\"]\noffset_left = $x_left\noffset_top = 120.0\noffset_right = $x_right\noffset_bottom = 960.0\ncolor = $WALL_COLOR\n\n"
    fi
  done

  # --- colisiones ---
  body+="[node name=\"Walls\" type=\"StaticBody2D\" parent=\".\"]\n\n"
  for side in N S; do
    if [ "$side" = "N" ]; then center_y=60.0; label="Top"; local open=$has_n
    else center_y=1020.0; label="Bottom"; local open=$has_s; fi
    if [ "$open" = 1 ]; then
      body+="[node name=\"${label}Left\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2(450, $center_y)\nshape = SubResource(\"2\")\n\n"
      body+="[node name=\"${label}Right\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2(1470, $center_y)\nshape = SubResource(\"2\")\n\n"
    else
      body+="[node name=\"$label\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2(960, $center_y)\nshape = SubResource(\"1\")\n\n"
    fi
  done
  for side in O E; do
    if [ "$side" = "O" ]; then center_x=120.0; label="Left"; local open=$has_o
    else center_x=1800.0; label="Right"; local open=$has_e; fi
    if [ "$open" = 1 ]; then
      body+="[node name=\"${label}Upper\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2($center_x, 270)\nshape = SubResource(\"4\")\n\n"
      body+="[node name=\"${label}Lower\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2($center_x, 810)\nshape = SubResource(\"4\")\n\n"
    else
      body+="[node name=\"$label\" type=\"CollisionShape2D\" parent=\"Walls\"]\nposition = Vector2($center_x, 540)\nshape = SubResource(\"3\")\n\n"
    fi
  done

  # --- puertas y puntos de aparición ---
  local pos spawn res_id prop_name
  for spec in $doors; do
    dir="${spec%%:*}"; kind="${spec##*:}"
    case "$dir" in
      N) pos="Vector2(960, 60)";   spawn="Vector2(960, 220)" ;;
      S) pos="Vector2(960, 1020)"; spawn="Vector2(960, 860)" ;;
      O) pos="Vector2(120, 540)";  spawn="Vector2(280, 540)" ;;
      E) pos="Vector2(1800, 540)"; spawn="Vector2(1640, 540)" ;;
    esac
    if [ "$kind" = "elevator" ]; then res_id=$elevator_id; prop_name="Elevator"; else res_id=$door_id; prop_name="Door"; fi
    body+="[node name=\"${prop_name}${dir}\" parent=\".\" instance=ExtResource(\"$res_id\")]\nposition = $pos\ndirection = \"$dir\"\n\n"
  done
  for spec in $doors; do
    dir="${spec%%:*}"
    case "$dir" in
      N) spawn="Vector2(960, 220)" ;;
      S) spawn="Vector2(960, 860)" ;;
      O) spawn="Vector2(280, 540)" ;;
      E) spawn="Vector2(1640, 540)" ;;
    esac
    body+="[node name=\"Spawn${dir}\" type=\"Marker2D\" parent=\".\"]\nposition = $spawn\n\n"
  done

  {
    echo "[gd_scene load_steps=$load_steps format=3]"
    echo ""
    echo "[ext_resource type=\"Script\" path=\"res://world/rooms/room.gd\" id=\"1\"]"
    printf "%b" "$ext_block"
    echo ""
    echo "$subres"
    echo ""
    printf "%b" "$body"
  } > "$OUT/$file"
  echo "  $file"
}

echo "Generando salas:"

# --- Nivel -2: se le abre la salida norte hacia Mantenimiento ---
emit_room l2_esclusa.tscn L2Esclusa "O:door N:elevator" \
'lamps_n = Array[int]([3, 9])
lamps_e = Array[int]([3])
tanks = Array[Vector2i]([Vector2i(2, 1), Vector2i(10, 1)])
debris = Array[Vector2i]([Vector2i(4, 5), Vector2i(8, 5)])
puddles = Array[Vector2i]([Vector2i(6, 4)])
sign_text = "ASCENSOR ↑ NIVEL -1"
sign_cell = Vector2i(9, 0)'

# --- Nivel -1: MANTENIMIENTO ---
emit_room l1_ascensor.tscn L1Ascensor "S:elevator E:door" \
'lamps_n = Array[int]([2, 6, 10])
dead_lamps_s = Array[int]([4])
tanks = Array[Vector2i]([Vector2i(1, 1), Vector2i(11, 5)])
debris = Array[Vector2i]([Vector2i(3, 5)])
puddles = Array[Vector2i]([Vector2i(5, 3), Vector2i(8, 1)])
sign_text = "NIVEL -1 · MANTENIMIENTO"
sign_cell = Vector2i(6, 0)'

emit_room l1_taller.tscn L1Taller "O:door N:door E:door" \
'lamps_s = Array[int]([2, 10])
dead_lamps_n = Array[int]([4, 8])
tanks = Array[Vector2i]([Vector2i(2, 3), Vector2i(10, 3)])
debris = Array[Vector2i]([Vector2i(5, 5), Vector2i(7, 1)])
puddles = Array[Vector2i]([Vector2i(4, 2), Vector2i(8, 4)])
sign_text = "TALLER DE PIEZAS"
sign_cell = Vector2i(9, 0)'

emit_room l1_deposito.tscn L1Deposito "S:door" \
'lamps_e = Array[int]([2])
lamps_o = Array[int]([4])
dead_lamps_n = Array[int]([6])
tanks = Array[Vector2i]([Vector2i(2, 1), Vector2i(3, 1), Vector2i(9, 5), Vector2i(10, 5)])
debris = Array[Vector2i]([Vector2i(6, 2), Vector2i(6, 4)])
puddles = Array[Vector2i]([Vector2i(2, 4), Vector2i(10, 2)])
sign_text = "DEPÓSITO · RESIDUOS"
sign_cell = Vector2i(6, 0)'

emit_room l1_compuerta.tscn L1Compuerta "O:door N:elevator" \
'lamps_n = Array[int]([2, 10])
lamps_s = Array[int]([6])
tanks = Array[Vector2i]([Vector2i(1, 3), Vector2i(11, 3)])
debris = Array[Vector2i]([Vector2i(4, 1), Vector2i(8, 5)])
puddles = Array[Vector2i]([Vector2i(6, 3)])
sign_text = "COMPUERTA DE PRESIÓN ↑"
sign_cell = Vector2i(6, 0)'

# --- Nivel 0: SUPERFICIE ---
emit_room l0_vestibulo.tscn L0Vestibulo "S:elevator E:door" \
'lamps_n = Array[int]([3, 6, 9])
lamps_o = Array[int]([3])
tanks = Array[Vector2i]([Vector2i(2, 2), Vector2i(10, 2)])
debris = Array[Vector2i]([Vector2i(5, 5), Vector2i(7, 5)])
puddles = Array[Vector2i]([Vector2i(6, 1)])
sign_text = "NIVEL 0 · VESTÍBULO"
sign_cell = Vector2i(6, 0)'

emit_room l0_salida.tscn L0Salida "O:door" \
'lamps_n = Array[int]([2, 5, 7, 10])
lamps_e = Array[int]([1, 5])
debris = Array[Vector2i]([Vector2i(3, 5), Vector2i(9, 5)])
sign_text = "SALIDA"
sign_cell = Vector2i(9, 3)'

echo "Listo."
