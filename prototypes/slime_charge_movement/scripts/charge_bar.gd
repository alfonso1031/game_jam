class_name SlimeChargeBar
extends Node2D

const BAR_SIZE := Vector2(136.0, 24.0)
const INNER_MARGIN := 6.0

var charge_power := 0.0


func set_charge(power: float, show_bar: bool) -> void:
	var previous_power := charge_power
	charge_power = clampf(power, 0.0, 1.0)
	visible = show_bar
	queue_redraw()

	if (
		is_inside_tree()
		and charge_power >= 1.0
		and previous_power < 1.0
	):
		_play_full_charge_pulse()


func _draw() -> void:
	var outer_rect := Rect2(-BAR_SIZE * 0.5, BAR_SIZE)
	draw_style_box(_make_box(Color("#10262d"), 12), outer_rect)

	var inner_size := BAR_SIZE - Vector2.ONE * INNER_MARGIN * 2.0
	var inner_rect := Rect2(
		-BAR_SIZE * 0.5 + Vector2.ONE * INNER_MARGIN,
		inner_size
	)
	draw_style_box(_make_box(Color("#203b42"), 7), inner_rect)

	var fill_width := inner_size.x * charge_power
	if fill_width <= 0.0:
		return

	var fill_color := Color("#4de3a2").lerp(Color("#ffe27a"), charge_power)
	var fill_rect := Rect2(inner_rect.position, Vector2(fill_width, inner_size.y))
	draw_style_box(_make_box(fill_color, 7), fill_rect)

	if charge_power >= 1.0:
		draw_arc(
			Vector2.ZERO,
			77.0,
			0.0,
			TAU,
			32,
			Color(1.0, 0.89, 0.48, 0.45),
			3.0
		)


func _play_full_charge_pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _make_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
