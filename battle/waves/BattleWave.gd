class_name BattleWave extends Node

signal finished

var battle: Battle
var duration: float = 6.0
var elapsed: float = 0.0


func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed = minf(duration, elapsed + delta)
	advance_wave(previous, elapsed)
	if elapsed >= duration:
		set_physics_process(false)
		finished.emit()


# Override this to schedule bullets using seconds, not frame counts.
func advance_wave(_previous: float, _now: float) -> void:
	pass
