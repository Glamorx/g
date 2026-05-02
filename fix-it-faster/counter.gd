extends Node3D

@export var part_scene: PackedScene = preload("res://engine_part.tscn")

const MIN_SPACING := 4.0
const PLAYER_CLEAR_RADIUS := 5.0
const CAR_CLEAR_RADIUS := 7.0

var engine_parts_needed: int = 4
var engine_parts: int = 0
var car_fixed: bool = false
var can_enter_car: bool = false
var driving_away: bool = false
var _arrow_pivot: Node3D
var _arrow_mesh: MeshInstance3D
var _arrow_target_alpha: float = 0.0

var map_size: Vector2 = Vector2(50, 40)
var current_level: int = 1
var rng: RandomNumberGenerator

@onready var objective: Label = $UI/Objective
@onready var parts_label: Label = $UI/PartsLabel
@onready var hint_label: Label = $UI/Hint
@onready var status_label: Label = $UI/Status
@onready var level_label: Label = $UI/LevelLabel
@onready var ui: CanvasLayer = $UI
@onready var player: CharacterBody3D = $Player
@onready var car: StaticBody3D = $Car
@onready var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
@onready var ground_collision: CollisionShape3D = $Ground/CollisionShape3D
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Pull current level info from GameState autoload (if present).
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState") != null:
		var gs := get_node("/root/GameState")
		current_level = gs.current_level
		map_size = gs.map_size_for_level(current_level)
		engine_parts_needed = gs.parts_needed_for_level(current_level)
		var seed_val: int = gs.get_seed_for_level(current_level)
		rng = RandomNumberGenerator.new()
		rng.seed = seed_val
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	_resize_ground()
	_position_player_and_car()
	_adjust_camera()
	_create_player_arrow()

	# Remove pre-placed parts if any.
	for p in get_tree().get_nodes_in_group("engine_parts"):
		p.queue_free()

	# Pass map info to map builder if it has the API.
	var map := get_node_or_null("Map")
	if map and map.has_method("build_with"):
		map.build_with(map_size, rng)

	await get_tree().process_frame
	_spawn_random_parts()
	update_ui()
	if level_label:
		level_label.text = "Level %d / %d" % [current_level, 10]

func _resize_ground() -> void:
	if ground_mesh and ground_mesh.mesh is PlaneMesh:
		var pm: PlaneMesh = ground_mesh.mesh.duplicate()
		pm.size = map_size
		ground_mesh.mesh = pm
	if ground_collision and ground_collision.shape is BoxShape3D:
		var bs: BoxShape3D = ground_collision.shape.duplicate()
		bs.size = Vector3(map_size.x, 1, map_size.y)
		ground_collision.shape = bs

func _position_player_and_car() -> void:
	# Player spawns near south edge, car at north end where it'll drive off.
	var south_z := map_size.y * 0.5 - 4.0
	var north_z := -map_size.y * 0.5 + 6.0
	if player:
		player.global_position = Vector3(0, 1, south_z)
	if car:
		car.global_position = Vector3(0, 0, north_z)
		car.rotation = Vector3.ZERO

@export var camera_offset: Vector3 = Vector3(0, 14, 11)
@export var camera_follow_speed: float = 6.0

func _adjust_camera() -> void:
	if camera and player:
		camera.global_position = player.global_position + camera_offset
		camera.look_at(player.global_position, Vector3.UP)
		camera.fov = 60.0

