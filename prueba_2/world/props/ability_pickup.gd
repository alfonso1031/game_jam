extends Area2D

@export var ability_id: String = "dash"

var _t := 0.0

@onready var glow: Polygon2D = $Glow
@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	label.text = ability_id.to_upper()

func _process(delta: float) -> void:
	_t += delta
	glow.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.14)
	glow.rotation = _t * 0.6

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	GameState.gain_ability(ability_id)
	queue_free()
