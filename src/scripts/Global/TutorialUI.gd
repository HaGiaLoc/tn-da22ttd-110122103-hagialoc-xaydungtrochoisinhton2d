extends CanvasLayer

@onready var objective_label: Label = %ObjectiveLabel
@onready var panel: PanelContainer = $MarginContainer/PanelContainer

func _ready() -> void:
	TutorialManager.objective_updated.connect(_on_objective_updated)
	TutorialManager.objective_completed.connect(_on_objective_completed)
	TutorialManager.tutorial_finished.connect(_on_tutorial_finished)
	
	_on_objective_updated(TutorialManager.get_current_objective_text(), 0.0)

func _on_objective_updated(text: String, _progress: float) -> void:
	if text == "":
		panel.hide()
	else:
		panel.show()
		objective_label.text = text

func _on_objective_completed(_index: int) -> void:
	var tw = create_tween()
	tw.tween_property(panel, "modulate", Color(0.2, 1.0, 0.2), 0.2)
	tw.tween_property(panel, "modulate", Color.WHITE, 0.2)

func _on_tutorial_finished() -> void:
	panel.hide()
