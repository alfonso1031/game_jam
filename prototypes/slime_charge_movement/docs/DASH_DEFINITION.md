# Definición aislada del impulso cargado

Este documento define la movilidad del **slime base** desarrollada en
`prototypes/slime_charge_movement/`. Está dirigido al compañero que trabaja en
las escenas y el controlador principal.

> **Estado: integrado.** El impulso cargado ya es el movimiento base de
> `prueba_2/scripts/player/slime.gd`. La integración añadió dos reglas que **no**
> están en este prototipo (ver §5.1). Este proyecto sigue siendo el banco de
> pruebas: se itera acá y después se porta.

## 1. Distinción de nombres

En el repositorio existen dos mecánicas diferentes:

| Mecánica | Ubicación | Propósito |
|---|---|---|
| **Impulso cargado** | `prototypes/slime_charge_movement/` | Movimiento base del slime antes de obtener piernas |
| **DASH de habilidad** | `prueba_2/scripts/player/slime.gd` | Recompensa del boss para cruzar huecos |

Para evitar confusiones:

- En diseño y UI, esta propuesta se llama **impulso cargado**.
- El nombre **DASH** sin calificativo se reserva para la habilidad actual de
  `prueba_2`.
- Ambas mecánicas conviven en `prueba_2`: el impulso cargado es el movimiento
  base y el DASH sigue siendo la recompensa del boss, con sus propias reglas de
  invulnerabilidad y máscara de huecos.

## 2. Fantasía y costo jugable

El slime todavía no tiene piernas. No camina continuamente: acumula energía,
elige una dirección y se lanza. El beneficio es recorrer una distancia grande;
el costo es comprometerse con la trayectoria.

Con piernas humanas, una iteración posterior reemplazará este control por
movimiento continuo y preciso.

## 3. Contrato de control

1. El jugador mantiene `WASD` o las flechas.
2. La carga comienza inmediatamente.
3. La dirección puede corregirse mientras se mantienen las teclas.
4. Una barra sobre el slime representa la potencia acumulada.
5. Al soltar todas las direcciones, se inicia el impulso.
6. Durante el impulso no se puede girar, cancelar ni iniciar otra carga.
7. El impulso termina al consumir su distancia o al chocar con una pared.
8. Después existe una recuperación breve antes de aceptar otra carga.

Si se mantienen dos direcciones opuestas, la dirección resultante es cero: la
carga se pausa y conserva la última dirección válida. Soltar todas las teclas sí
libera el impulso.

## 4. Máquina de estados

```mermaid
stateDiagram-v2
    [*] --> Reposo
    Reposo --> Carga: Presionar dirección
    Carga --> Carga: Mantener o corregir dirección
    Carga --> Impulso: Soltar todas las direcciones
    Impulso --> Recuperación: Distancia consumida
    Impulso --> Recuperación: Colisión
    Recuperación --> Reposo: 0.12 segundos
```

Los identificadores de código están en
`scripts/player.gd`:

```gdscript
enum MovementState {
	IDLE,
	CHARGING,
	LAUNCHING,
	RECOVERING,
}
```

## 5. Definición numérica a 1920 × 1080

La fuente única de estos valores es
`scripts/charge_motion.gd`.

| Constante | Valor | Significado |
|---|---:|---|
| `MAX_CHARGE_TIME` | `1.0 s` | Tiempo requerido para llenar la barra |
| `MINIMUM_DISTANCE` | `112 px` | Distancia de una pulsación corta |
| `MAXIMUM_DISTANCE` | `520 px` | Distancia con carga completa |
| `LAUNCH_SPEED` | `1040 px/s` | Velocidad constante del recorrido |
| `RECOVERY_TIME` | `0.12 s` | Pausa posterior al recorrido |

La potencia se normaliza:

```text
potencia = clamp(tiempo_de_carga / 1.0, 0.0, 1.0)
```

La distancia usa interpolación lineal:

```text
distancia = lerp(112, 520, potencia)
```

La velocidad no cambia con la potencia. Una carga mayor produce un recorrido
más largo:

- Carga mínima: aproximadamente `0.108 s` de recorrido.
- Media carga: `316 px`, aproximadamente `0.304 s`.
- Carga máxima: `520 px`, exactamente `0.5 s`.

La entrada diagonal se normaliza, por lo que no obtiene más velocidad ni
distancia.

## 5.1 Reglas añadidas en la integración a `prueba_2`

El prototipo permite soltar la dirección en cualquier momento y trata todas las
recuperaciones por igual. Al integrarlo se añadieron dos costos que el prototipo
todavía no tiene:

| Constante | Valor | Motivo |
|---|---:|---|
| `MIN_CHARGE_TIME` | `0.18 s` | Soltar antes no lanza nada. Sin esto, machacar teclas de dirección produce lanzamientos mínimos encadenados y equivale a caminar — y caminar es una **habilidad futura** (piernas), no algo que la mecánica base deba permitir. |
| `WALL_RECOVERY_TIME` | `0.45 s` | Chocar contra una pared aturde casi cuatro veces más que terminar el recorrido limpio. Sin esto, estrellarse no tenía costo y lanzarse a ciegas era gratis. |

Soltar antes del mínimo entra en `FIZZLE_RECOVERY_TIME` (`0.28 s`) sin desplazarse.

