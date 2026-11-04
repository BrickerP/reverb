class_name MomentInk
extends RefCounted

# One local paper impression owns the accent. Repeated hits cannot turn it
# into a permanent halo or erase the warning beneath the next attack.
var _mark: Dictionary = {}
var _left := 0.0
var _cooldown := 0.0


func clear() -> void:
	_mark.clear()
	_left = 0.0
	_cooldown = 0.0


func step(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	_left = maxf(0.0, _left - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if _left <= 0.0:
		_mark.clear()


func offer(kind: StringName, pos: Vector2, tint: Color = Color("dcccaa"), familiar: bool = false) -> bool:
	var profile := _profile(kind)
	if profile.is_empty() or not pos.is_finite():
		return false
	if _cooldown > 0.0 and int(profile["priority"]) <= int(_mark.get("priority", 0)):
		return false
	if familiar:
		profile = profile.duplicate()
		profile["duration"] = minf(0.30, float(profile["duration"]))
		profile["hold"] = 0.06
	_mark = {"kind": kind, "pos": pos, "tint": tint,
		"priority": profile["priority"], "duration": profile["duration"], "radius": profile["radius"],
		"hold": profile["hold"], "familiar": familiar}
	_left = float(profile["duration"])
	_cooldown = _left
	return true


func snapshot() -> Dictionary:
	if _mark.is_empty():
		return {}
	var out := _mark.duplicate(true)
	out["progress"] = 1.0 - _left / float(_mark["duration"])
	return out


func active() -> bool:
	return not _mark.is_empty()


static func _profile(kind: StringName) -> Dictionary:
	match kind:
		&"ready": return {"priority": 1, "duration": 0.60, "hold": 0.20, "radius": 27.0}
		&"repair", &"rescue": return {"priority": 2, "duration": 0.55, "hold": 0.18, "radius": 32.0}
		&"combo": return {"priority": 3, "duration": 0.50, "hold": 0.15, "radius": 31.0}
		&"skill", &"block": return {"priority": 4, "duration": 0.42, "hold": 0.12, "radius": 34.0}
		&"retire", &"hurt": return {"priority": 5, "duration": 0.36, "hold": 0.08, "radius": 36.0}
		&"boss": return {"priority": 6, "duration": 0.48, "hold": 0.12, "radius": 56.0}
	return {}


static func draw(ci: CanvasItem, data: Dictionary, clip: Rect2, reduced: bool) -> void:
	if ci == null or data.is_empty():
		return
	var pos: Vector2 = data["pos"]
	var progress := clampf(float(data["progress"]), 0.0, 1.0)
	var radius := float(data["radius"])
	if not clip.intersects(Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		return
	var opening := 1.0 if reduced else lerpf(0.76, 1.10, minf(1.0, progress * 4.0))
	var elapsed := progress * float(data["duration"])
	var fade := clampf((elapsed - float(data.get("hold", 0.0))) / maxf(0.001, float(data["duration"]) - float(data.get("hold", 0.0))), 0.0, 1.0)
	var alpha := (1.0 - fade) * (0.7 if reduced else 0.9)
	var ink := Color(ArenaPainter.INK, alpha)
	var paper := Color(data["tint"], alpha)
	var count := 3 if reduced else 4
	for index in count:
		var direction := Vector2.from_angle(TAU * float(index) / float(count) + 0.18)
		var side := direction.orthogonal()
		var center := pos + direction * radius * opening
		# Unequal folded tabs echo the paper bodies, without a screen flash.
		var a := (center - side * 7.0 - direction * 2.0).clamp(clip.position, clip.end)
		var b := (center + side * 3.0 + direction * 3.0).clamp(clip.position, clip.end)
		var c := (center + side * 8.0 - direction * 4.0).clamp(clip.position, clip.end)
		ci.draw_line(a, b, paper, 5.0, true)
		ci.draw_line(b, c, paper, 5.0, true)
		ci.draw_line(a, b, ink, 1.6, true)
		ci.draw_line(b, c, ink, 1.6, true)
