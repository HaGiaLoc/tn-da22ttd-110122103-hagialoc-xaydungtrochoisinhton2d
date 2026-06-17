@tool
class_name BuildIngredient
extends Resource

@export var item_id: String = ""
@export_range(1, 999, 1) var quantity: int = 1
