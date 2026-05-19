extends Control
class_name SkillButtonUI

signal pressed(slot_index: int)

@export var slot_index: int = 0
@export var slot_label: String = ""

@onready var touch_button: Button = $TouchButton
@onready var label_node: Label = $Margin/Label
@onready var cooldown_overlay: CooldownMask = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownLabel

var _cooldown_duration: float = 0.0
var _cooldown_remaining: float = 0.0
var _is_enabled: bool = true

func _ready() -> void:
	if touch_button != null and not touch_button.pressed.is_connected(_on_touch_button_pressed):
		touch_button.pressed.connect(_on_touch_button_pressed)
	label_node.text = slot_label
	if cooldown_overlay != null:
		cooldown_overlay.set_mask_color(Color(0.0, 0.0, 0.0, 0.5))
	_update_cooldown_view()

func set_slot_label(value: String) -> void:
	slot_label = value
	if label_node != null:
		label_node.text = slot_label

func set_enabled_state(value: bool) -> void:
	_is_enabled = value
	if touch_button != null:
		touch_button.visible = value
	modulate = Color(1.0, 1.0, 1.0, 1.0) if value else Color(0.6, 0.6, 0.6, 0.85)

func set_cooldown_state(remaining: float, duration: float) -> void:
	_cooldown_remaining = max(remaining, 0.0)
	_cooldown_duration = max(duration, 0.0)
	_update_cooldown_view()

func _process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = max(_cooldown_remaining - delta, 0.0)
	_update_cooldown_view()

func _can_trigger() -> bool:
	return _is_enabled and _cooldown_remaining <= 0.0

func _on_touch_button_pressed() -> void:
	if not _can_trigger():
		return
	pressed.emit(slot_index)

func _update_cooldown_view() -> void:
	if cooldown_overlay == null or cooldown_label == null:
		return
	if _cooldown_remaining <= 0.0 or _cooldown_duration <= 0.0:
		cooldown_overlay.visible = false
		cooldown_label.visible = false
		cooldown_overlay.set_progress(1.0)
		return
	cooldown_overlay.visible = true
	cooldown_label.visible = true
	cooldown_overlay.set_progress(1.0 - (_cooldown_remaining / _cooldown_duration))
	cooldown_label.text = _format_cooldown_text(_cooldown_remaining)

func _format_cooldown_text(remaining: float) -> String:
	if remaining >= 1.0:
		return str(int(ceil(remaining)))
	return "%.1f" % remaining
