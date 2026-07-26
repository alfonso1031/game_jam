# Handoff de assets — enemigos de Contención

Estos recursos están preparados para que otra rama o agente implemente las
animaciones sin volver a separar las hojas conceptuales.

El paquete está aislado bajo `alt_enemies/` para no colisionar con los recursos
que ya existen en `origin/main`. La integración remota debe comparar cada PNG
antes de copiarlo a su ruta de runtime.

## Alcance

- Incluye EXP01, EXP02 y EXP03.
- No incluye la Quimera Albina: el jefe conserva el asset realizado manualmente.
- No modifica escenas, scripts, colisiones, estadísticas ni máquinas de estados.
- EXP07 conserva sus assets y animaciones existentes.

Todos los fotogramas finales son PNG RGBA de `160 × 160 px`, están centrados,
tienen esquinas transparentes y miran hacia la derecha.

## EXP01 — Ciempiés de Agujas

Asset alternativo:
`alt_enemies/prueba_2/assets/enemies/exp01_centipede/`

Destino esperado al integrar:
`prueba_2/assets/enemies/exp01_centipede/`

| Archivo | Uso |
|---|---|
| `exp01_approach_00.png` | Primer paso del movimiento ondulado |
| `exp01_approach_01.png` | Segundo paso del movimiento ondulado |
| `exp01_windup_00.png` | Inicio de compresión |
| `exp01_windup_01.png` | Máxima anticipación con espinas levantadas |
| `exp01_charge_00.png` | Embestida recta |
| `exp01_rest_00.png` | Aturdimiento y ventana de castigo |

Secuencias sugeridas:

- `approach`: `approach_00`, `approach_01`;
- `windup`: `windup_00`, `windup_01`;
- `charge`: `charge_00`;
- `rest`: `rest_00`.

## EXP02 — Arácnido Blindado

Asset alternativo:
`alt_enemies/prueba_2/assets/enemies/exp02_spider/`

Destino esperado al integrar:
`prueba_2/assets/enemies/exp02_spider/`

| Archivo | Uso |
|---|---|
| `exp02_reposition_00.png` | Primer apoyo de locomoción |
| `exp02_reposition_01.png` | Segundo apoyo de locomoción |
| `exp02_shoot_windup_00.png` | Preparación del disparo |
| `exp02_shoot_release_00.png` | Liberación del disparo |
| `exp02_slam_windup_00.png` | Preparación del aplastamiento |
| `exp02_slam_impact_00.png` | Impacto contra el suelo |

La telaraña fue retirada de `shoot_release`: el proyectil debe seguir siendo un
nodo independiente creado por la lógica de gameplay.

Secuencias sugeridas:

- `reposition`: `reposition_00`, `reposition_01`;
- `shoot_windup`: `shoot_windup_00`, `shoot_release_00`;
- `slam_windup`: `slam_windup_00`, `slam_impact_00`;
- `recover`: `slam_impact_00`, `reposition_01`.

## EXP03 — Saurio Escamado

Asset alternativo:
`alt_enemies/prueba_2/assets/enemies/exp03_saurian/`

Destino esperado al integrar:
`prueba_2/assets/enemies/exp03_saurian/`

| Archivo | Uso |
|---|---|
| `exp03_walk_00.png` | Primer paso |
| `exp03_walk_01.png` | Segundo paso |
| `exp03_tail_windup_00.png` | Inicio del enrollado de cola |
| `exp03_tail_windup_01.png` | Máxima anticipación |
| `exp03_tail_sweep_00.png` | Barrido de cola |
| `exp03_recover_00.png` | Recuperación |

Secuencias sugeridas:

- `walk`: `walk_00`, `walk_01`;
- `tail_windup`: `tail_windup_00`, `tail_windup_01`, `tail_sweep_00`;
- `recover`: `recover_00`, `walk_00`.

## Fuentes

Cada enemigo tiene su hoja original y una copia procesada con transparencia:

```text
alt_enemies/art_raw/enemigos/containment/exp01_centipede/
alt_enemies/art_raw/enemigos/containment/exp02_spider/
alt_enemies/art_raw/enemigos/containment/exp03_saurian/
```

Las hojas siguen una cuadrícula `3 × 2` en orden de lectura. Los fotogramas
finales son la fuente de verdad para la integración en Godot.
