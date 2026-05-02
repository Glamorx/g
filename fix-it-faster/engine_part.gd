extends Area3D

@export var rotation_speed := 1.8

func _ready() -> void:
	add_to_group("engine_parts")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

func _on_body_entered(body: Node3D) -> void:

	if body.name != "Player":
		return

	var game := get_tree().current_scene
	if game != null and game.has_method("add_engine_part"):
		game.add_engine_part()

	queue_free()
