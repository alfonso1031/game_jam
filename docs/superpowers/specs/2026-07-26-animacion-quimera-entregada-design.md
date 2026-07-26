# Animación ilustrada de la Quimera Albina

Fecha: 2026-07-26
Estado: aprobado para implementación

## Objetivo

Sustituir las seis poses funcionales actuales de la Quimera Albina por las animaciones
ilustradas entregadas en `Nivel_1-20260726T183847Z-1-001.zip`, sin modificar su
comportamiento de combate.

La entrega contiene:

- siete fotogramas `Idle`;
- dieciséis fotogramas `Angry`;
- hojas de sprites equivalentes;
- archivos fuente `.clip` y un video de referencia.

## Alcance

- Copiar el ZIP intacto a la raíz local del repositorio.
- Mantener el ZIP fuera de los commits: pesa 121,6 MB y supera el límite normal de
  archivos de GitHub.
- Extraer a `art_raw/` solamente los PNG necesarios para reproducir el procesamiento.
- Generar fotogramas optimizados dentro de
  `prueba_2/assets/bosses/containment_chimera/animations/`.
- Actualizar `boss_core_frames.tres`, el mapeo visual del boss, las pruebas y la
  documentación vigente.
- Conservar intactos vida, daño, velocidades, tiempos, colisiones, grupos, drops,
  recompensas y ciclo de partida.

No se integrarán los `.clip` ni el MP4 al proyecto Godot. Permanecerán disponibles dentro
del ZIP original.

## Diseño visual

La máquina de estados mantiene sus cinco estados actuales. La traducción visual queda:

| Estado | Animación |
|---|---|
| `SEEK_CORNER` | `idle` |
| `CORNER_AIM` | `angry` |
| `POUNCE` | `angry` |
| `RECOVER` | `idle` |
| `DEAD` | ninguna; se conserva el flujo de muerte actual |

`CORNER_AIM` y `POUNCE` comparten el mismo nombre de animación. Como
`_update_sprite_animation()` solo llama `play()` cuando cambia el nombre, `angry` continúa
sin reiniciarse al comenzar la embestida.

Las animaciones no aplican daño ni disparan transiciones. El script y sus temporizadores
siguen siendo la única autoridad del gameplay.

## Pipeline de assets

Se añadirá un procesador reproducible específico para la entrega de la Quimera:

1. cargar los siete PNG `Idle` y los dieciséis PNG `Angry`;
2. validar que todos existan, tengan alfa y contengan píxeles visibles;
3. calcular un recorte común para los 23 fotogramas;
4. añadir un margen uniforme al recorte;
5. redimensionar con alfa premultiplicado para evitar halos oscuros;
6. centrar cada resultado en un lienzo runtime común;
7. guardar los fotogramas con nombres estables `chimera_idle_00..06` y
   `chimera_angry_00..15`.

El recorte común conserva escala y pivote entre fotogramas. Los PNG 1920 × 1080 y las
hojas 7680 px no se usarán directamente en runtime para evitar un consumo innecesario de
memoria gráfica.

## Cambios de código y recursos

- `prueba_2/tools/art/`: procesador de la nueva entrega.
- `art_raw/enemigos/containment/boss_chimera/`: PNG fuente extraídos.
- `prueba_2/assets/bosses/containment_chimera/animations/`: 23 fotogramas procesados.
- `prueba_2/actors/boss/boss_core_frames.tres`: animaciones `idle` y `angry`.
- `prueba_2/actors/boss/boss_core.gd`: mapeo de estados visuales.
- `prueba_2/actors/boss/boss_core.tscn`: autoplay `idle`.
- `prueba_2/tests/containment_boss_tests.gd`: contrato de frames y continuidad.
- `docs/agents/ESTADO_ACTUAL.md`, `docs/agents/REFERENCIA.md` y
  `docs/ARQUITECTURA.md`: estado, receta y arquitectura actualizados.

## Pruebas y verificación

La implementación seguirá un ciclo rojo-verde:

1. cambiar primero la prueba del boss para exigir `idle` con 7 frames, `angry` con
   16 frames y continuidad entre aviso y embestida;
2. ejecutar la prueba y confirmar que falla por faltar el nuevo contrato;
3. implementar el pipeline, recursos y mapeo mínimos;
4. regenerar e importar los assets;
5. ejecutar nuevamente la prueba y el resto de suites relacionadas.

Verificación final:

```bash
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn
godot --headless --path prueba_2 res://tests/check_enemy_animations.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --path prueba_2
```

También se generarán capturas del modo visual `boss` a 1920 × 1080 y 1280 × 720 para
revisar escala, pivote, volteo y legibilidad en la arena.

La salida limpia y las pruebas automatizadas no validan por sí solas el ritmo percibido
de la animación. Después de completar las comprobaciones se abrirá el juego para que una
persona pueda jugar el combate y evaluar la sensación final.

## Criterios de aceptación

- El ZIP está presente en la raíz local con su nombre original.
- La Quimera muestra los siete frames de `idle` al buscar esquina y recuperarse.
- La Quimera muestra los dieciséis frames de `angry` durante aviso y embestida.
- `angry` no se reinicia al entrar a `POUNCE`.
- El arte mantiene una escala y un pivote estables y no presenta halos.
- Ninguna constante ni regla de combate cambia.
- Godot importa todos los recursos y el proyecto arranca sin errores ni `Debugger Break`.
- Las pruebas relacionadas terminan con cero fallos.
- La documentación describe la entrega ilustrada como el arte vigente.
