class_name BuildingInventory
extends Control

const RecipeScript = preload("res://scripts/InventorySystem/building/BuildingRecipe.gd")
const IngredientScript = preload("res://scripts/InventorySystem/building/BuildIngredient.gd")
const BuildingComponentScript = preload("res://scripts/InventorySystem/building/BuildingComponent.gd")
const BuildingPlacerScript = preload("res://scripts/InventorySystem/building/BuildingPlacer.gd")

@export var recipe_list: VBoxContainer  ## Container chứa các recipe row

var _building_component: BuildingComponentScript
var _pending_component: BuildingComponentScript
var _build_buttons: Array[Button] = []


func _ready() -> void:
	if not recipe_list:
		recipe_list = get_node_or_null("MarginContainer/VBoxContainer/RecipeListWrapper/RecipeList")
	if _pending_component:
		_building_component = _pending_component
		_pending_component = null
		_rebuild_list()
	_connect_inventory_signals()


func _connect_inventory_signals() -> void:
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		return
	var player_inv = inventory_system.get_player_inventory()
	if not player_inv:
		return
	if not player_inv.item_added.is_connected(_on_inventory_changed):
		player_inv.item_added.connect(_on_inventory_changed)
	if not player_inv.item_removed.is_connected(_on_inventory_removed):
		player_inv.item_removed.connect(_on_inventory_removed)


func _on_inventory_changed(_item: Item, _slot: int) -> void:
	_refresh_button_states()


func _on_inventory_removed(_slot: int) -> void:
	_refresh_button_states()


func _refresh_button_states() -> void:
	if not _building_component:
		return
	for i in _build_buttons.size():
		var btn := _build_buttons[i]
		if not is_instance_valid(btn):
			continue
		var can: bool = _building_component.can_build(i)
		btn.disabled = not can
		btn.modulate = Color.WHITE if can else Color(0.5, 0.5, 0.5, 1.0)


func set_building_component(component: BuildingComponentScript) -> void:
	if not is_node_ready():
		_pending_component = component
		return
	_building_component = component
	_rebuild_list()


func _rebuild_list() -> void:
	if not recipe_list:
		push_warning("BuildingInventory: `recipe_list` not assigned.")
		return

	for child in recipe_list.get_children():
		child.queue_free()

	_build_buttons.clear()

	if not _building_component:
		push_warning("BuildingInventory: _building_component is null.")
		return

	var inventory_system := get_node_or_null("/root/InventorySystem")

	for i in _building_component.recipes.size():
		var recipe = _building_component.get_recipe(i)
		if not recipe or not recipe.is_valid():
			continue
		var row := _build_default_row(i, recipe, inventory_system)
		recipe_list.add_child(row)

	_connect_inventory_signals()


func _build_default_row(index: int, recipe: Resource, inventory_system) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var typed_recipe := recipe as RecipeScript

	var result_box := _make_icon_with_label(
		typed_recipe.icon,
		typed_recipe.display_name
	)
	row.add_child(result_box)

	var eq_label := Label.new()
	eq_label.text = "="
	eq_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(eq_label)

	var ing_box := HBoxContainer.new()
	ing_box.add_theme_constant_override("separation", 2)
	var first_ing := true
	for res in typed_recipe.ingredients:
		if not res or not (res is IngredientScript):
			continue
		var ing := res as IngredientScript
		if not first_ing:
			var plus := Label.new()
			plus.text = "+"
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ing_box.add_child(plus)
		first_ing = false
		var ing_base = inventory_system.get_item_base(ing.item_id) if inventory_system else null
		var ing_widget := _make_icon_with_qty(
			ing_base.icon if ing_base and ing_base.icon else null,
			ing.quantity,
			ing_base.name if ing_base else ing.item_id
		)
		ing_box.add_child(ing_widget)
	row.add_child(ing_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var build_btn := Button.new()
	build_btn.text = "Xây dựng"
	build_btn.pressed.connect(_on_build_pressed.bind(index))
	var can: bool = _building_component != null and _building_component.can_build(index)
	build_btn.disabled = not can
	build_btn.modulate = Color.WHITE if can else Color(0.5, 0.5, 0.5, 1.0)
	row.add_child(build_btn)
	_build_buttons.append(build_btn)

	return row


func _make_icon_with_label(icon: Texture2D, label_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(32, 32)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = icon
	tex.tooltip_text = label_text
	box.add_child(tex)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	box.add_child(lbl)

	return box


func _make_icon_with_qty(icon: Texture2D, qty: int, item_tooltip: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(32, 32)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = icon
	tex.tooltip_text = item_tooltip
	box.add_child(tex)

	var qty_label := Label.new()
	qty_label.text = "x%d" % qty
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 10)
	box.add_child(qty_label)

	return box


func _on_build_pressed(index: int) -> void:
	if not _building_component:
		return
	if not _building_component.can_build(index):
		print("[BuildingInventory] Không đủ nguyên liệu để xây recipe %d." % index)
		return

	var placer := _get_or_create_placer()
	if placer:
		placer.start_placement(index, _building_component, _get_inventory_ui())
	else:
		push_warning("[BuildingInventory] Không tìm thấy BuildingPlacer.")


func _get_inventory_ui() -> Control:
	var node: Node = self
	while node:
		if node.has_method("open_for_building"):
			return node as Control
		node = node.get_parent()
	return null


func _get_or_create_placer() -> BuildingPlacerScript:
	var existing := get_tree().root.get_node_or_null("BuildingPlacer")
	if existing and existing is BuildingPlacerScript:
		return existing as BuildingPlacerScript
	var placer := BuildingPlacerScript.new()
	placer.name = "BuildingPlacer"
	get_tree().root.add_child(placer)
	return placer
