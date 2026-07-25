extends Area2D

const SPEED := 250.0
const LIFETIME := 4.0

var direction := Vector2.RIGHT

var _life := LIFETIME

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(1, global_position)
	queue_free()
