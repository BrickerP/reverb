class_name Offer
extends RefCounted

var weapon: WeaponDef
var weapon_level: int = 0
var item: ItemDef
var contract: AnomalyContract
var price: int = 0
var sold: bool = false
var locked: bool = false


func id() -> StringName:
	if weapon != null:
		return weapon.id
	if contract != null:
		return contract.id()
	return item.id if item != null else &""


func is_weapon() -> bool:
	return weapon != null


func is_contract() -> bool:
	return contract != null
