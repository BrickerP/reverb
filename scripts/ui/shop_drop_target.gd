class_name ShopDropTarget
extends PanelContainer

signal clicked

var target_kind: StringName = &""
var target_index: int = -1
var highlighted: bool = false
var feedback_runs: int = 0
var last_feedback_reverse: bool = false
var _quote_drop := Callable()
var _apply_drop := Callable()
var _clear_drop := Callable()
var _feedback_tween: Tween
var _stamp_visible := false
var _stamp_rejected := false
var _stamp_impact := 0.0:
	set(value):
		_stamp_impact = value
		queue_redraw()


func configure(kind: StringName, index: int, quote_drop: Callable, apply_drop: Callable,
		clear_drop: Callable = Callable()) -> void:
	target_kind = kind
	target_index = index
	_quote_drop = quote_drop
	_apply_drop = apply_drop
	_clear_drop = clear_drop
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			clicked.emit()
			accept_event()


func quote(data: Variant) -> ShopResult:
	if not _quote_drop.is_valid():
		return ShopResult.failure(&"", &"invalid")
	return _quote_drop.call(data, target_kind, target_index) as ShopResult


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var result := quote(data)
	_set_highlight(result != null and result.ok, result != null)
	return result != null and result.ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_highlight(false, false)
	if _apply_drop.is_valid():
		_apply_drop.call(data, target_kind, target_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_highlight(false, false)
		if _clear_drop.is_valid():
			_clear_drop.call()


func settle() -> void:
	feedback(false, false)


func feedback(reverse: bool = false, reduced: bool = false) -> void:
	reset_feedback()
	feedback_runs += 1
	last_feedback_reverse = reverse
	_stamp_visible = true
	_stamp_rejected = false
	_stamp_impact = 0.0 if reduced else 1.0
	if not reduced:
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(self, "_stamp_impact", 0.0, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func reset_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null
	highlighted = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	_stamp_visible = false
	_stamp_impact = 0.0


func reject(reduced: bool = false) -> void:
	reset_feedback()
	_stamp_visible = true
	_stamp_rejected = true
	if reduced:
		queue_redraw()
		return
	_stamp_impact = 1.0
	modulate = Color(1.0, 0.74, 0.63)
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(self, "_stamp_impact", 0.0, 0.2).set_trans(Tween.TRANS_QUAD)
	_feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _draw() -> void:
	if not _stamp_visible:
		return
	var center := Vector2(maxf(16.0, size.x - 15.0), 15.0)
	var radius := 9.0 + _stamp_impact * 3.0
	var ink := UiTheme.WARN if _stamp_rejected else (UiTheme.ECHO if last_feedback_reverse else UiTheme.ACCENT)
	draw_arc(center, radius, -0.2, TAU - 0.5, 20, ink, 2.0, true)
	if _stamp_rejected:
		draw_line(center + Vector2(-3.0, -3.0), center + Vector2(3.0, 3.0), ink, 2.0, true)
		draw_line(center + Vector2(3.0, -3.0), center + Vector2(-3.0, 3.0), ink, 2.0, true)
	elif last_feedback_reverse:
		draw_line(center + Vector2(4.0, 0.0), center + Vector2(-4.0, 0.0), ink, 2.0, true)
		draw_line(center + Vector2(-4.0, 0.0), center + Vector2(0.0, -4.0), ink, 2.0, true)
	else:
		draw_line(center + Vector2(-4.0, 0.0), center + Vector2(-1.0, 3.0), ink, 2.0, true)
		draw_line(center + Vector2(-1.0, 3.0), center + Vector2(5.0, -4.0), ink, 2.0, true)


func clear_highlight() -> void:
	_set_highlight(false, false)


func _on_mouse_exited() -> void:
	if not highlighted:
		return
	_set_highlight(false, false)
	if _clear_drop.is_valid():
		_clear_drop.call()


func _set_highlight(valid: bool, active: bool) -> void:
	highlighted = active
	if not active:
		modulate = Color.WHITE
	elif valid:
		modulate = Color(0.82, 0.94, 0.74)
	else:
		modulate = Color(1.0, 0.74, 0.65)
