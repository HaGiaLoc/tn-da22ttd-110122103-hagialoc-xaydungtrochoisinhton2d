class_name AffixInstance
extends RefCounted

var id: String
var values: Array[Variant]

func _init(_id: String, _values: Array[Variant]):
	id = _id
	values = _values

func serialize() -> Dictionary:
	return {
		"id": id,
		"values": values
	}