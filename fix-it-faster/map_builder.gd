extends Node3D

var _materials: Dictionary = {}
var _rng: RandomNumberGenerator
var _map_size: Vector2 = Vector2(50, 40)

func _ready() -> void:
	_create_materials()
	# If no external build_with call yet, build with defaults after a frame.
	await get_tree().process_frame
	if get_child_count() == 0:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
		_build()

func build_with(map_size: Vector2, rng: RandomNumberGenerator) -> void:
	_map_size = map_size
	_rng = rng
	# Clear any previously generated children.
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	_build()

func _build() -> void:
	_create_path()
	_create_start_marker()
	_create_forest()
	_create_bushes()
	_create_rocks()

func _create_materials() -> void:
	_materials["dirt"] = _material(Color(0.48, 0.32, 0.18))
	_materials["wood"] = _material(Color(0.36, 0.20, 0.10))
	_materials["leaf"] = _material(Color(0.10, 0.42, 0.12))
	_materials["leaf_dark"] = _material(Color(0.06, 0.29, 0.09))
	_materials["bush"] = _material(Color(0.08, 0.36, 0.08))
	_materials["rock"] = _material(Color(0.35, 0.35, 0.35))
	_materials["start"] = _material(Color(0.22, 0.48, 0.92))

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _create_path() -> void:
	# Vertical dirt road through the middle from south to north.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6.0, _map_size.y - 4.0)
	var instance := MeshInstance3D.new()
	instance.name = "MainRoad"
	instance.mesh = mesh
	instance.material_override = _materials["dirt"]
	instance.position = Vector3(0, 0.02, 0)
	add_child(instance)

func _create_start_marker() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.08
	mesh.radial_segments = 32
	var marker := MeshInstance3D.new()
	marker.name = "ArrivalMarker"
	marker.mesh = mesh
	marker.material_override = _materials["start"]
	marker.position = Vector3(0, 0.06, _map_size.y * 0.5 - 4.0)
	add_child(marker)

func _create_forest() -> void:
	var area := _map_size.x * _map_size.y
	var tree_count := int(area / 50.0)
	tree_count = clamp(tree_count, 16, 200)

	var min_x := -_map_size.x * 0.5 + 2.0
	var max_x := _map_size.x * 0.5 - 2.0
	var min_z := -_map_size.y * 0.5 + 2.0
	var max_z := _map_size.y * 0.5 - 2.0

	var placed: Array[Vector3] = []
	var attempts := 0
	while placed.size() < tree_count and attempts < tree_count * 10:
		attempts += 1
		var x := _rng.randf_range(min_x, max_x)
		var z := _rng.randf_range(min_z, max_z)
		# Avoid road corridor
		if abs(x) < 4.0:
			continue
		var pos := Vector3(x, 0, z)
		var ok := true
		for other in placed:
			if other.distance_to(pos) < 3.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(pos)
		_create_tree(pos, 1.0 + _rng.randf() * 0.5)

func _create_tree(position: Vector3, scale_factor: float) -> void:
	var tree := StaticBody3D.new()
	tree.name = "Tree"
	tree.position = position
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 2.5
	trunk_mesh.radial_segments = 8
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = trunk_mesh
	trunk.material_override = _materials["wood"]
	trunk.position.y = 1.25
	tree.add_child(trunk)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.38
	shape.height = 2.4
	collision.shape = shape
	collision.position.y = 1.2
	tree.add_child(collision)

	_create_leaf_cluster(tree, Vector3(0, 2.55, 0), 1.45, _materials["leaf"])
	_create_leaf_cluster(tree, Vector3(0.35, 3.05, -0.1), 1.05, _materials["leaf_dark"])
	_create_leaf_cluster(tree, Vector3(-0.35, 3.0, 0.2), 0.95, _materials["leaf"])

func _create_leaf_cluster(parent: Node3D, position: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.55
	mesh.radial_segments = 12
	mesh.rings = 6
	var leaves := MeshInstance3D.new()
	leaves.name = "Leaves"
	leaves.mesh = mesh
	leaves.material_override = material
	leaves.position = position
	parent.add_child(leaves)

func _create_bushes() -> void:
	var area := _map_size.x * _map_size.y
	var bush_count := int(area / 80.0)
	bush_count = clamp(bush_count, 8, 80)

	for i in bush_count:
		var x := _rng.randf_range(-_map_size.x * 0.5 + 1.5, _map_size.x * 0.5 - 1.5)
		var z := _rng.randf_range(-_map_size.y * 0.5 + 1.5, _map_size.y * 0.5 - 1.5)
		if abs(x) < 4.0:
			continue
		var bush := StaticBody3D.new()
		bush.name = "Bush"
		bush.position = Vector3(x, 0, z)
		add_child(bush)

		var mesh := SphereMesh.new()
		mesh.radius = 0.75 + _rng.randf() * 0.35
		mesh.height = 0.9
		mesh.radial_segments = 10
		mesh.rings = 5
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _materials["bush"]
		instance.position.y = 0.45
		bush.add_child(instance)

		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.55
		collision.shape = shape
		collision.position.y = 0.45
		bush.add_child(collision)

func _create_rocks() -> void:
	var area := _map_size.x * _map_size.y
	var rock_count := int(area / 200.0)
	rock_count = clamp(rock_count, 4, 40)

	for i in rock_count:
		var x := _rng.randf_range(-_map_size.x * 0.5 + 1.5, _map_size.x * 0.5 - 1.5)
		var z := _rng.randf_range(-_map_size.y * 0.5 + 1.5, _map_size.y * 0.5 - 1.5)
		if abs(x) < 4.0:
			continue
		var rock := StaticBody3D.new()
		rock.name = "Rock"
		rock.position = Vector3(x, 0, z)
		rock.rotation.y = _rng.randf() * TAU
		add_child(rock)

		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.1, 0.55, 0.85)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _materials["rock"]
		instance.position.y = 0.28
		rock.add_child(instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.1, 0.55, 0.85)
		collision.shape = shape
		collision.position.y = 0.28
		rock.add_child(collision)
