class_name SlimeAudio
extends Node2D

const CHARGE_LOOP_STREAM: AudioStreamWAV = preload("res://assets/audio/slime/slime_charge_loop.wav")
const CHARGE_FULL_STREAM: AudioStreamWAV = preload("res://assets/audio/slime/slime_charge_full.wav")
const DASH_STREAM: AudioStreamWAV = preload("res://assets/audio/slime/slime_dash.wav")
const FIZZLE_STREAM: AudioStreamWAV = preload("res://assets/audio/slime/slime_fizzle.wav")
const IDLE_STREAM: AudioStreamWAV = preload("res://assets/audio/slime/slime_idle.wav")
const IMPACT_STREAMS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/slime/slime_impact_01.wav"),
	preload("res://assets/audio/slime/slime_impact_02.wav"),
]
const LAUNCH_STREAMS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/slime/slime_launch_01.wav"),
	preload("res://assets/audio/slime/slime_launch_02.wav"),
]
const RECOVER_STREAMS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/slime/slime_recover_01.wav"),
	preload("res://assets/audio/slime/slime_recover_02.wav"),
]

@onready var charge_loop: AudioStreamPlayer2D = get_node("ChargeLoop")
@onready var effect_a: AudioStreamPlayer2D = get_node("EffectA")
@onready var effect_b: AudioStreamPlayer2D = get_node("EffectB")
@onready var idle: AudioStreamPlayer2D = get_node("Idle")

var last_event: StringName = &""
var _full_played := false
var _next_effect_a := true
var _next_launch_index := 0
var _next_impact_index := 0
var _next_recover_index := 0


func _ready() -> void:
	var loop_stream := CHARGE_LOOP_STREAM.duplicate() as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	charge_loop.stream = loop_stream
	idle.stream = IDLE_STREAM


func begin_charge() -> void:
	_full_played = false
	if not charge_loop.playing:
		charge_loop.pitch_scale = 0.85
		charge_loop.volume_db = -20.0
		charge_loop.play()
	last_event = &"charge"


func update_charge(power: float) -> void:
	var clamped_power := clampf(power, 0.0, 1.0)
	charge_loop.pitch_scale = lerpf(0.85, 1.18, clamped_power)
	charge_loop.volume_db = lerpf(-20.0, -8.0, clamped_power)
	if clamped_power >= 1.0:
		charge_full()
	else:
		last_event = &"charge"


func charge_full() -> void:
	if _full_played:
		return

	_full_played = true
	_play_effect(CHARGE_FULL_STREAM)
	last_event = &"charge_full"


func fizzle() -> void:
	stop_charge()
	_play_effect(FIZZLE_STREAM)
	last_event = &"fizzle"


func launch() -> void:
	stop_charge()
	_play_effect(_next_launch_stream(), true)
	last_event = &"launch"


func dash() -> void:
	stop_charge()
	_play_effect(DASH_STREAM)
	last_event = &"dash"


func impact() -> void:
	_play_effect(_next_impact_stream(), true)
	last_event = &"impact"


func recover() -> void:
	_play_effect(_next_recover_stream(), true)
	last_event = &"recover"


func stop_charge() -> void:
	charge_loop.stop()
	last_event = &"stop_charge"


func is_charge_playing() -> bool:
	return charge_loop.playing


func get_charge_pitch() -> float:
	return charge_loop.pitch_scale


func _play_effect(stream: AudioStream, vary_pitch := false) -> void:
	var effect_player := _next_effect_player()
	effect_player.stream = stream
	effect_player.pitch_scale = randf_range(0.96, 1.04) if vary_pitch else 1.0
	effect_player.play()


func _next_effect_player() -> AudioStreamPlayer2D:
	var effect_player := effect_a if _next_effect_a else effect_b
	_next_effect_a = not _next_effect_a
	return effect_player


func _next_launch_stream() -> AudioStreamWAV:
	var stream := LAUNCH_STREAMS[_next_launch_index]
	_next_launch_index = (_next_launch_index + 1) % LAUNCH_STREAMS.size()
	return stream


func _next_impact_stream() -> AudioStreamWAV:
	var stream := IMPACT_STREAMS[_next_impact_index]
	_next_impact_index = (_next_impact_index + 1) % IMPACT_STREAMS.size()
	return stream


func _next_recover_stream() -> AudioStreamWAV:
	var stream := RECOVER_STREAMS[_next_recover_index]
	_next_recover_index = (_next_recover_index + 1) % RECOVER_STREAMS.size()
	return stream
