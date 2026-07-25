extends CharacterBody2D

const SPEED := 160.0

func _physics_process(_delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vec != Vector2.ZERO:
		input_vec = input_vec.normalized()

	# Project screen-space input onto the isometric diamond axes.
	var iso_vec := Vector2(
		input_vec.x - input_vec.y,
		(input_vec.x + input_vec.y) * 0.5
	)
	if iso_vec != Vector2.ZERO:
		iso_vec = iso_vec.normalized()

	velocity = iso_vec * SPEED
	move_and_slide()
