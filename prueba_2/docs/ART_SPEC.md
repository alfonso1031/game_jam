# Especificación de arte — Slime Escape

Documento para pasar a diseño. Todas las medidas salen del código actual: las
formas primitivas que se ven ahora ya están ajustadas al tamaño de las hitboxes
y a la legibilidad en pantalla, así que **el arte tiene que respetar la silueta
y el tamaño** o hay que reajustar colisiones y equilibrio.

---

## 1 · Reglas que aplican a TODO

| Regla | Valor | Por qué |
|---|---|---|
| Resolución de referencia | 1920 × 1080 | La cámara no hace zoom: 1 px de arte = 1 px de pantalla |
| Formato | PNG-24 con alfa | Sin fondo, sin sombra quemada |
| Pivote | **Centro exacto del lienzo** | Todo en el juego se posiciona por su centro |
| Orientación | Mirando a la **derecha** (→) | El código rota el sprite con `facing.angle()`, y ángulo 0 = derecha |
| Margen | 16 px libres al borde del lienzo | Evita recortes cuando el sprite se estira o rota |
| Perspectiva | Cenital ligeramente inclinada (top-down 3/4) | Es lo que sugiere la planta de las salas |

### Iluminación — leer esto antes de pintar

El juego oscurece toda la escena a **~47 % de brillo** (`CanvasModulate` a
`0.45, 0.48, 0.50`) y luego la vuelve a iluminar con luces 2D puntuales
(lámparas de pared, el propio slime, las partes en el suelo).

Consecuencias para diseño:

- **Pintad con brillo normal, no oscuro.** El motor ya oscurece. Si entregáis
  arte oscuro, en el juego será ilegible.
- **Nada de sombras ni luces quemadas en la textura.** Las hace el motor.
- El destello de daño multiplica el color **× 2,2**. Si una zona ya es blanco
  puro, ese golpe no se ve. Dejad los blancos por debajo de `#E0E0E0`.
- Opcional y muy recomendable: entregar **normal map** por sprite
  (`nombre_n.png`). Godot lo usa automáticamente y las luces cobran volumen.

### Paleta base

Es la paleta actual del juego. No es obligatoria para el arte final, pero la
interfaz y las luces están afinadas con ella; si os separáis mucho, avisad.

| Uso | Hex |
|---|---|
| Vacío / fondo | `#313638` |
| Suelo | `#32535F` |
| Muro | `#0A777A` |
| Cuerpo del slime | `#4AA881` |
| Núcleo del slime | `#73EFE8` |
| Luz cálida | `#ECF3B0` |

### Decisión pendiente antes de empezar

**¿Pixel art o ilustración?** Cambia la configuración del motor y no es
reversible sin retocar todo:

- **Ilustración / vectorial** → como está ahora. Filtrado suave. Sin cambios.
- **Pixel art** → hay que poner el filtro en *Nearest* en `project.godot` y
  definir a qué resolución se pinta (ej. dibujar a 1/4 y escalar ×4). Decididlo
  **antes** de la primera entrega.

---

## 2 · Slime (protagonista)

Lienzo **128 × 128**. Cuerpo de **90 px de diámetro**, núcleo interior de
**50 px** centrado.

> ⚠️ **Restricción importante:** el código deforma el slime en tiempo real
> (aplasta y estira hasta 1,36 × 0,74 en ejes distintos). El diseño tiene que
> aguantar deformación no uniforme: silueta simple, sin detalles finos, sin
> texto ni elementos que se vean raros al cizallarse.

El núcleo va en capa aparte (`Core`) porque parpadea y se ilumina solo.
Entregad **cuerpo y núcleo en archivos separados**.

| Estado | Nombre de archivo | Notas |
|---|---|---|
| Reposo | `slime_idle.png` | Respira solo por código |
| Cargando | `slime_charge.png` | Se comprime hacia atrás |
| Lanzado | `slime_launch.png` | Estirado en la dirección de vuelo |
| Recuperando | `slime_recover.png` | Aplastado al aterrizar |
| Núcleo | `slime_core.png` | Capa interior, se ilumina |

