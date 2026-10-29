class_name ShopResult
extends RefCounted

const BUY := &"buy"
const REPLACE := &"replace"
const UPGRADE := &"upgrade"
const EVOLVE := &"evolve"
const SELL := &"sell"
const ECHO_DISCARD := &"echo_discard"
const ECHO_MERGE := &"echo_merge"
const ECHO_REPAIR := &"echo_repair"
const REROLL := &"reroll"
const UNDO := &"undo"

var action: StringName
var ok: bool = false
var reason: StringName = &""
var cost: int = 0
var index: int = -1
var offer_id: StringName = &""
var before_state: ShopState
var after_state: ShopState


static func success(action_value: StringName, cost_value: int, index_value: int = -1,
		offer_id_value: StringName = &"", before: ShopState = null, after: ShopState = null) -> ShopResult:
	var result := ShopResult.new()
	result.action = action_value
	result.ok = true
	result.cost = cost_value
	result.index = index_value
	result.offer_id = offer_id_value
	result.before_state = before
	result.after_state = after
	return result


static func failure(action_value: StringName, reason_value: StringName, cost_value: int = 0,
		index_value: int = -1, offer_id_value: StringName = &"") -> ShopResult:
	var result := ShopResult.new()
	result.action = action_value
	result.reason = reason_value
	result.cost = cost_value
	result.index = index_value
	result.offer_id = offer_id_value
	return result


func to_dict() -> Dictionary:
	return {
		"action": String(action),
		"ok": ok,
		"reason": String(reason),
		"cost": cost,
		"index": index,
		"offer_id": String(offer_id),
		"before": before_state.to_dict() if before_state != null else null,
		"after": after_state.to_dict() if after_state != null else null,
	}
