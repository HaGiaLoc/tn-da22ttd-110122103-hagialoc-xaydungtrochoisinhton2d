class_name CraftingInventory
extends Control

const RecipeScript = preload("res://scripts/InventorySystem/crafting/CraftingRecipe.gd")
const IngredientScript = preload("res://scripts/InventorySystem/crafting/CraftIngredient.gd")

@export var recipe_list: VBoxContainer  ## Container chứa các recipe row
@export var recipe_row_scene: PackedScene  ## Scene cho mỗi dòng recipe

var _crafting_component: CraftingComponent
var _pending_component: CraftingComponent  ## Lưu tạm nếu set trước khi _ready
var _craft_buttons: Array[Button] = []     ## Cache nút craft để update trạng thái nhanh


func _ready() -> void:
	if not recipe_list:
		recipe_list = get_node_or_null("MarginContainer/VBoxContainer/RecipeListWrapper/RecipeList")
	if _pending_component:
		_crafting_component = _pending_component
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
	if not _crafting_component:
		return
	for i in _craft_buttons.size():
		var btn := _craft_buttons[i]
		if not is_instance_valid(btn):
			continue
		var can := _crafting_component.can_craft(i)
		btn.disabled = not can
		btn.modulate = Color.WHITE if can else Color(0.5, 0.5, 0.5, 1.0)


func set_crafting_component(component: CraftingComponent) -> void:
	print("[CraftingInventory] set_crafting_component: %s, recipes=%d" % [str(component), component.recipes.size()])
	if not is_node_ready():
		_pending_component = component
		return
	_crafting_component = component
	_rebuild_list()


func _rebuild_list() -> void:
	if not recipe_list:
		push_warning("CraftingInventory: `recipe_list` not assigned.")
		return

	for child in recipe_list.get_children():
		child.queue_free()

	_craft_buttons.clear()

	if not _crafting_component:
		push_warning("CraftingInventory: _crafting_component is null.")
		return

	var inventory_system := get_node_or_null("/root/InventorySystem")
	print("[CraftingInventory] _rebuild_list: %d recipes" % _crafting_component.recipes.size())

	for i in _crafting_component.recipes.size():
		var recipe = _crafting_component.get_recipe(i)
		print("[CraftingInventory] recipe[%d] = %s, valid=%s" % [i, str(recipe), str(recipe != null and recipe.is_valid())])
		if not recipe or not recipe.is_valid():
			continue

		var row: Control
		if recipe_row_scene:
			row = recipe_row_scene.instantiate()
			recipe_list.add_child(row)
			if row.has_method("setup"):
				row.setup(i, recipe, _crafting_component, inventory_system)
		else:
			row = _build_default_row(i, recipe, inventory_system)
			recipe_list.add_child(row)

	_connect_inventory_signals()


func _build_default_row(index: int, recipe: Resource, inventory_system) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var typed_recipe := recipe as RecipeScript

	var result_base = inventory_system.get_item_base(typed_recipe.result_item_id) if inventory_system else null
	var result_box := _make_icon_with_qty(
		result_base.icon if result_base and result_base.icon else null,
		typed_recipe.result_quantity,
		result_base.name if result_base else typed_recipe.result_item_id
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

	var craft_btn := Button.new()
	craft_btn.text = "Chế tạo"
	craft_btn.pressed.connect(_on_craft_pressed.bind(index))
	var can := _crafting_component != null and _crafting_component.can_craft(index)
	craft_btn.disabled = not can
	craft_btn.modulate = Color.WHITE if can else Color(0.5, 0.5, 0.5, 1.0)
	row.add_child(craft_btn)
	_craft_buttons.append(craft_btn)

	return row


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


func _on_craft_pressed(index: int) -> void:
	if not _crafting_component:
		return

	if not _crafting_component.can_craft(index):
		print("[CraftingInventory] Không đủ nguyên liệu để craft recipe %d." % index)
		return

	var success = _crafting_component.craft(index)
	if success:
		print("[CraftingInventory] Craft thành công recipe %d." % index)
		_rebuild_list()  # Refresh để cập nhật trạng thái nút
	else:
		print("[CraftingInventory] Craft thất bại recipe %d." % index)