---

## 3 · Enemigos — los 10 experimentos

**Lienzo uniforme 160 × 160** para todos, para simplificar el pipeline. Lo que
cambia es cuánto ocupa el cuerpo dentro.

| # | Nombre | Diámetro del cuerpo | Silueta actual | Vida |
|---|---|---|---|---|
| 01 | Ciempiés de Agujas | 104 px | Alargado horizontal, espinas | 2 |
| 02 | Arácnido Blindado | 92 px | Octágono pesado | 3 |
| 03 | Saurio Escamado | 96 px | Cuña, cola gruesa | 3 |
| 04 | Anguila Voltaica | 84 px | Alargado fino, translúcido | 2 |
| 05 | Quimera Alada | 80 px | Triangular, alas | 2 |
| 06 | Bestia Térmica | 92 px | Hexágono macizo, vetas al rojo | 4 |
| 07 | Crustáceo Escudo | 108 px | Ancho, **una tenaza enorme al frente** | 4 |
| 08 | Cuerpo Fúngico | 88 px | Humanoide irregular | 3 |
| 09 | Gólem de Metal Sólido | 112 px | Bloque cuadrado | 6 |
| 10 | Mutante Parásito | 100 px | Masa amorfa, tentáculo | 3 |

### Legibilidad — no es decoración, es mecánica

Tres siluetas tienen que comunicar su regla **de un vistazo**, o el jugador
pierde vida sin entender por qué:

- **07 Crustáceo:** bloquea el daño que le llega de frente en un cono de 100°.
  La tenaza tiene que leerse como escudo y **verse claramente hacia dónde
  apunta**.
- **03 Saurio:** es ciego y solo ataca si lo rodeas. Que no tenga ojos, y que
  se note su frente.
- **09 Gólem:** su embestida es imparable. Tiene que verse macizo y lento, muy
  distinto del Ciempiés que también embiste pero sí se puede frenar.

### Estados de animación por enemigo

Cada uno tiene su máquina de estados. Estos son los fotogramas clave que
necesita el juego:

| # | Estados |
|---|---|
| 01 | `approach` (zig-zag) · `windup` (se tensa) · `charge` (embiste) · `rest` (aturdido) |
| 02 | `reposition` · `shoot_windup` · `slam_windup` · `recover` |
| 03 | `walk` · `tail_windup` · `recover` |
| 04 | `strafe` · `discharge_windup` · `retreat` |
| 05 | `orbit` (vuela) · `hover` (pausa en el aire) · `dive` (picado) · `recover` |
| 06 | `chase` · `slam_windup` · `recover` |
| 07 | `advance` · `pinch_windup` · `recover` |
| 08 | `walk` · `release` (suelta esporas) |
| 09 | `walk` · `charge_windup` · `charge` · `recover` |
| 10 | `crawl` · `aim` · `strike` (tentáculo) · `recover` |

**El `windup` es el estado más importante de todos.** Es el aviso previo al
ataque y dura entre 0,5 y 1,3 segundos. Si no se distingue claramente del
estado normal, el enemigo se vuelve injusto. Que tenga un cambio de postura o
de color evidente.

Si podéis dar solo un fotograma por estado, empezad por `windup` de cada uno.

---

## 4 · Entorno

Todas las salas son la misma caja. Rejilla de **13 × 7 celdas de 120 px**.

| Elemento | Medida | Formato pedido |
|---|---|---|
| Suelo | Área de 1560 × 840 | Textura **tileable de 240 × 240** (= 2 celdas) |
| Muro horizontal | Franja de 120 px de alto | Tira **tileable de 240 × 120** + esquinas |
| Muro vertical | Franja de 120 px de ancho | Tira **tileable de 120 × 240** |
| Hueco de puerta | 240 px de ancho | El marco va en el arte de puerta |
| Pozo / hueco de suelo | 120 × 840 | Tileable vertical |

