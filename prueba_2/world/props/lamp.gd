extends Node2D

const BASE_ENERGY := 1.1

@export var dead: bool = false

@onready var light: PointLight2D = $Light
@onready var fixture: ColorRect = $Fixture
@onready var timer: Timer = $Timer

func _ready() -> void:
	if dead:
		light.enabled = false
		fixture.color = Color(0.192157, 0.211765, 0.219608, 1)
		return
	timer.timeout.connect(_on_timeout)
	timer.start(randf_range(0.4, 2.5))

func _on_timeout() -> void:
	# Parpadeo irregular: la mayoría del tiempo estable, bajones ocasionales.
	if randf() < 0.25:
		light.energy = BASE_ENERGY * randf_range(0.15, 0.4)
	else:
		light.energy = BASE_ENERGY * randf_range(0.85, 1.0)
	timer.start(randf_range(0.15, 2.0))
