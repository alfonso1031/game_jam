extends RefCounted

const CabinetScene := preload("res://world/props/containment/cabinet.tscn")
const PipeScene := preload("res://world/props/containment/pipe.tscn")
const GlassTubeScene := preload("res://world/props/containment/glass_tube.tscn")
const BrokenGlassTubeScene := preload("res://world/props/containment/broken_glass_tube.tscn")

const SAFE_CELLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(4, 1), Vector2i(8, 1), Vector2i(11, 1),
	Vector2i(1, 5), Vector2i(4, 5), Vector2i(8, 5), Vector2i(11, 5),
]
const NORMAL_PROPS: Array[Dictionary] = [
	{"id": "cabinet", "scene": CabinetScene},
	{"id": "pipe", "scene": PipeScene},
	{"id": "glass_tube", "scene": GlassTubeScene},
]
const INTERIOR_ORIGIN := Vector2(180, 120)
const CELL := 120.0
const ENTRY_TUBE_POSITION := Vector2(960, 500)


static func placements_for(room_data: Dictionary) -> Array[Dictionary]:
	var role: StringName = room_data.get("role", &"normal")
	if role == &"entry":
		return [{
			"scene": BrokenGlassTubeScene,
			"id": "broken_glass_tube",
			"cell": Vector2i(6, 3),
			"position": ENTRY_TUBE_POSITION,
		}]
	if role != &"normal":
		return []

	var stable_hash: int = _stable_hash(String(room_data.get("id", "")))
	var prop_count: int = stable_hash % 3 + 1
	var placements: Array[Dictionary] = []
	for index: int in range(prop_count):
		var cell_index: int = (stable_hash + index * 3) % SAFE_CELLS.size()
		var prop_index: int = (stable_hash + index) % NORMAL_PROPS.size()
		var cell: Vector2i = SAFE_CELLS[cell_index]
		var prop: Dictionary = NORMAL_PROPS[prop_index]
		placements.append({
			"scene": prop["scene"],
			"id": prop["id"],
			"cell": cell,
			"position": _cell_center(cell),
		})
	return placements


static func _cell_center(cell: Vector2i) -> Vector2:
	return INTERIOR_ORIGIN + Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


static func _stable_hash(value: String) -> int:
	var total := 0
	for index: int in range(value.length()):
		total += value.unicode_at(index) * (index + 1)
	return total
