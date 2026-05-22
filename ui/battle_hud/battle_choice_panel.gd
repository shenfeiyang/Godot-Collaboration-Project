extends Control
class_name BattleChoicePanel

const BATTLE_CHOICE_CARD_SCENE = preload("res://ui/battle_hud/battle_choice_card.tscn")

signal choice_selected(mode: StringName, card_index: int, card_data: Dictionary)
signal closed

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/Content/Header/TitleBlock/TitleLabel
@onready var subtitle_label: Label = $Panel/Margin/Content/Header/TitleBlock/SubtitleLabel
@onready var close_button: Button = $Panel/Margin/Content/Header/CloseButton
@onready var event_panel: PanelContainer = $Panel/Margin/Content/EventPanel
@onready var event_label: Label = $Panel/Margin/Content/EventPanel/EventMargin/EventLabel
@onready var choice_cards_row: HBoxContainer = $Panel/Margin/Content/ChoicesPanel/ChoicesMargin/ChoicesRow
@onready var footer_label: Label = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterLabel

var _mode: StringName = &"normal"
var _allow_close: bool = true
var _choice_cards: Array[BattleChoiceCard] = []
var _selected_index: int = -1

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if close_button != null and not close_button.pressed.is_connected(hide_panel):
		close_button.pressed.connect(hide_panel)
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)

func show_choices(choice_context: Dictionary) -> void:
	_mode = StringName(String(choice_context.get("mode", "normal")))
	_allow_close = bool(choice_context.get("allow_close", true))
	title_label.text = String(choice_context.get("title", "三选一"))
	subtitle_label.text = String(choice_context.get("subtitle", "请选择一个选项。"))
	event_label.text = String(choice_context.get("event_text", ""))
	footer_label.text = String(choice_context.get("footer_hint", "点击一个候选项继续。"))
	event_panel.visible = not event_label.text.is_empty()
	close_button.visible = _allow_close
	_selected_index = -1
	_rebuild_choice_cards(choice_context.get("choices", []))
	visible = true
	move_to_front()

func hide_panel() -> void:
	if not _allow_close:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and _allow_close:
		hide_panel()
		get_viewport().set_input_as_handled()

func _on_overlay_gui_input(event: InputEvent) -> void:
	if not visible or not _allow_close:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()
		accept_event()

func _rebuild_choice_cards(choice_entries: Variant) -> void:
	for child in choice_cards_row.get_children():
		child.queue_free()
	_choice_cards.clear()
	var entries: Array = []
	if choice_entries is Array:
		entries = choice_entries
	for index in range(entries.size()):
		var card_data: Dictionary = entries[index] as Dictionary
		var card := BATTLE_CHOICE_CARD_SCENE.instantiate() as BattleChoiceCard
		if card == null:
			continue
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_cards_row.add_child(card)
		card.bind_card(index, card_data)
		if not card.card_pressed.is_connected(_on_choice_card_pressed):
			card.card_pressed.connect(_on_choice_card_pressed)
		_choice_cards.append(card)

func _on_choice_card_pressed(card_index: int) -> void:
	_selected_index = card_index
	for index in range(_choice_cards.size()):
		_choice_cards[index].set_selected(index == card_index)
	if card_index < 0 or card_index >= _choice_cards.size():
		return
	choice_selected.emit(_mode, card_index, _choice_cards[card_index].get_payload())
