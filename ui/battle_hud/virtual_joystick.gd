extends Control
class_name VirtualJoystick

signal input_changed(input_vector: Vector2)

@export var max_radius: float = 56.0
@export var dead_zone_radius: float = 8.0
@export var knob_visual_radius: float = 22.0

@onready var base_ring: TextureRect = $BaseRing
@onready var knob: TextureRect = $Knob
@onready var touch_area: Control = $TouchArea

var _active_pointer_id: int = -1
var _current_input: Vector2 = Vector2.ZERO
var _center_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if touch_area != null and not touch_area.gui_input.is_connected(_on_touch_area_gui_input):
		touch_area.gui_input.connect(_on_touch_area_gui_input)
	_update_center_position()
	_reset_knob_position()

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	_update_center_position()
	if _active_pointer_id == -1:
		_reset_knob_position()

func get_input_vector() -> Vector2:
	return _current_input

func is_pointer_active() -> bool:
	return _active_pointer_id != -1

func set_visual_input(input_vector: Vector2) -> void:
	var visual_input: Vector2 = input_vector.limit_length(1.0)
	if visual_input == Vector2.ZERO:
		_reset_knob_position()
		return
	var knob_visual_offset: Vector2 = visual_input * knob_visual_radius
	knob.position = _center_position + knob_visual_offset - (knob.size * 0.5)

func _gui_input(event: InputEvent) -> void:
	_handle_gui_event(event)

func _on_touch_area_gui_input(event: InputEvent) -> void:
	_handle_gui_event(event)

func _handle_gui_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_pointer_id != -1:
			return
		_active_pointer_id = event.index
		_update_input_from_local_position(event.position - global_position)
		return
	if event.index != _active_pointer_id:
		return
	_release_input()

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_pointer_id:
		return
	_update_input_from_local_position(event.position - global_position)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _active_pointer_id != -1:
			return
		_active_pointer_id = -2
		_update_input_from_local_position(event.position)
		return
	if _active_pointer_id != -2:
		return
	_release_input()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _active_pointer_id != -2:
		return
	_update_input_from_local_position(event.position)

func _update_input_from_local_position(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - _center_position
	var distance: float = offset.length()
	if distance <= dead_zone_radius:
		_current_input = Vector2.ZERO
		_reset_knob_position()
		input_changed.emit(_current_input)
		return
	var clamped_offset: Vector2 = offset.limit_length(max_radius)
	_current_input = clamped_offset / max_radius
	var knob_visual_offset: Vector2 = _current_input * knob_visual_radius
	knob.position = _center_position + knob_visual_offset - (knob.size * 0.5)
	input_changed.emit(_current_input)

func _release_input() -> void:
	_active_pointer_id = -1
	_current_input = Vector2.ZERO
	_reset_knob_position()
	input_changed.emit(_current_input)

func _reset_knob_position() -> void:
	if knob == null:
		return
	knob.position = _center_position - (knob.size * 0.5)

func _update_center_position() -> void:
	_center_position = size * 0.5
