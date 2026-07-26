# Consumo directo y paredes de rejilla Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir comer con `F` una copia del suelo sin alterar la equipada y evitar que una rejilla comparta pared con una entrada añadida durante la generación.

**Architecture:** `Inventory` conserva la autoridad de digestión y expone una operación específica para partes sueltas duplicadas. `PartPickup` controla proximidad, input, mensaje y desaparición. `MapGenerator` registra reconexiones en orden ascendente antes de reservar rejillas y valida la pared elegida.

**Tech Stack:** Godot 4.7.1, GDScript, escenas procedurales dirigidas.

## Global Constraints

- La copia equipada conserva slot, cooldown y usos.
- La copia del suelo cura exactamente `2 HP`.
- Solo un duplicado exacto se puede comer directamente.
- `F` usa la acción existente `consume`.
- El `assert` de `ProceduralRoom` permanece activo.
- No cambian coste ni distribución 40/20/40 de rejillas.
- Por instrucción del usuario no se ejecutan suites automatizadas.
- La entrega termina con el juego abierto para validación manual.

---

### Task 1: Reservar paredes de rejilla después de registrar entradas

**Files:**
- Modify: `prueba_2/core/map_generator.gd`

**Interfaces:**
- Consumes: `_available_grate_directions(data: Dictionary) -> Array[String]`
- Produces: intentos de mapa donde `grate_direction` no aparece en `doors` ni `entrances`

- [ ] **Step 1: Cambiar el orden de las fuentes**

En `_add_grates()`, ordenar por capa ascendente:

```gdscript
sources.sort_custom(
	func(a: String, b: String) -> bool:
		return int(run_map.room(a)["layer"]) < int(run_map.room(b)["layer"])
)
```

Cada destino de una fuente temprana añadirá su `entrance` antes de que una sala
futura seleccione `grate_direction`.

- [ ] **Step 2: Validar la reserva**

En `validate()`, dentro del bloque de una fuente con `grate_target`, añadir:

```gdscript
var grate_direction := String(data.get("grate_direction", ""))
if _opening_directions(data).has(grate_direction):
	errors.append("%s comparte pared entre abertura y rejilla" % room_id)
```

Un intento inconsistente será descartado por `generate()` antes de ensamblarse.

- [ ] **Step 3: Commit**

```powershell
git add -- prueba_2/core/map_generator.gd
git commit -m "fix: reserve grate walls after incoming routes"
```

---

### Task 2: Comer una copia del suelo con `F`

**Files:**
- Modify: `prueba_2/autoload/inventory.gd`
- Modify: `prueba_2/world/props/part_pickup.gd`

**Interfaces:**
- Produces: `Inventory.consume_loose_duplicate(part_id: String) -> bool`
- Consumes: acción `consume`, señal `collected(part_id)`

- [ ] **Step 1: Exponer digestión segura**

Añadir junto a `consume_slot()`:

```gdscript
func consume_loose_duplicate(part_id: String) -> bool:
	if not PartsDB.exists(part_id) or not has_part(part_id):
		return false
	_digest(part_id)
	return true
```

No se llama `_set_slot()`, por lo que la parte equipada queda intacta.

- [ ] **Step 2: Cambiar el mensaje del pickup**

En `_process()`:

```gdscript
if Inventory.has_part(part_id):
	hint.text = "F · COMER"
else:
	hint.text = "CUERPO LLENO · [TAB] COME UNA PARTE"
```

- [ ] **Step 3: Consumir desde el mundo**

Añadir:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if (
		not _player_inside
		or not event.is_action_pressed("consume")
		or not Inventory.consume_loose_duplicate(part_id)
	):
		return
	collected.emit(part_id)
	get_viewport().set_input_as_handled()
	queue_free()
```

La señal conserva la persistencia de la recompensa de sala.

- [ ] **Step 4: Commit**

```powershell
git add -- prueba_2/autoload/inventory.gd prueba_2/world/props/part_pickup.gd
git commit -m "feat: consume loose duplicate parts with f"
```

---

### Task 3: Documentar y abrir la versión jugable

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Documents: consumo directo, duplicado exacto y orden de paredes

- [ ] **Step 1: Actualizar contratos**

Documentar que:

- `F` sobre una copia exacta del suelo la digiere sin retirar la equipada;
- una parte diferente continúa esperando un slot;
- las entradas dirigidas se registran antes de reservar la pared de una rejilla;
- el validador rechaza conflictos de pared.

- [ ] **Step 2: Abrir el juego**

Usar Godot MCP:

```text
run_project(projectPath=<ruta absoluta a prueba_2>)
get_debug_output()
```

Solo se corrigen errores que impidan abrir el juego. No se lanzan suites.

- [ ] **Step 3: Commit**

```powershell
git add -- AGENTS.md docs/agents/REFERENCIA.md
git commit -m "docs: explain loose duplicate consumption"
```
