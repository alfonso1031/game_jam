# art_raw — entregas de arte sin procesar

Aquí vive el arte **tal y como llega** de diseño: renders a 1920 × 1080, hojas
de sprites sin recortar y los ZIP originales de cada entrega.

## Por qué está fuera de `prueba_2/`

Godot importa **todo** lo que hay bajo la carpeta del proyecto. Mientras estas
entregas vivieron dentro, el proyecto arrastraba ~106 MB de PNG duplicados con
sus `.import` al lado, y todos acababan en la exportación. Fuera del proyecto
Godot ni los mira, pero siguen versionados y a mano.

Lo que entra en `prueba_2/assets/` es siempre la versión **procesada**: recortada
al tamaño de juego, con el pivote y la orientación que pide
[`prueba_2/docs/ART_SPEC.md`](../prueba_2/docs/ART_SPEC.md).

## `entorno/` — fondos de sala

`Nivel/` son los 13 fondos originales. Se copiaron a
`prueba_2/assets/environment/rooms/` **renombrados y sin tocar un píxel** (misma
suma MD5), porque `core/room_backgrounds.gd` los busca por combinación de
puertas. La correspondencia:

| Original | En el juego | Puertas |
|---|---|---|
| `1_Puerta/Nivel_Basico_Var_1.png` | `room_1door_O.png` | O |
| `1_Puerta/Nivel_Basico_Var_2.png` | `room_1door_E.png` | E |
| `1_Puerta/Nivel_Basico_Var_3.png` | `room_1door_N.png` | N |
| `1_Puerta/Nivel_Basico_Var_4.png` | `room_1door_S.png` | S |
| `2_Puertas/Nivel_Basico_Horizontal.png` | `room_2door_OE.png` | O+E |
| `2_Puertas/Nivel_Basico_Vertical.png` | `room_2door_NS.png` | N+S |
| `2_Puertas/Nivel_Basico_Var_3.png` | `room_2door_SE.png` | S+E |
| `2_Puertas/Nivel_Basico_Var_4.png` | `room_2door_ON.png` | O+N |
| `3_Puertas/Nivel_Basico_Var_1.png` | `room_3door_NES.png` | N+E+S |
| `3_Puertas/Nivel_Basico_Var_2.png` | `room_3door_NEO.png` | N+E+O |
| `3_Puertas/Nivel_Basico_Var_3.png` | `room_3door_NSO.png` | N+S+O |
| `3_Puertas/Nivel_Basico_Var_4.png` | `room_3door_ESO.png` | E+S+O |
| `Nivel_Basico_4_Puertas.png` | `room_4door_ONES.png` | N+E+S+O |

Los nombres de origen (`Var_1`…`Var_4`) no dicen qué lado abre cada uno: la
correspondencia se sacó muestreando los píxeles del hueco de puerta. Si llega
una entrega nueva con el mismo esquema de nombres, **hay que volver a
comprobarlo**, no fiarse de esta tabla.

## `enemigos/` — experimentos

- `Prueba_2/Timeline 1_000{1,2,3}.png` — tres poses del **Crustáceo Escudo**
  (experimento 07) sobre lienzo completo de 1920 × 1080. Es la fuente buena: los
  tres comparten lienzo, así que el registro entre fotogramas se conserva solo.
- `Sprite_Claw/spritesheet(2).png` — los mismos tres fotogramas en una hoja de
  3072 × 407. **No usar:** los fotogramas están empaquetados con anchos
  distintos (737, 768 y 754 px) y sin separación entre el segundo y el tercero,
  así que no se puede cortar en rejilla.

### Cómo se generó `assets/enemies/exp07_crustacean/`

De los tres PNG de `Prueba_2/`, con el mismo recorte para los tres:

1. Recorte común `x 569..1346, y 333..739` (778 × 407) — es la unión de las
   siluetas de los tres fotogramas, y usar un solo rectángulo es lo que mantiene
   el registro del animador.
2. Volteo horizontal: el arte mira a la izquierda y `ART_SPEC.md` §1 pide que
   mire a la derecha, que es el ángulo 0 con el que el código orienta.
3. Reescalado a 120 × 63 px y centrado en lienzo de 160 × 96.

Si llega una entrega corregida, se repite igual. Los números de arriba son todo
lo que hace falta.
