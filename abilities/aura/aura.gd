extends Area2D

signal expired

const DURATION: float = 2.8

var duration_left: float = DURATION

func _ready() -> void:
	refresh_duration()

func _process(delta: float) -> void:
	duration_left -= delta
	if duration_left <= 0.0:
		expired.emit()
		queue_free()

func refresh_duration() -> void:
	duration_left = DURATION
