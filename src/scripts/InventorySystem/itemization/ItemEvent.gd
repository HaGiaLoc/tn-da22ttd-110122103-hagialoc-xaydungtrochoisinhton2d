class_name ItemEvent
extends Resource


func can_use(_item: Item, _user: Node) -> bool:
	return false

func on_use(_item: Item, _user: Node) -> bool:
	return false

func on_equip(_item: Item, _user: Node) -> bool:
	return false

func on_unequip(_item: Item, _user: Node) -> void:
	pass
