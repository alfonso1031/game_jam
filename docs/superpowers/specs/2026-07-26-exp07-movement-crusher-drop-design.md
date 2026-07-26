# EXP07: movimiento, ataque y drop de Tenaza Trituradora

Fecha: 2026-07-26  
Estado: aprobado  
Alcance: Experimento 07 — Crustáceo Escudo

## Objetivo

Integrar los recursos de movimiento y ataque disponibles en el enemigo
Crustáceo Escudo y establecerlo como la fuente exclusiva de la parte
`crusher_claw` — Tenaza Trituradora.

El arte representa el cuerpo del enemigo. No se reutiliza en el slime ni en la
ejecución de la habilidad equipable.

## Comportamiento visual

La máquina de estados de `exp07_crustacean.gd` continúa siendo la autoridad del
comportamiento:

- `ADVANCE` reproduce en bucle las tres poses de avance mientras el enemigo
  persigue al jugador y mezcla desplazamiento frontal con movimiento lateral;
- `PINCH_WINDUP` reproduce los cinco fotogramas ilustrados de ataque durante
  `0,8 s`;
- al terminar el aviso, `_pinch()` aplica una sola vez el cono de daño y el
  retroceso;
- `RECOVER` reproduce los cinco fotogramas en orden inverso durante `0,6 s` y
  luego retorna a `ADVANCE`;
- el sprite se refleja horizontalmente para mantener la tenaza orientada hacia
  el lado al que apunta `facing`.

El daño no se dispara desde una señal visual. Esto evita que el recurso de
animación duplique o desincronice la autoridad de combate.

## Drop

`exp07_crustacean.tscn` tendrá como único elemento de `drop_parts`:

```gdscript
["crusher_claw"]
```

Un EXP07 normal conserva su porcentaje de drop configurado. Cuando el
ensamblador lo marca como líder de sala, se conserva la regla general de drop
garantizado de `EnemyBase`; al existir un solo elemento en el pool, la
recompensa siempre será Tenaza Trituradora.

## Recursos

- Movimiento:
  `assets/enemies/exp07_crustacean/exp07_crustacean_00.png` a
  `exp07_crustacean_02.png`.
- Ataque de runtime:
  `assets/enemies/exp07_crustacean/exp07_pinch_00.png` a
  `exp07_pinch_04.png`.
- Fuentes originales:
  `assets/enemies/exp07_crustacean/source_attack/`.
- Recurso de animación:
  `actors/enemies/exp07_crustacean_frames.tres`.

Todos los PNG referenciados deben quedar rastreados en Git y cargar después de
una importación nueva, sin depender del caché local `.godot/`.

## Verificación

La integración se acepta cuando:

1. `advance` contiene las tres poses de movimiento y se reproduce en bucle;
2. `pinch_windup` contiene los cinco fotogramas en orden y dura `0,8 s`;
3. `recover` contiene los mismos fotogramas en reversa y dura `0,6 s`;
4. la máquina de estados selecciona la animación correspondiente;
5. el ataque conserva un único punto de aplicación de daño en `_pinch()`;
6. el sprite mira hacia el mismo lado que `facing`;
7. el único drop configurado es `crusher_claw`;
8. todos los recursos usados están rastreados en Git;
9. el enemigo puede instanciarse y actuar en la partida sin errores de recursos.

La sensación de velocidad, claridad del ataque y lectura de orientación
requieren además una prueba jugable humana.
