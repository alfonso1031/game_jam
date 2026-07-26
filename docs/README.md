# Documentación

| Documento | Contenido |
|---|---|
| [agents/ESTADO_ACTUAL.md](agents/ESTADO_ACTUAL.md) | **Fuente única para otra IA.** Resume solo las reglas vigentes, diferencia lo implementado de lo pendiente y resuelve contradicciones históricas |
| [CONVENCIONES.md](CONVENCIONES.md) | **Las reglas del proyecto.** Arquitectura por feature, dirección de las dependencias, nombres, estilo y qué verificar antes de subir |
| [ARQUITECTURA.md](ARQUITECTURA.md) | Cómo está construido el juego: sistema de salas, movimiento, HUD, boss, flujo de pantallas, bugs resueltos y estado del plan |
| [agents/REFERENCIA.md](agents/REFERENCIA.md) | Referencia técnica para agentes de IA: medidas de sala, recetas, estilo, formato `.tscn` |
| [PLAN.md](PLAN.md) y [DIRECCION.md](DIRECCION.md) | Documentos históricos o de exploración futura. No contienen el contrato actual |

Fuera de esta carpeta:

- [`AGENTS.md`](../AGENTS.md) — raíz del repositorio por convención de las herramientas de
  IA. Reglas duras y flujo de verificación; es lo primero que debe leer un agente.
- [`prototypes/slime_charge_movement/docs/`](../prototypes/slime_charge_movement/docs/) —
  documentación histórica del prototipo de movimiento. Solo aplica al proyecto activo si
  una regla ya está reflejada en [agents/ESTADO_ACTUAL.md](agents/ESTADO_ACTUAL.md).
- [`superpowers/plans/`](superpowers/plans/) y
  [`superpowers/specs/`](superpowers/specs/) — historial de decisiones e implementación.
  Una especificación solo sigue pendiente si
  [agents/ESTADO_ACTUAL.md](agents/ESTADO_ACTUAL.md) la declara expresamente.
