class_name Offer
extends RefCounted

var weapon: WeaponDef
var item: ItemDef
var price: int = 0
var sold: bool = false


func id() -> StringName:
	return weapon.id if weapon != null else item.id


func is_weapon() -> bool:
	return weapon != null
