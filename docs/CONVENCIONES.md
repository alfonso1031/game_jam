# Convenciones del proyecto

Reglas que **no** son opcionales. Valen igual para personas y para agentes de IA. Si algo
acá choca con lo que parece más cómodo en el momento, gana esto — y si una regla estorba de
verdad, se cambia el documento primero y el código después.

Documentos relacionados: [ARQUITECTURA.md](ARQUITECTURA.md) explica *cómo está construido*
el juego; [`AGENTS.md`](../AGENTS.md) es el flujo operativo de verificación;
[agents/REFERENCIA.md](agents/REFERENCIA.md) tiene las medidas y recetas concretas.

---

## 1. Arquitectura por feature (obligatoria)

Godot es composición de nodos: no hay ECS ni MVC que seguir. La organización es **por
contexto del juego**, no por tipo de archivo.

> **Un `.tscn` y su `.gd` viven en la misma carpeta y comparten nombre.**
> `door.tscn` ↔ `door.gd`. Nunca en árboles paralelos.

Está **prohibido** volver a una estructura `scenes/` + `scripts/`. Ya existió y se eliminó:
obligaba a saltar entre dos carpetas para tocar una sola cosa, y al mover algo había que
acordarse de mover su gemelo.

| Carpeta | Qué va | Qué **no** va |
|---|---|---|
| `assets/` | Arte, audio, fuentes | Escenas ni scripts |
| `autoload/` | Los singletons registrados en `project.godot` | Cualquier cosa que no necesite sobrevivir al cambio de escena |
| `core/` | Utilidades sin dependencias del juego (`palette`, `layers`) | Referencias a escenas, nodos o autoloads |
| `game/` | El ensamblaje de la partida (`main`) | Lógica de una entidad concreta |
| `actors/` | Lo que se mueve y decide: jugador, bosses, enemigos | Escenografía |
| `world/` | El escenario: `rooms/`, `props/` | Nada que persiga o decida |
| `ui/` | Pantallas y overlays | Reglas del juego |

Para ubicar algo nuevo, en orden:

1. ¿Se mueve y toma decisiones? → `actors/`
2. ¿Es escenario, con o sin colisión? → `world/props/`
3. ¿Es una pantalla o un overlay? → `ui/`
4. ¿Lo usan varios sistemas y no depende de ninguno? → `core/`
5. ¿Tiene que sobrevivir al cambio de escena? → `autoload/`, y pensarlo dos veces

---

## 2. Dirección de las dependencias

Esta es la regla que mantiene el proyecto desarmable. Las flechas van en **un solo
sentido**:

```
        core/  ←──────────────┐
          ↑                   │
     autoload/  ←── ui/       │
          ↑                   │
   actors/ ──→ world/props/ ──┘
```

- `core/` **no importa nada**. Si un archivo de `core/` necesita conocer el juego, no es
  `core/`.
- `autoload/` puede usar `core/`. No conoce escenas concretas: las rutas viven como **datos**
  en `RoomDB`, no cableadas en el código.
- `actors/` y `world/` usan `core/` y los autoloads. **No importan `ui/`.**
- `ui/` lee estado de los autoloads y escucha sus señales. **No toca actores ni salas.**
- `game/` es el **único** lugar donde se ensambla todo (`main.gd` conecta `Transition` con
  los nodos de la escena).

Dos matices que ya existen y son deliberados:

- Un actor **sí** puede instanciar un prop (el boss suelta el pickup del DASH). Al revés no:
  `world/props/` nunca depende de `actors/`.
- Cuando un actor necesita hablarle a un prop, lo hace por **duck typing**, no importando su
  clase: el boss sella las salidas con `if node.has_method("set_sealed")`. Así puertas y
  ascensores responden igual sin que el boss sepa qué son.

---

## 3. Señales hacia arriba, llamadas hacia abajo

Un padre llama métodos de sus hijos. Un hijo avisa con `signal` y **no** conoce a su padre.

Corolario que se aplica en todo el proyecto: **la UI nunca consulta el estado en
`_process()`**. Se suscribe a `room_changed`, `health_changed`, `ability_gained` y se
redibuja cuando pasa algo. Sondear cada frame significa desincronizaciones y trabajo de más.

---

## 4. Datos antes que código

Si algo se va a repetir, va como **dato**, no como caso especial:

- El grafo de salas es un diccionario en `RoomDB`. Añadir una sala es una entrada más, no
  tocar la lógica de transición.
