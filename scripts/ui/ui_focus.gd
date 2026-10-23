class_name UiFocus
extends RefCounted


# Keeps keyboard/gamepad traversal inside the visible modal. Left/right stay on
# button-like controls; sliders and option buttons retain their native adjustment.
static func cycle(controls: Array) -> void:
	var active: Array[Control] = []
	for raw: Variant in controls:
		var control := raw as Control
		if control == null or not control.visible:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		if control is Slider and not (control as Slider).editable:
			continue
		active.append(control)
	if active.is_empty():
		return
	for i in active.size():
		var current := active[i]
		var previous := active[(i - 1 + active.size()) % active.size()]
		var next := active[(i + 1) % active.size()]
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(next)
		if not (current is Range) and not (current is OptionButton):
			current.focus_neighbor_left = current.get_path_to(current)
			current.focus_neighbor_right = current.get_path_to(current)
