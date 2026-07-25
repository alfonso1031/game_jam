class_name ChargeMotion
extends RefCounted

# Contrato único del impulso cargado para el prototipo a 1920 x 1080.
const MAX_CHARGE_TIME := 1.0
const MINIMUM_DISTANCE := 112.0
const MAXIMUM_DISTANCE := 520.0
const LAUNCH_SPEED := 1040.0
const RECOVERY_TIME := 0.12


static func normalized_power(charge_time: float, max_charge_time: float) -> float:
	if max_charge_time <= 0.0:
		return 1.0
	return clampf(charge_time / max_charge_time, 0.0, 1.0)


static func launch_distance(
	power: float,
	minimum_distance: float,
	maximum_distance: float
) -> float:
	return lerpf(
		minimum_distance,
		maximum_distance,
		clampf(power, 0.0, 1.0)
	)


static func safe_direction(raw_direction: Vector2) -> Vector2:
	if raw_direction.is_zero_approx():
		return Vector2.ZERO
	return raw_direction.normalized()
