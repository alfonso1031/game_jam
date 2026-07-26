# Title Intro Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir las dos ilustraciones del título en una introducción A → B omisible y dejar un menú navegable sobre la imagen del slime liberado.

**Architecture:** `title.tscn` conserva la responsabilidad visual y `title.gd` controla una máquina pequeña de introducción. Las imágenes fuente viven en `assets/ui/title/`; los tests observan una API mínima (`skip_intro()` e `intro_finished()`) en vez de depender de tiempos reales.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `TextureRect`, `Tween`, PNG 1920 × 1080 y pruebas headless.

## Global Constraints

- Resolución lógica: 1920 × 1080.
- La secuencia automática es A durante 0,8 s, transición a B durante 0,6 s y aparición del menú durante 0,35 s.
- Una tecla o clic durante la introducción la omite, pero no inicia una partida.
- El título impreso en las ilustraciones no se duplica con un `Label`.
- Todos los PNG referenciados deben quedar rastreados en Git; `.godot/` no forma parte de la entrega.

---

### Task 1: Contrato de la introducción y recursos fuente

**Files:**
- Create: `prueba_2/assets/ui/title/title_contained.png`
- Create: `prueba_2/assets/ui/title/title_escaped.png`
- Create: `prueba_2/tests/title_intro_tests.gd`
- Create: `prueba_2/tests/title_intro_tests.tscn`
- Modify: `prueba_2/tests/ui_cleanup_tests.gd`

**Interfaces:**
- Consumes: las imágenes `Pantalla de inicio_1.png` y `Pantalla de inicio_2.png` del ZIP entregado.
- Produces: recursos `res://assets/ui/title/title_contained.png` y `res://assets/ui/title/title_escaped.png`; contrato esperado `skip_intro() -> void` e `intro_finished() -> bool`.

- [ ] **Step 1: Escribir la prueba que falla**

Crear `title_intro_tests.tscn` con un nodo `Node` que use
`res://tests/title_intro_tests.gd`. La prueba debe cargar la escena y comprobar:

```gdscript
extends Node

var failures: Array[String] = []

func _ready() -> void:
	var title: Control = load("res://ui/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_check(title.has_node("BackgroundContained"), "existe el estado contenido")
	_check(title.has_node("BackgroundEscaped"), "existe el estado liberado")
	_check(title.has_node("Menu/PlayButton"), "existe Jugar")
	_check(title.has_node("Menu/QuitButton"), "existe Salir")
	_check(title.has_method("skip_intro"), "la introducción se puede omitir")
	_check(title.has_method("intro_finished"), "la introducción expone su estado")
	if title.has_method("skip_intro"):
		title.skip_intro()
		await get_tree().process_frame
		_check(title.intro_finished(), "omitir deja el menú preparado")
		_check(title.get_node("Menu").visible, "el menú aparece")
		_check(
			is_equal_approx(title.get_node("BackgroundEscaped").modulate.a, 1.0),
			"la imagen B queda visible"
		)
	title.queue_free()
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: title intro" if failures.is_empty() else "FAIL: title intro")
	get_tree().quit(0 if failures.is_empty() else 1)
```

Actualizar `ui_cleanup_tests.gd` para exigir `Menu/PlayButton` y
`Menu/QuitButton`, y dejar de exigir el nodo obsoleto `TitleLabel`.

- [ ] **Step 2: Ejecutar la prueba y confirmar el fallo**

