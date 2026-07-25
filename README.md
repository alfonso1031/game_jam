# SLIME ESCAPE

Juego 2D cenital hecho en **Godot 4.7.1** para una game jam. Un slime recién liberado
escapa de un laboratorio abandonado subiendo de nivel en nivel.

El slime todavía no tiene piernas: no camina, **carga un impulso y se lanza**.

## Requisitos

**Godot 4.7.1**, sin dependencias ni plugins. Se descarga de
[godotengine.org](https://godotengine.org/download).

## Cómo jugar

**Desde el editor:** abrir Godot, *Importar* en el gestor de proyectos, elegir la carpeta
`prueba_2/` y darle a *Ejecutar*.

**Desde consola**, en la raíz del repositorio:

```bash
godot --path prueba_2
```

Si el comando `godot` no está en el `PATH`, se invoca con la ruta al ejecutable. En
Windows conviene la variante `_console.exe`, que muestra la salida de depuración.

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
- [docs/CONVENCIONES.md](docs/CONVENCIONES.md) — **las reglas del proyecto**: arquitectura
  por feature, dependencias, nombres, estilo y qué verificar antes de subir
- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) — cómo está construido y por qué
- [docs/PLAN.md](docs/PLAN.md) — diseño del MVP
- [AGENTS.md](AGENTS.md) — instrucciones para agentes de IA que trabajen en el repo

Antes de tocar código, leer [docs/CONVENCIONES.md](docs/CONVENCIONES.md).
