extends CharacterBody3D

@export var speed := 7.0
@export var gravity := 24.0

func _physics_process(delta: float) -> void:

	var direction := Vector3.ZERO

	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		direction.x += 1

	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		direction.x -= 1

	if Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down"):
		direction.z += 1

	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"):
		direction.z -= 1

	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, -0.1)

	if direction != Vector3.ZERO:
		var look_target := global_position + Vector3(direction.x, 0, direction.z)
		look_at(look_target, Vector3.UP)

	move_and_slide()
