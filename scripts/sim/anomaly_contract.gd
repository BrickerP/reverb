class_name AnomalyContract
extends RefCounted

const SALVAGE := &"salvage"
const AUDIT := &"audit"
const REPAIR := &"repair"
const RESCUE := &"rescue"
const RECRUIT := &"recruit"
const CREDIT := &"credit"
const KINDS: Array[StringName] = [SALVAGE, AUDIT, REPAIR, RESCUE, RECRUIT, CREDIT]

var kind: StringName = SALVAGE
# The purchase price of a one-encounter work order, refunded if exchanged before departure.
var deposit: int = 0
var reward: int = 0
var target: int = 0
var accepted: bool = false


static func create(kind_id: StringName, next_wave: int) -> AnomalyContract:
	if not KINDS.has(kind_id):
		return null
	var order := AnomalyContract.new()
	order.kind = kind_id
	var act := maxi(0, int(float(maxi(1, next_wave) - 1) / 4.0))
	match kind_id:
		SALVAGE:
			order.deposit = 8 + 2 * act
			order.reward = 10 + 2 * act
			order.target = 3
		AUDIT:
			order.deposit = 10 + 2 * act
			order.reward = 12 + 2 * act
			order.target = 2
		REPAIR:
			order.deposit = 12 + 2 * act
			order.reward = 8 + 2 * act
			order.target = 1
		RESCUE:
			order.deposit = 14 + 2 * act
			order.reward = 10 + 2 * act
			order.target = 1
		RECRUIT:
			order.deposit = 18 + 3 * act
			order.reward = 0
			order.target = 1
		CREDIT:
			order.deposit = 0
			order.reward = 0
			order.target = 8
	return order


func id() -> StringName:
	return StringName("order_" + String(kind))


func is_complete(sim: Sim) -> bool:
	return Expedition.order_complete(sim, self)


func to_dict() -> Dictionary:
	return {"kind": String(kind), "deposit": deposit, "reward": reward,
		"target": target, "accepted": accepted}


static func from_dict(data: Dictionary) -> AnomalyContract:
	var order := create(StringName(str(data.get("kind", ""))), 1)
	if order == null:
		return null
	order.deposit = maxi(0, int(data.get("deposit", 0)))
	order.reward = maxi(0, int(data.get("reward", 0)))
	order.target = maxi(0, int(data.get("target", 0)))
	order.accepted = bool(data.get("accepted", false))
	return order
