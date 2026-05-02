extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return

	var game := get_tree().current_scene
	if game != null and game.has_method("on_player_near_car"):
		game.on_player_near_car()

func _on_body_exited(body: Node3D) -> void:
	if body.name != "Player":
		return

	var game := get_tree().current_scene
	if game != null and game.has_method("on_player_left_car"):
		game.on_player_left_car()