### Props

| Prop | Tamaño real | Lienzo | Notas |
|---|---|---|---|
| Tanque de contención | 104 × 104 | 128 × 128 | Lleva líquido y una grieta |
| Escombros | 88 × 72 | 128 × 128 | 2-3 variantes para que no se repita |
| Charco | 114 × 86 | 128 × 128 | Semitransparente, 2 variantes |
| Lámpara de pared | 64 × 20 | 96 × 64 | 2 versiones: **encendida y fundida** |
| Puerta | 110 × 110 + jambas | 256 × 256 | 2 estados: **abierta y sellada** |
| Ascensor | 120 × 120 | 256 × 256 | 2 estados: abierto y sellado |
| Parte soltada | 60 × 60 | 128 × 128 | Icono genérico + brillo |

La puerta y el ascensor **necesitan sí o sí los dos estados**: la sala se cierra
mientras hay enemigos vivos, y el jugador tiene que ver que está encerrado.

### Ambientación por nivel

Cuatro pisos, de abajo arriba. Que se note que el slime va escapando:

| Nivel | Nombre | Tono |
|---|---|---|
| -3 | Contención | Celdas, sucio, húmedo, luz de emergencia |
| -2 | Bio-Laboratorios | Clínico, tanques, verde |
| -1 | Mantenimiento | Tuberías, óxido, industrial |
| 0 | Superficie | Limpio, luz natural entrando por la salida |

---

## 5 · Interfaz

| Elemento | Tamaño | Notas |
|---|---|---|
| Corazón | 28 × 28 | Hacen falta **3 versiones: lleno, medio y vacío** |
| Hueco de parte | 230 × 62 | 6 en columna, con número de tecla |
| Icono de parte | 48 × 48 | 44 partes distintas — ver lista abajo |
| Marco del mapa | — | Las salas se dibujan como rectángulos 150 × 84 |

Los **iconos de parte son 44** y es el lote más grande del proyecto. Sugerencia:
que hagan primero un set de 6-8 formas base por tipo de efecto (proyectil,
golpe, pulso, impulso, trampa, rayo, mejora) y varíen color y detalle. Sale
coherente y cuesta un décimo.

---

## 6 · Cómo entregarlo

### Nombres de archivo

Que coincidan con las claves del código, así se integran sin traducir nada:

```
slime_idle.png
slime_charge.png
exp01_centipede_approach.png
exp01_centipede_windup.png
exp07_crustacean_advance.png
prop_tank.png
prop_lamp_on.png
prop_lamp_dead.png
env_floor_l3.png
env_wall_h_l3.png
ui_heart_full.png
ui_heart_half.png
```

Todo en minúsculas, sin espacios, sin tildes.

### Estructura de carpetas

Que la carpeta compartida imite esta estructura, para poder copiar y pegar:

```
arte/
  slime/
  enemigos/
    exp01_centipede/
    exp02_spider/
    ...
  entorno/
    l3_contencion/
    l2_biolab/
    l1_mantenimiento/
    l0_superficie/
  props/
  ui/
```

### Dónde cae cada cosa en el repositorio

Hay dos sitios y no son intercambiables:

| Carpeta | Qué guarda |
|---|---|
| `art_raw/` (raíz del repo) | La entrega **cruda**, tal cual llega: lienzos de 1920 × 1080, hojas de sprites, los ZIP. |
| `prueba_2/assets/` | La versión **procesada** que carga el juego: recortada, orientada y al tamaño de estas tablas. |

`art_raw/` vive fuera de `prueba_2/` a propósito: Godot importa todo lo que
encuentra bajo la carpeta del proyecto, así que una entrega cruda guardada
dentro se cuela entera en la exportación. Cómo se pasa de una a otra está en
[`art_raw/README.md`](../../art_raw/README.md).

### Entregable adicional

