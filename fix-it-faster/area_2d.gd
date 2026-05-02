extends Area2D

func _input_event(viewport, event, shape_idx):

	if event is InputEventMouseButton:
		if event.pressed:
			inspect_car()

func inspect_car():

	print("Inspecting car...")

	await get_tree().create_timer(3).timeout

	print("Engine broken")
