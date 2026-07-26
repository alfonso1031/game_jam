extends SceneTree

const PartsDB := preload("res://core/parts_db.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		PartsDB.description("serrated_jaw") == "Mordisco a corta distancia.",
		"Mandíbula Serrada expone su descripción breve"
	)
	_check(
		PartsDB.description("mycelium_hand")
		== "Dispara una línea de raíz que inmoviliza al primer enemigo tocado.",
		"Mano de Micelio expone su descripción breve"
	)
	_check(
		PartsDB.description("crusher_claw") == "Ataque cónico frontal.",
		"Tenaza Trituradora expone su descripción breve"
	)
	_check(
		PartsDB.display_name("scaled_skin") == "Pierna Escamada",
		"la parte escamada se llama pierna, coherente con su tipo"
	)
	_check(
		PartsDB.description("scaled_skin")
		== "Levanta una costra de escamas que bloquea el siguiente impacto recibido.",
		"Pierna Escamada expone su descripción breve"
	)
	_check(PartsDB.is_active("scaled_skin"), "Pierna Escamada se activa con su tecla")
	_check(
		PartsDB.description("whip_tail")
		== "Barrido giratorio de 360 grados que repele a los enemigos alrededor.",
		"Cola de Látigo expone su descripción breve"
	)
	_check(PartsDB.description("unknown_part").is_empty(), "una parte desconocida no inventa texto")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: UI part descriptions")
		quit(0)
		return
	print("FAIL: UI part descriptions (%d)" % _failures.size())
	quit(1)