- La decoración se declara por **coordenada de celda** en la raíz del `.tscn` de cada sala.
  Añadir props no toca el árbol de nodos.
- Todo dato que se pueda validar, se valida al arrancar. `RoomDB._validate()` hace
  `push_error` si el grafo es incoherente: los errores de datos aparecen en la salida de
  debug, no jugando.

---

## 5. Constantes, nunca números ni colores sueltos

- **Colores:** siempre desde `core/palette.gd`. Ningún hex hardcodeado en un script.
- **Capas de física:** siempre desde `core/layers.gd`. Nada de
  `set_collision_mask_value(3, false)`; va `Layers.GAP_BIT`. Los nombres legibles están en
  `project.godot` (`[layer_names]`) para que se vean en el inspector.
- **Ajustes de sensación** (velocidades, tiempos, distancias): constantes con nombre arriba
  del archivo, no repartidas por el cuerpo de las funciones.

---

## 6. Estado del jugador

El estado que debe sobrevivir a un cambio de sala vive **solo** en `GameState`: vida, salas
visitadas, habilidades, bosses derrotados. Un script de entidad no guarda copia propia.

Al volver al título o reiniciar hay que llamar a `GameState.reset_run()`. Los autoloads
sobreviven al cambio de escena: si no se limpia, la partida nueva arranca con el progreso
de la anterior.

---

## 7. Nombres

| Cosa | Forma | Ejemplo |
|---|---|---|
| Archivos y carpetas | `snake_case` | `boss_core.gd`, `world/props/` |
| Nodo raíz de una escena | `PascalCase` | `BossCore`, `AbilityPickup` |
| Clases y tipos | `PascalCase` | `Layers`, `Palette` |
| Constantes | `SCREAMING_SNAKE_CASE` | `WALL_RECOVERY_TIME` |
| Miembros y métodos privados | prefijo `_` | `_charge_time`, `_begin_recovery()` |
| Ids de sala | `SCREAMING_SNAKE_CASE`, con prefijo de nivel | `L3_NUCLEO` |
| Direcciones | `N` `S` `E` `O` | `doors = {"E": "L3_PASILLO"}` |

---

## 8. Estilo de GDScript

- Tabs para indentar (estándar de Godot).
- **Tipado estático siempre.** El proyecto trata los warnings como errores: una inferencia
  desde `Variant` (`var x := clamp(...)`) rompe el arranque. Va `var x: float = clamp(...)`.
- Comentarios en **español**, solo donde el "por qué" no se ve en el código.
- Nada de `print()` de depuración en lo que se entrega.
- Sin assets de arte: todo con `Polygon2D`, `ColorRect`, `_draw()` y `GradientTexture2D`.

---

## 9. Rutas

- En **código y escenas**: rutas de recurso (`res://…`).
- En **documentación**: rutas relativas a la raíz del repositorio (`prueba_2/…`).
- **Nunca** rutas absolutas de una máquina concreta. Los comandos de la documentación
  asumen que se ejecutan desde la raíz del repo.
- La ruta del repositorio puede contener espacios: toda ruta absoluta en un comando va
  entre comillas.

---

## 10. Antes de subir

1. **El proyecto arranca limpio.** Ningún cambio se da por bueno sin correrlo y leer la
   salida de debug. Un `Debugger Break` es un fallo aunque el proceso siga vivo.
2. **Lo que el arranque limpio no prueba, se prueba a mano.** Las transiciones entre salas,
   el balance del combate y la sensación del movimiento no aparecen en la salida de debug.
3. **Actualizar la documentación en el mismo commit** que el cambio:

   | Si tocaste… | Actualizá |
   |---|---|
   | Una mecánica o un sistema | [ARQUITECTURA.md](ARQUITECTURA.md) |
   | Medidas, recetas o estilo | [agents/REFERENCIA.md](agents/REFERENCIA.md) |
   | Algo que rompe si se hace mal | las reglas duras de [`AGENTS.md`](../AGENTS.md) |
   | Una regla del proyecto | este archivo |

4. **Decir qué quedó sin verificar.** Es preferible "no probé que la partida se termine" a
   dar por bueno algo que nadie jugó.

---

## 11. Git

- Mensajes de commit en español, en imperativo, con el **por qué** cuando no sea obvio del
  diff. El asunto describe el cambio, no el archivo tocado.
- Mover archivos con `git mv` para conservar el historial.
- **Nunca `push --force`.** Si el remoto tiene trabajo que no está local, se hace `pull`,
  se resuelve, se verifica que arranca limpio y recién ahí se sube.
