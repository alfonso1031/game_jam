# Animación entregada del slime y balance de salas

## Objetivo

Integrar el arte de `Slime_Personaje-20260726T191625Z-1-001.zip` en el
protagonista sin alterar sus mecánicas, fusionar y publicar ese cambio primero,
y después ajustar la generación procedural para reducir salas vacías y aumentar
los rangos de enemigos.

## Fuentes entregadas

El ZIP contiene cuatro hojas PNG transparentes con celdas de `320 × 320`:

- `idle spritesheet.png`: 5 fotogramas.
- `walk spritesheet.png`: 2 fotogramas.
- `jump spritesheet.png`: 6 fotogramas.
- `spritesheet(8).png`: 12 fotogramas de licuado y recomposición, confirmados
  como animación de recuperación.

Las hojas originales se conservarán bajo `art_raw/personaje/slime/`. Un
procesador reproducible separará las celdas, calculará un recorte común para
todos los fotogramas y los centrará sobre un lienzo transparente uniforme de
runtime. No se editarán manualmente los PNG derivados.

## Presentación del jugador

`slime.tscn` sustituirá el cuerpo vectorial visible por un `AnimatedSprite2D`,
pero conservará sin cambios el `CharacterBody2D`, el círculo de colisión, la
luz, la barra de carga, el audio, las habilidades y `ScaleShell`.

Mapeo aprobado:

| Estado de gameplay | Animación |
|---|---|
| `IDLE`, `CHARGING` | `idle` |
| Movimiento continuo con piernas | `walk` |
| `LAUNCHING`, `DASHING`, `PART_DASH` | `jump` |
| `RECOVERING` | `recover` |

`idle` y `walk` se reproducen en loop. `jump` y `recover` no se reinician
mientras el nombre de animación no cambie. El sprite mira a la derecha en la
fuente y usa `flip_h` según el signo horizontal de `_facing`; la rotación visual
del polígono anterior desaparece para que el personaje permanezca legible.

La duración de recuperación del gameplay sigue siendo la autoridad. La
animación puede terminar antes o ser interrumpida cuando el estado vuelva a
`IDLE`; no se añadirán esperas que cambien control, invulnerabilidad o balance.

## Compatibilidad visual

- El cuerpo y núcleo vectoriales quedan ocultos, no eliminados, para mantener
  referencias internas y facilitar efectos existentes.
- La costra `ScaleShell` continúa por encima del sprite.
- La luz conserva energía y radio.
- La barra de carga conserva posición y reglas.
- No cambian hitbox, velocidades, distancias, daño, capas ni máscaras.

## Balance procedural posterior al primer push

El cambio de balance se realiza y publica después de que la animación del slime
ya esté en `origin/main`.

La tabla vigente es `easy=50`, `hard=30`, `empty=20`. Al reducir `empty` a
`10` sin cambiar la frecuencia difícil, queda:

- normal/fácil: `60 %`;
- difícil: `30 %`;
- vacía: `10 %`.

Los rangos de enemigos serán:

- normal/fácil: entero aleatorio de `1` a `3`;
- difícil: entero aleatorio de `4` a `7`.

El preboss y los destinos exclusivos de rejilla conservan sus reglas actuales.
La generación sigue siendo determinista por `(seed, attempt)`.

## Pruebas y aceptación

### Animación

- Prueba RED/GREEN del contrato `SpriteFrames`: 5 `idle`, 2 `walk`, 6 `jump`
  y 12 `recover`.
- Prueba del mapeo de estados, loops, orientación y continuidad.
- Suites de audio, movilidad con piernas, costra y combate.
- Importación y arranque controlado sin errores.
- Captura visual en al menos `1920 × 1080`.

### Balance

- Prueba RED/GREEN focalizada de la tabla `60/30/10`.
- Muestreo determinista que aproxime esas proporciones.
- Verificación de que todas las salas fáciles estén en `1..3` y las difíciles
  en `4..7` sobre muchas seeds.
- Verificación de determinismo y validador actualizado.

`tests/run_map_tests.gd` ya falla en `main` por expectativas antiguas ajenas a
este cambio (rejillas adyacentes a la fuente, máximo de 12 y contenido
`closure`). Esos fallos se reportarán como baseline preexistente; este trabajo
no reescribirá toda esa suite ni cambiará la topología de rejillas.

## Entrega Git

1. Commit(s) de animación, fusión local en `main` y primer push a `origin/main`.
2. Commit de balance procedural, nueva verificación y segundo push a
   `origin/main`.
3. Los cambios locales no relacionados del checkout principal se preservan.