Run:

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/title_intro_tests.tscn
```

Expected: FAIL porque los fondos, el menú y la API todavía no existen.

- [ ] **Step 3: Extraer y copiar los dos PNG con nombres semánticos**

```powershell
$assetTemp = Join-Path $env:TEMP 'gamejam-title-assets'
New-Item -ItemType Directory -Force -Path $assetTemp | Out-Null
Expand-Archive -LiteralPath 'C:\Users\jcbla\Downloads\Title_Screen-20260726T044454Z-1-001.zip' -DestinationPath $assetTemp -Force
New-Item -ItemType Directory -Force -Path 'prueba_2\assets\ui\title' | Out-Null
Copy-Item -LiteralPath (Join-Path $assetTemp 'Title_Screen\Pantalla de inicio_1.png') -Destination 'prueba_2\assets\ui\title\title_contained.png'
Copy-Item -LiteralPath (Join-Path $assetTemp 'Title_Screen\Pantalla de inicio_2.png') -Destination 'prueba_2\assets\ui\title\title_escaped.png'
```

- [ ] **Step 4: Forzar la importación y validar dimensiones**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
Add-Type -AssemblyName System.Drawing
Get-ChildItem 'prueba_2\assets\ui\title\*.png' | ForEach-Object {
	$image = [System.Drawing.Image]::FromFile($_.FullName)
	if ($image.Width -ne 1920 -or $image.Height -ne 1080) { throw "Dimensión inválida: $($_.Name)" }
	$image.Dispose()
}
```

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/assets/ui/title prueba_2/tests/title_intro_tests.gd prueba_2/tests/title_intro_tests.tscn prueba_2/tests/ui_cleanup_tests.gd
git commit -m "test: define contrato de introduccion ilustrada"
```

### Task 2: Máquina de introducción y menú

**Files:**
- Modify: `prueba_2/ui/title.tscn`
- Modify: `prueba_2/ui/title.gd`
- Test: `prueba_2/tests/title_intro_tests.gd`

**Interfaces:**
- Consumes: `title_contained.png`, `title_escaped.png`.
- Produces: `skip_intro() -> void`, `intro_finished() -> bool`, señales internas de `PlayButton` y `QuitButton`.

- [ ] **Step 1: Construir la jerarquía visual de la escena**

Reemplazar `Background`, `Slime`, `SlimeCore`, `TitleLabel` y `Prompt` por:

```text
Title
├── BackgroundContained (TextureRect)
├── BackgroundEscaped (TextureRect)
├── Flash (ColorRect)
└── Menu (VBoxContainer)
    ├── PlayButton
    └── QuitButton
```

Ambos `TextureRect` usan anclajes completos, `expand_mode = 1`,
`stretch_mode = 6` y `mouse_filter = IGNORE`. `BackgroundEscaped`,
`Flash` y `Menu` comienzan transparentes; `Menu` comienza oculto.

- [ ] **Step 2: Implementar el estado y los tweens**

En `title.gd` declarar:

```gdscript
const HOLD_TIME := 0.8
const CROSSFADE_TIME := 0.6
const MENU_FADE_TIME := 0.35

var _intro_done := false
var _intro_tween: Tween

func intro_finished() -> bool:
	return _intro_done

func skip_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_finish_intro()
```

En `_ready()`, reiniciar la run, conectar los botones y lanzar un tween que:

1. espere `HOLD_TIME`;
2. sacuda `BackgroundContained` con desplazamientos de 8 px;
3. lleve el alpha de `Flash` a 0,75 y de vuelta a 0;
4. cruce los alphas A → B durante `CROSSFADE_TIME`;
5. llame `_finish_intro()`.

`_finish_intro()` debe ser idempotente, mostrar `Menu`, llevarlo a alpha 1 en
`MENU_FADE_TIME` y dar foco a `PlayButton`. `_unhandled_input()` durante la
introducción solo llama `skip_intro()`; una vez terminada, los botones controlan
el cambio a `res://game/main.tscn` y `get_tree().quit()`.

- [ ] **Step 3: Ejecutar las pruebas de título y limpieza**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/title_intro_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
```

Expected: ambas terminan con `PASS`.

- [ ] **Step 4: Commit**

```powershell
git add prueba_2/ui/title.gd prueba_2/ui/title.tscn prueba_2/tests/title_intro_tests.gd prueba_2/tests/ui_cleanup_tests.gd
git commit -m "feat: anima escape en pantalla de inicio"
```

### Task 3: Evidencia visual y documentación

**Files:**
- Modify: `prueba_2/tests/ui_visual_capture.gd`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Consumes: `TitleScene.skip_intro()`.
- Produces: modos de captura `title_intro` y `title_menu`.

- [ ] **Step 1: Separar las capturas de los dos estados**

En `ui_visual_capture.gd`, hacer que `title_intro` instancie la portada sin
omitirla y que `title_menu` llame `skip_intro()` antes de capturar. Mantener
desactivado `_unhandled_input` durante la herramienta.

- [ ] **Step 2: Documentar la nueva escena**

Actualizar arquitectura y referencia con:

- rutas de los dos PNG;
- jerarquía `BackgroundContained` / `BackgroundEscaped` / `Menu`;
- regla de que la primera entrada omite, pero no activa `PlayButton`;
- comandos de captura a 1920 × 1080.

- [ ] **Step 3: Generar y revisar capturas reales**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_intro user://title-intro.png 1920x1080
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_menu user://title-menu.png 1920x1080
```

Abrir ambas imágenes y verificar que no haya bandas, duplicación del título,
botones cortados ni texto explicativo residual.

- [ ] **Step 4: Verificación final del subproyecto**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/title_intro_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --quit-after 3
git ls-files --error-unmatch prueba_2/assets/ui/title/title_contained.png prueba_2/assets/ui/title/title_escaped.png
```

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/tests/ui_visual_capture.gd docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: registra introduccion ilustrada"
```