Junto a los PNG, pedid **el archivo fuente editable** (`.aseprite`, `.psd`,
`.svg` o `.kra`). Cuando haya que cambiar un color o reajustar un tamaño, sin
fuente hay que rehacerlo.

---

## 7 · Orden de trabajo recomendado

No pidáis los 10 enemigos de golpe. Haced un **piloto**:

1. **Slime** (idle + carga + lanzado) — es lo que más se ve.
2. **Un enemigo completo**: el 01 Ciempiés, con sus 4 estados.
3. **Un set de entorno**: suelo + muros + puerta del nivel -3.

Integramos esos tres, se ve en movimiento y con la iluminación real, y se
corrige lo que haga falta. **Después** el resto. Así un malentendido cuesta un
enemigo, no diez.

---

## 8 · Estado de la entrega

### Integrado

| Qué | Dónde | Notas |
|---|---|---|
| 13 fondos de sala | `assets/environment/rooms/` | Los 13 completos, uno por combinación de puertas. |
| **07 Crustáceo Escudo** | `assets/enemies/exp07_crustacean/` | 3 fotogramas. Es el primer experimento con arte. |

El Crustáceo llegó como **tres poses de la misma postura a tres alturas**
(agachado, medio, encabritado), no como estados sueltos. De ahí salen sus tres
estados reutilizando la tirada en los dos sentidos: sube durante
`pinch_windup`, se queda arriba en el golpe y baja en `recover`. Está en
`actors/enemies/exp07_crustacean_frames.tres`, y `tests/check_enemy_animations.tscn`
avisa si un estado pide una animación que no existe.

**Cómo entra el arte de un experimento nuevo:** en su `.tscn`, cambiar el nodo
`Body` (Polygon2D) por uno llamado `Sprite` (AnimatedSprite2D) con su
SpriteFrames y su `autoplay`, y darle a su script un `_visual_state()` que
devuelva el nombre de animación de cada estado. `enemy_base.gd` hace el resto y
no toca a los que siguen con polígono. Si un nombre todavía no existe, se usa el
`autoplay`: se puede entregar estado a estado sin romper nada.

### Dos correcciones para la próxima entrega

1. **Que mire a la derecha.** El Crustáceo llegó mirando a la izquierda y hubo
   que voltearlo al procesarlo (§1, «Orientación»). Es un minuto, pero se
   acumula por cada bicho.
2. **La hoja de sprites no se puede cortar.** `Sprite_Claw/spritesheet(2).png`
   trae los fotogramas con anchos distintos (737, 768 y 754 px) y sin separación
   entre el segundo y el tercero, así que no hay rejilla que valga. Se usaron los
   PNG sueltos de lienzo completo, que sí conservan el registro. **Si mandáis
   hoja, que sea de celdas iguales; si no, mandad PNG sueltos y ya.**

### Un aviso sobre la silueta

El Crustáceo entregado mide 778 × 407 px, casi 2:1. Su colisión es un **círculo**
de 100 px de diámetro, ajustada al polígono anterior, que era casi cuadrado.
Puesto a escala de juego (120 × 63 px) el bicho es más ancho que alto, así que
por arriba y por abajo hay una franja de colisión que **no se ve**: el jugador
recibe el golpe sin tocar nada.

No se cambió la colisión porque el Crustáceo está equilibrado como muro móvil y
adelgazarlo deja pasar por encima. Hay que elegir una:

- **Arte más alto** (más cerca de 1:1, que es lo que dice la tabla de §3), o
- **cambiar la colisión a cápsula** y reequilibrar la sala.

Es el caso concreto del aviso de la cabecera de este documento: si el arte no
respeta la silueta, hay que tocar colisiones y equilibrio.

---

## 9 · Lo que ya pueden mirar hoy

El juego funciona con formas primitivas de colores. Que lo ejecuten y lo
jueguen: las siluetas, tamaños y tiempos de aviso ya están ajustados y son la
referencia real. Todo lo de este documento se ve en movimiento en 5 minutos de
partida.