También cambió el perfil de velocidad. El prototipo usa `LAUNCH_SPEED` constante
(`1040 px/s`); la integración lo reemplazó por una curva con salida acelerada y
frenada exponencial, porque a velocidad fija el arranque y el frenado se sienten
toscos:

```
velocidad = fin + (pico − fin) · restante^ease
          · lerp(0.45, 1.0, smoothstep(arranque))
```

| Constante | Impulso | DASH |
|---|---:|---:|
| Pico | `1500 px/s` | `2000 px/s` |
| Final | `240 px/s` | `300 px/s` |
| `ease` | `0.7` | `0.8` |
| Rampa de salida | `14 %` | `15 %` |

La distancia del impulso **no** cambia: la sigue fijando `_remaining`, la curva
solo reparte el tiempo. En el DASH sí, porque su duración es fija: el alcance
pasa a ser la integral de la curva (`326 px`).

En la UI, la barra de carga dibuja una marca en el umbral mínimo y mantiene el
relleno en color de muro hasta superarlo, para que el costo sea legible.

Estas reglas también aplican al DASH de habilidad al chocar: comparten
`WALL_RECOVERY_TIME`.

## 6. Colisiones

- El jugador es un `CharacterBody2D`.
- La colisión es un círculo fijo de radio `44 px`.
- El avance usa `move_and_collide()`.
- Una pared termina el impulso inmediatamente.
- El aplastamiento y estiramiento ocurren únicamente en el nodo visual.
- Este impulso no concede invulnerabilidad.
- Este impulso no desactiva capas ni permite atravesar huecos.

La última regla es importante: cruzar huecos sigue siendo responsabilidad del
DASH de habilidad existente.

## 7. Barra y respuesta visual

La barra:

- Aparece solamente en `CHARGING`.
- Se llena de izquierda a derecha.
- Cambia de verde a amarillo.
- Pulsa al llegar al máximo.
- Se oculta al liberar el impulso.

El slime:

- Se comprime durante la carga.
- Se desplaza visualmente en sentido contrario a la dirección elegida.
- Se estira durante el recorrido.
- Se aplasta con mayor intensidad al chocar.
- Nunca cambia la forma de colisión.

## 8. Diferencia frente al DASH de `prueba_2`

| Aspecto | Impulso cargado | DASH actual |
|---|---|---|
| Activación | Mantener y soltar dirección | `Shift` o `Espacio` |
| Disponibilidad | Movimiento base | Requiere `GameState.has_ability("dash")` |
| Velocidad | `1040 px/s` | `1200 px/s` |
| Duración | Depende de la carga, `~0.108–0.5 s` | Fija, `0.22 s` |
| Cooldown | No | `0.8 s` más la duración |
| Dirección | Se elige durante la carga | Última dirección `_facing` |
| Control durante el recorrido | Ninguno | Ninguno |
| Invulnerabilidad | No | Sí |
| Cruza huecos | No | Sí, desactiva temporalmente el bit 3 |
| Función narrativa | Cuerpo sin piernas | Habilidad obtenida del boss |

No se debe copiar `_start_dash()` del controlador principal para implementar el
impulso cargado: sus reglas de habilidad, invulnerabilidad y máscara de huecos
son deliberadamente diferentes.

## 9. Archivos que forman el contrato

| Archivo | Responsabilidad |
|---|---|
| `scripts/charge_motion.gd` | Constantes, normalización y distancia |
| `scripts/player.gd` | Estados, entrada, movimiento y colisión |
| `scripts/charge_bar.gd` | Representación de la potencia |
| `scripts/slime_visual.gd` | Deformación sin alterar la física |
| `scenes/player.tscn` | Ensamblaje físico y visual |
| `tests/run_tests.gd` | Contrato automatizado |

Las funciones públicas relevantes son:

```gdscript
begin_charge(direction: Vector2) -> void
update_charge(direction: Vector2, delta: float) -> void
release_charge() -> void
get_charge_power() -> float
```

## 10. Integración futura con piernas

La integración recomendada es mantener dos modos de movilidad:

```gdscript
enum MobilityMode {
	CHARGED_BASE,
	LEGS_CONTINUOUS,
}
```

- `CHARGED_BASE` usa la máquina de estados de este documento.
- `LEGS_CONTINUOUS` usa aceleración, frenado y `move_and_slide()`.
- El DASH ganado en el boss permanece como una habilidad independiente.

Esto conserva tres identidades distintas:

1. Slime sin piernas: impulso cargado y comprometido.
2. Slime con piernas: movimiento continuo.
3. Slime con habilidad DASH: ráfaga especial que cruza huecos.

## 11. Verificación

Desde la raíz del repositorio:

```powershell
godot --headless `
  --path prototypes/slime_charge_movement `
  --script res://tests/run_tests.gd
```

La salida correcta es:

```text
PASS: all slime movement tests
```

Antes de integrar en `prueba_2`, deben conservarse estas condiciones:

- La carga máxima tarda `1.0 s`.
- La media carga recorre `316 px`.
- Las diagonales están normalizadas.
- No existe giro durante `LAUNCHING`.
- Las paredes terminan el recorrido.
- La deformación no modifica la colisión.
- El impulso cargado no concede invulnerabilidad ni atraviesa huecos.
