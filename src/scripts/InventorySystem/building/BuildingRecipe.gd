@tool
class_name BuildingRecipe
extends Resource

@export_group("Building")
@export var display_name: String = ""
@export var icon: Texture2D
@export_file("*.tscn") var building_scene: String = ""

@export_group("Material")
@export var ingredients: Array[Resource] = []

func is_valid() -> bool:
	return not display_name.is_empty() and not building_scene.is_empty()
