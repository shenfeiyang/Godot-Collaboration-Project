extends Control
class_name BattleSettlementPanel

signal restart_requested

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/Content/Header/TitleLabel
@onready var subtitle_label: Label = $Panel/Margin/Content/Header/SubtitleLabel
@onready var summary_label: Label = $Panel/Margin/Content/Body/SummaryPanel/SummaryMargin/SummaryLabel
@onready var detail_label: Label = $Panel/Margin/Content/Body/DetailPanel/DetailMargin/DetailLabel
@onready var restart_button: Button = $Panel/Margin/Content/Footer/ActionsRow/RestartButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)

func show_settlement(settlement_context: Dictionary) -> void:
	title_label.text = String(settlement_context.get("title", "战斗失败"))
	subtitle_label.text = String(settlement_context.get("subtitle", "你在本轮战斗中倒下了。"))
	summary_label.text = String(settlement_context.get("summary_text", "本次挑战已结束。"))
	detail_label.text = String(settlement_context.get("detail_text", "点击重新开始可立即重开当前战斗场景。"))
	visible = true
	move_to_front()

func hide_panel() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_restart_button_pressed()
		get_viewport().set_input_as_handled()

func _on_overlay_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()
