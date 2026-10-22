class_name Check
extends RefCounted

var passed: int = 0
var failed: int = 0
var _ctx: String = ""


func begin(ctx: String) -> void:
	_ctx = ctx


func ok(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		_fail(label, "condition was false")


func eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		_fail(label, "expected %s, got %s" % [expected, actual])


func near(actual: float, expected: float, eps: float, label: String) -> void:
	if absf(actual - expected) <= eps:
		passed += 1
	else:
		_fail(label, "expected %s +/- %s, got %s" % [expected, eps, actual])


func _fail(label: String, detail: String) -> void:
	failed += 1
	printerr("FAIL [%s] %s: %s" % [_ctx, label, detail])
