extends CanvasLayer

@onready var objective: Label = $Objective

func _ready() -> void:
	$PartsLabel.visible = true
	$Hint.visible = true
	$Status.visible = true
	show_objective(objective.text)

	await get_tree().create_timer(4).timeout
	if is_instance_valid($Hint):
		$Hint.text = "Look for glowing engine parts off the main path."

func show_objective(text: String) -> void:
	if not objective:
		return
	objective.text = text
	objective.visible = true
	objective.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(objective, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.5)
	tween.tween_property(objective, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): objective.visible = false)
