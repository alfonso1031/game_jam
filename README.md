# SLIME ESCAPE

Juego 2D cenital hecho en **Godot 4.7.1** para una game jam. Un slime recién liberado
escapa de un laboratorio abandonado subiendo de nivel en nivel.

El slime todavía no tiene piernas: no camina, **carga un impulso y se lanza**.

## Cómo jugar

Desde la raíz del repositorio, con Godot 4.7.1:

```bash
godot --path prueba_2
```

En Windows, si el binario no está en el `PATH`, se invoca con su ruta y conviene usar la
variante `_console.exe` para ver la salida:

```bash
"<ruta-a-godot>/Godot_v4.7.1-stable_win64_console.exe" --path prueba_2
```

| Acción | Control |
|---|---|
| Cargar impulso y lanzarse | mantener `WASD` / flechas y **soltar** |
| Mapa completo | `TAB` |
| Pausa | `Esc` |
| Dash (se desbloquea con el boss) | `Shift` / `Espacio` |
| Pantalla completa | `F11` |

## Estructura del repositorio

| Carpeta | Qué es |
|---|---|
| `prueba_2/` | **El juego.** Proyecto Godot activo |
| `prototypes/slime_charge_movement/` | Banco de pruebas del impulso cargado, con tests propios |
| `docs/` | Documentación del proyecto |
| `prueba/` | Legacy abandonado, se conserva por historial |

## Documentación

- [docs/](docs/) — índice completo
- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) — cómo está construido y por qué
- [docs/PLAN.md](docs/PLAN.md) — diseño del MVP
- [AGENTS.md](AGENTS.md) — instrucciones para agentes de IA que trabajen en el repo
