# Plan de implementación: consumo de partes desde el mapa

> **Objetivo:** retirar la pantalla de inventario y el estado pendiente, y
> convertir el panel corporal de `TAB` en la única interfaz para seleccionar y
> consumir las seis partes equipadas.

**Arquitectura:** `Inventory` conserva la autoridad interna de los seis slots
porque actores, habilidades y `RunManager` ya dependen de ella. `MapOverlay`
controla apertura y entradas del overlay; `BodyPanel` controla selección
espacial, consumo y presentación. Los pickups permanecen en el mundo cuando no
hay un slot disponible.

**Tecnología:** Godot 4.7.1, GDScript, escenas `.tscn`, pruebas headless.

---

## Tarea 1: fijar el contrato de seis slots sin pendientes

**Archivos:**

- Modificar: `prueba_2/tests/combat_smoke.gd`
- Modificar: `prueba_2/autoload/inventory.gd`

1. Añadir comprobaciones que exijan exactamente seis slots, que `pick_up()`
   devuelva `false` al llenarlos y que no exista la propiedad `pending`.
2. Ejecutar el smoke test y comprobar que falla por el estado pendiente actual:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/combat_smoke.tscn
   ```

3. Eliminar `pending`, `pending_changed`, `place_in_slot()`,
   `consume_pending()` y `_set_pending()`.
4. Hacer que `pick_up()` no altere estado y devuelva `false` si no hay espacio.
5. Quitar el reinicio y la emisión correspondientes al estado pendiente.
6. Repetir el smoke test y confirmar que pasa.

## Tarea 2: mantener pickups llenos en el mundo

**Archivos:**

- Crear: `prueba_2/tests/part_pickup_tests.gd`
- Crear: `prueba_2/tests/part_pickup_tests.tscn`
- Modificar: `prueba_2/world/props/part_pickup.gd`

1. Crear una prueba que llene los seis slots, instancie un pickup y verifique
   que `_collect()` no emite `collected` ni libera el nodo cuando `pick_up()`
   devuelve `false`.
2. Añadir un caso que libere un slot y compruebe que el mismo pickup puede
   recogerse después.
3. Ejecutar la escena y confirmar que el primer caso falla:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/part_pickup_tests.tscn
   ```

4. Cambiar `_collect()` para emitir y destruir el pickup solo si `pick_up()`
   devuelve `true`.
5. Sustituir los textos de pendiente por una indicación breve de liberar una
   parte desde `TAB`.
6. Repetir la prueba hasta obtener `PASS`.

## Tarea 3: selección espacial y consumo en el panel corporal

**Archivos:**

- Modificar: `prueba_2/tests/body_panel_tests.gd`
- Modificar: `prueba_2/ui/body_panel.gd`
- Modificar: `prueba_2/ui/body_panel.tscn`

1. Añadir pruebas para:
   - seleccionar la primera parte ocupada;
   - omitir slots vacíos al navegar;
   - conservar selección si no existe candidato direccional;
   - impedir consumo con vida máxima;
   - consumir el slot seleccionado con vida faltante;
   - trasladar la selección a la parte restante más cercana;
   - limpiar selección cuando no quedan partes;
   - aplicar escala y estilo especial únicamente a la tarjeta seleccionada.
2. Ejecutar la escena y confirmar que falla por los métodos inexistentes:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/body_panel_tests.tscn
   ```

3. Implementar en `BodyPanel`:
   - `selected_slot`;
   - `select_first_equipped()`;
   - `move_selection(direction)`;
   - `consume_selected()`;
   - reconciliación de selección en `_refresh_slots()`;
   - tooltip anclado a la tarjeta seleccionada.
4. Añadir `CardSelected` en la escena y aplicar escala `1.06`, pivote centrado,
   borde luminoso de `5 px` y contraste mayor.
5. Dibujar la conexión seleccionada después de las demás y con trazo más ancho.
6. Mostrar el mensaje contextual de consumo o vida máxima.
7. Repetir la prueba hasta obtener `PASS`.

## Tarea 4: delegar los controles de `TAB` y retirar `I`

**Archivos:**

- Modificar: `prueba_2/tests/map_overlay_tests.gd`
- Modificar: `prueba_2/tests/ui_cleanup_tests.gd`
- Modificar: `prueba_2/ui/map_overlay.gd`
- Modificar: `prueba_2/game/main.tscn`
- Modificar: `prueba_2/project.godot`
- Eliminar: `prueba_2/ui/inventory_ui.gd`
- Eliminar: `prueba_2/ui/inventory_ui.gd.uid`
- Eliminar: `prueba_2/ui/inventory_ui.tscn`

1. Añadir pruebas que abran el overlay, comprueben la selección inicial,
   simulen flechas y `consume`, y verifiquen que la escena principal no contiene
   `InventoryUI`.
2. Añadir una comprobación de que `InputMap` no contiene `inventory`.
3. Ejecutar ambas escenas y confirmar los fallos:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/map_overlay_tests.tscn
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
   ```

4. Hacer que `MapOverlay` entregue las cuatro direcciones y `consume` a su
   `BodyPanel` únicamente mientras está visible.
5. Seleccionar la primera parte al abrir `TAB`.
6. Quitar `InventoryLayer`, el recurso externo y la instancia de
   `InventoryUI` de `main.tscn`.
7. Eliminar la acción `inventory` de `project.godot` y borrar los tres archivos
   de la UI antigua.
8. Repetir las dos pruebas hasta obtener `PASS`.

## Tarea 5: actualizar arquitectura y reglas operativas

**Archivos:**

- Modificar: `docs/ARQUITECTURA.md`
- Modificar: `docs/agents/REFERENCIA.md`
- Modificar: `AGENTS.md`

1. Documentar que `Inventory` es una autoridad interna de seis partes, no una
   reserva visible.
2. Documentar que los pickups permanecen en el suelo cuando no hay espacio.
3. Documentar `TAB` + flechas + `F` como flujo único de consumo.
4. Registrar como regla dura que no se debe reintroducir `pending` ni una
   segunda pantalla de inventario.
5. Buscar referencias obsoletas:

   ```powershell
   rg -n "pending|pendiente|InventoryUI|\\[I\\]|inventario" prueba_2 docs AGENTS.md
   ```

6. Conservar únicamente menciones históricas o internas justificadas.

## Tarea 6: verificación integral

1. Comprobar formato:

   ```powershell
   git diff --check
   ```

2. Ejecutar las pruebas enfocadas:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/body_panel_tests.tscn
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/map_overlay_tests.tscn
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/part_pickup_tests.tscn
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
   ```

3. Ejecutar regresiones obligatorias:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/combat_smoke.tscn
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 --script res://tests/run_map_tests.gd
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
   ```

4. Arrancar el juego durante unos segundos y revisar que no existan errores ni
   `Debugger Break`:

   ```powershell
   & "C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe" --path prueba_2
   ```

5. Probar manualmente a 1920×1080:
   - obtener al menos tres partes;
   - abrir `TAB`;
   - navegar con las flechas;
   - comprobar el resaltado;
   - consumir con `F`;
   - confirmar que `I` no abre nada;
   - llenar los seis slots y verificar que otro pickup queda en el suelo.