func _create_player_arrow() -> void:
	if not player:
		return
	if player.has_node("LocatorArrow"):
		return

	var pivot := Node3D.new()
	pivot.name = "LocatorArrow"
	pivot.position = Vector3(0, 2.6, 0)
	player.add_child(pivot)

	# Bobbing & spinning visual
	var spinner := Node3D.new()
	spinner.name = "Spinner"
	pivot.add_child(spinner)

	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.7, 0.9, 0.25)
	arrow.mesh = mesh
	# Point downward toward the player.
	arrow.rotation = Vector3(PI, 0, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.render_priority = 10
	arrow.material_override = mat
	# Render on top of everything (above default opaque pass).
	arrow.sorting_offset = 100.0
	spinner.add_child(arrow)

	_arrow_pivot = pivot
	_arrow_mesh = arrow
	pivot.visible = false

	# Animate: bob up/down and slow spin.
	var bob := create_tween()
	bob.set_loops()
	bob.set_trans(Tween.TRANS_SINE)
	bob.set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(pivot, "position:y", 3.0, 0.9)
	bob.tween_property(pivot, "position:y", 2.6, 0.9)

	var spin := create_tween()
	spin.set_loops()
	spin.tween_property(spinner, "rotation:y", TAU, 3.0).from(0.0)

func _spawn_random_parts() -> void:
	var min_x := -map_size.x * 0.5 + 3.0
	var max_x := map_size.x * 0.5 - 3.0
	var min_z := -map_size.y * 0.5 + 4.0
	var max_z := map_size.y * 0.5 - 6.0

	var player_pos := player.global_position if player else Vector3.ZERO
	var car_pos := car.global_position + Vector3(3.07, 0, 0) if car else Vector3.ZERO

	var placed: Array[Vector3] = []
	var attempts := 0
	while placed.size() < engine_parts_needed and attempts < 800:
		attempts += 1
		var x := rng.randf_range(min_x, max_x)
		var z := rng.randf_range(min_z, max_z)
		var pos := Vector3(x, 0.6, z)

		if pos.distance_to(player_pos) < PLAYER_CLEAR_RADIUS:
			continue
		if pos.distance_to(car_pos) < CAR_CLEAR_RADIUS:
			continue

		var too_close := false
		for existing in placed:
			if existing.distance_to(pos) < MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue

		placed.append(pos)
		var part: Node3D = part_scene.instantiate()
		add_child(part)
		part.global_position = pos

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_arrow_visibility(delta)
	if not car_fixed or driving_away:
		return
	if can_enter_car and Input.is_action_just_pressed("interact"):
		_drive_away()

func _update_arrow_visibility(delta: float) -> void:
	if not _arrow_pivot or not _arrow_mesh or not player or not camera:
		return

	var space := player.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := player.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)

	var occluded: bool = false
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider != player:
			occluded = true
	_arrow_target_alpha = 1.0 if occluded else 0.0

	var mat := _arrow_mesh.material_override as StandardMaterial3D
	if mat:
		var current := mat.albedo_color.a
		var new_a: float = lerp(current, _arrow_target_alpha, clamp(delta * 8.0, 0.0, 1.0))
		mat.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, new_a)
		_arrow_pivot.visible = new_a > 0.01

func _update_camera(delta: float) -> void:
	if not camera:
		return
	var target_node: Node3D = car if driving_away else player
	if not target_node:
		return
	var target_pos := target_node.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target_pos, clamp(delta * camera_follow_speed, 0.0, 1.0))
	camera.look_at(target_node.global_position, Vector3.UP)

func add_engine_part() -> void:
	if car_fixed:
		return
	engine_parts = min(engine_parts + 1, engine_parts_needed)
	update_ui()
	if engine_parts >= engine_parts_needed:
		show_hint("All parts found. Return to the car to fix it.")
	else:
		show_hint("Part collected. Keep searching the forest.")

func on_player_near_car() -> void:
	if driving_away:
		return
	if car_fixed:
		can_enter_car = true
		show_hint("Press E to enter the car and drive away.")
		return
	if engine_parts >= engine_parts_needed:
		repair_car()
	else:
		var missing := engine_parts_needed - engine_parts
		show_hint("The car still needs %d engine part%s." % [missing, "" if missing == 1 else "s"])

func on_player_left_car() -> void:
	can_enter_car = false
	if not car_fixed:
		show_hint("Search the forest for engine parts.")

func repair_car() -> void:
	car_fixed = true
	can_enter_car = true
	_set_objective("Car fixed!")
	status_label.text = "Press E to drive away."
	show_hint("Repair complete. Press E to enter the car.")
	parts_label.text = "Engine parts: %d/%d" % [engine_parts, engine_parts_needed]

func _drive_away() -> void:
	driving_away = true
	can_enter_car = false
	_set_objective("Driving away...")
	show_hint("")
	status_label.text = ""

	# Hide player (entered the car).
	if player:
		player.visible = false
		player.set_physics_process(false)

	# Animate the car driving north (negative Z) off the map.
	var north_target := Vector3(car.global_position.x, car.global_position.y, -map_size.y * 0.5 - 8.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(car, "global_position", north_target, 4.0)
	tween.tween_callback(_on_drive_complete)

func _on_drive_complete() -> void:
	# Mark level complete and return to menu.
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.complete_level(current_level)
	_set_objective("Level %d complete!" % current_level)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://mainmenu.tscn")

func update_ui() -> void:
	if car_fixed:
		return
	parts_label.text = "Engine parts: %d/%d" % [engine_parts, engine_parts_needed]
	status_label.text = "Search the forest for engine parts, then return to the car."

func _set_objective(text: String) -> void:
	if ui and ui.has_method("show_objective"):
		ui.show_objective(text)
	elif objective:
		objective.text = text

func show_hint(message: String) -> void:
	if hint_label:
		hint_label.text = message
