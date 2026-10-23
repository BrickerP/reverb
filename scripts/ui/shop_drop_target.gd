class_name ShopDropTarget
extends PanelContainer

var target_kind: StringName = &""
var target_index: int = -1
var highlighted: bool = false
var _quote_drop := Callable()
var _apply_drop := Callable()
var _clear_drop := Callable()


func configure(kind: StringName, index: int, quote_drop: Callable, apply_drop: Callable,
		clear_drop: Callable = Callable()) -> void:
	target_kind = kind
	target_index = index
	_quote_drop = quote_drop
	_apply_drop = apply_drop
	_clear_drop = clear_drop
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)


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
	pivot_offset = size * 0.5
	scale = Vector2(0.97, 0.97)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.025, 1.025), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


func reject() -> void:
	UiTheme.flash(self)
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


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
		modulate = Color(0.72, 1.0, 0.94)
	else:
		modulate = Color(1.0, 0.62, 0.68)
