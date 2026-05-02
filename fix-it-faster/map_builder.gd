extends Node3D

# Procedural biome-aware map generator.
# Variety: 4 tree species (oak, pine, birch, willow), grown from saplings to mature trees,
# multiple rock sizes/shapes with clustering, varied bushes, and grass tufts with biome-driven density.

var _rng: RandomNumberGenerator
var _map_size: Vector2 = Vector2(50, 40)

# Biome noise: moisture & temperature drive what spawns where.
var _moisture: FastNoiseLite
var _temperature: FastNoiseLite
var _density: FastNoiseLite

# Cached materials
var _mats: Dictionary = {}

const ROAD_HALF_WIDTH := 4.0

func _ready() -> void:
	_init_materials()
	# Don't auto-build. counter.gd will call build_with() with the level's seed.

func build_with(map_size: Vector2, rng: RandomNumberGenerator) -> void:
	_map_size = map_size
	_rng = rng
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	_init_noise()
	_build()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _init_noise() -> void:
	_moisture = FastNoiseLite.new()
	_moisture.seed = _rng.randi()
	_moisture.frequency = 0.09
	_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	_temperature = FastNoiseLite.new()
	_temperature.seed = _rng.randi()
	_temperature.frequency = 0.07
	_temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	_density = FastNoiseLite.new()
	_density.seed = _rng.randi()
	_density.frequency = 0.18
	_density.noise_type = FastNoiseLite.TYPE_PERLIN

func _init_materials() -> void:
	# Trunks
	_mats["bark_oak"] = _mat(Color(0.36, 0.22, 0.12), 0.95)
	_mats["bark_pine"] = _mat(Color(0.28, 0.16, 0.09), 0.95)
	_mats["bark_birch"] = _mat(Color(0.92, 0.92, 0.88), 0.85)
	_mats["bark_birch_marks"] = _mat(Color(0.15, 0.15, 0.15), 0.8)
	_mats["bark_willow"] = _mat(Color(0.42, 0.30, 0.18), 0.9)

	# Foliage palettes
	_mats["leaf_oak"] = _mat(Color(0.22, 0.50, 0.18), 0.9)
	_mats["leaf_oak_dark"] = _mat(Color(0.14, 0.36, 0.12), 0.9)
	_mats["leaf_pine"] = _mat(Color(0.10, 0.32, 0.18), 0.95)
	_mats["leaf_pine_dark"] = _mat(Color(0.06, 0.22, 0.12), 0.95)
	_mats["leaf_birch"] = _mat(Color(0.55, 0.75, 0.30), 0.85)
	_mats["leaf_birch_autumn"] = _mat(Color(0.85, 0.65, 0.20), 0.85)
	_mats["leaf_willow"] = _mat(Color(0.45, 0.60, 0.25), 0.9)

	# Rocks (range of greys/browns)
	_mats["rock_grey"] = _mat(Color(0.45, 0.45, 0.47), 0.95)
	_mats["rock_dark"] = _mat(Color(0.28, 0.28, 0.30), 0.95)
	_mats["rock_warm"] = _mat(Color(0.55, 0.45, 0.35), 0.95)
	_mats["rock_moss"] = _mat(Color(0.30, 0.42, 0.22), 0.9)

	# Bushes
	_mats["bush_green"] = _mat(Color(0.16, 0.42, 0.16), 0.9)
	_mats["bush_dark"] = _mat(Color(0.10, 0.30, 0.12), 0.9)
	_mats["bush_dry"] = _mat(Color(0.55, 0.50, 0.20), 0.9)
	_mats["bush_berry"] = _mat(Color(0.20, 0.40, 0.18), 0.9)
	_mats["berry"] = _mat(Color(0.75, 0.10, 0.15), 0.6)

	# Grass
	_mats["grass_lush"] = _mat(Color(0.20, 0.55, 0.18), 0.95)
	_mats["grass_normal"] = _mat(Color(0.30, 0.55, 0.20), 0.95)
	_mats["grass_dry"] = _mat(Color(0.65, 0.60, 0.25), 0.95)
	_mats["grass_tundra"] = _mat(Color(0.50, 0.55, 0.40), 0.95)

	# Cliffs (mountains)
	_mats["cliff_rock"] = _mat(Color(0.42, 0.38, 0.34), 0.95)
	_mats["cliff_dark"] = _mat(Color(0.28, 0.26, 0.24), 0.95)
	_mats["cliff_plateau"] = _mat(Color(0.22, 0.50, 0.20), 0.95)

	# Path
	_mats["dirt"] = _mat(Color(0.48, 0.32, 0.18), 0.95)
	_mats["start"] = _mat(Color(0.22, 0.48, 0.92), 0.7)

func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	_create_path()
	_create_start_marker()
	_create_boundary_walls()
	_scatter_vegetation()
	_scatter_rocks()
	_scatter_grass()

func _create_boundary_walls() -> void:
	var walls := StaticBody3D.new()
	walls.name = "BoundaryWalls"
	add_child(walls)

	var half_x := _map_size.x * 0.5
	var half_z := _map_size.y * 0.5
	var wall_h := 8.0
	var wall_t := 2.0

	# Solid invisible walls covering the entire north and south edges.
	# (The car drive-away animation uses a position tween, so it passes through.)
	# South wall (positive Z)
	_add_wall(walls, Vector3(0, wall_h * 0.5, half_z + wall_t * 0.5),
		Vector3(_map_size.x + wall_t * 2, wall_h, wall_t))
	# North wall (negative Z)
	_add_wall(walls, Vector3(0, wall_h * 0.5, -half_z - wall_t * 0.5),
		Vector3(_map_size.x + wall_t * 2, wall_h, wall_t))

	# East and West mountain walls (visible cliff barriers).
	_create_mountain_wall(-half_x, -1.0)  # west, faces east (+1)
	_create_mountain_wall(half_x, 1.0)    # east, faces west (-1)

func _create_mountain_wall(x_edge: float, outward: float) -> void:
	# A mountain runs along the full Z axis at x = x_edge.
	# It consists of stacked irregular rock segments, a plateau on top, and grass.
	var mountain := StaticBody3D.new()
	mountain.name = "Mountain"
	add_child(mountain)

	var z_min := -_map_size.y * 0.5
	var z_max := _map_size.y * 0.5
	var segment_length := 4.0
	var base_width := 6.0
	var top_width := 4.5
	var height := 14.0

	# Build segments along Z.
	var z := z_min
	while z < z_max:
		var seg_z := z + segment_length * 0.5
		# Slight irregularity to avoid perfectly straight cliff.
		var jitter_h := _rng.randf_range(-1.5, 1.5)
		var jitter_w := _rng.randf_range(-0.6, 0.6)
		var seg_h := height + jitter_h
		var seg_w := base_width + jitter_w

		# Position the cliff so its inner face sits at x_edge (mountain extends outward).
		# outward = +1 means mountain extends to +X (east edge: outward = -1 toward outside).
		# We want the inner face (toward map center) at x_edge.
		var center_x: float = x_edge + (seg_w * 0.5) * (-outward) * -1.0
		# Simplify: mountain extends OUTWARD beyond x_edge. So center is x_edge offset by outward*seg_w/2.
		center_x = x_edge - outward * (seg_w * 0.5)

		# Lower rocky base
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(seg_w, seg_h, segment_length + 0.2)
		var base := MeshInstance3D.new()
		base.mesh = base_mesh
		base.material_override = _mats["cliff_rock"]
		base.position = Vector3(center_x, seg_h * 0.5, seg_z)
		# Slight tilt for irregular silhouette.
		base.rotation = Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.04))
		mountain.add_child(base)

		# Darker rock outcrop on the inner cliff face for visual depth.
		if _rng.randf() < 0.5:
			var outcrop_mesh := BoxMesh.new()
			var ow: float = _rng.randf_range(1.0, 2.2)
			var oh: float = _rng.randf_range(2.0, 5.0)
			outcrop_mesh.size = Vector3(ow, oh, segment_length * _rng.randf_range(0.5, 0.9))
			var outcrop := MeshInstance3D.new()
			outcrop.mesh = outcrop_mesh
			outcrop.material_override = _mats["cliff_dark"]
			# Place against the inner face.
			var inner_face_x: float = x_edge + outward * (ow * 0.4)
			outcrop.position = Vector3(inner_face_x, _rng.randf_range(2.0, seg_h - oh * 0.5), seg_z + _rng.randf_range(-1.0, 1.0))
			outcrop.rotation.y = _rng.randf_range(-0.2, 0.2)
			mountain.add_child(outcrop)

		# Grassy plateau cap on top.
		var plateau_mesh := BoxMesh.new()
		plateau_mesh.size = Vector3(top_width, 0.6, segment_length + 0.2)
		var plateau := MeshInstance3D.new()
		plateau.mesh = plateau_mesh
		plateau.material_override = _mats["cliff_plateau"]
		plateau.position = Vector3(center_x + outward * 0.4, seg_h + 0.3, seg_z)
		mountain.add_child(plateau)

		# Collision: a single tall vertical wall at the inner face — guarantees no climbing.
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(seg_w, seg_h + 4.0, segment_length + 0.2)
		col.shape = shape
		col.position = Vector3(center_x, (seg_h + 4.0) * 0.5, seg_z)
		mountain.add_child(col)

		# Occasional bushes/small rocks on top of the plateau for life.
		if _rng.randf() < 0.4:
			_plateau_decoration(mountain, Vector3(center_x + outward * _rng.randf_range(-1.2, 1.2),
				seg_h + 0.6, seg_z + _rng.randf_range(-1.0, 1.0)))

		z += segment_length

func _plateau_decoration(parent: Node3D, pos: Vector3) -> void:
	var deco := MeshInstance3D.new()
	if _rng.randf() < 0.6:
		# Small bush
		var sm := SphereMesh.new()
		var r: float = _rng.randf_range(0.4, 0.7)
		sm.radius = r
		sm.height = r * 1.7
		sm.radial_segments = 8
		sm.rings = 4
		deco.mesh = sm
		deco.material_override = _mats["bush_dark"]
		deco.position = pos + Vector3(0, r * 0.6, 0)
	else:
		# Small rock
		var bm := BoxMesh.new()
		var s: float = _rng.randf_range(0.4, 0.9)
		bm.size = Vector3(s, s * 0.6, s)
		deco.mesh = bm
		deco.material_override = _mats["rock_grey"]
		deco.position = pos + Vector3(0, s * 0.3, 0)
		deco.rotation.y = _rng.randf() * TAU
	parent.add_child(deco)

func _add_wall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	parent.add_child(col)

func _create_path() -> void:
	# North-south main road (the level objective path).
	var road := PlaneMesh.new()
	road.size = Vector2(6.0, _map_size.y - 4.0)
	var road_inst := MeshInstance3D.new()
	road_inst.name = "MainRoad"
	road_inst.mesh = road
	road_inst.material_override = _mats["dirt"]
	road_inst.position = Vector3(0, 0.02, 0)
	add_child(road_inst)

	# East-west base paths along the foot of the mountains, on north and south sides.
	var base_path_w := 4.0
	var base_inset := 3.0  # distance from the cliff base
	var path_x_extent := _map_size.x - base_path_w - 2.0

	# Southern base path
	var south := PlaneMesh.new()
	south.size = Vector2(path_x_extent, base_path_w)
	var south_inst := MeshInstance3D.new()
	south_inst.name = "SouthBasePath"
	south_inst.mesh = south
	south_inst.material_override = _mats["dirt"]
	south_inst.position = Vector3(0, 0.018, _map_size.y * 0.5 - base_inset)
	add_child(south_inst)

	# Northern base path
	var north := PlaneMesh.new()
	north.size = Vector2(path_x_extent, base_path_w)
	var north_inst := MeshInstance3D.new()
	north_inst.name = "NorthBasePath"
	north_inst.mesh = north
	north_inst.material_override = _mats["dirt"]
	north_inst.position = Vector3(0, 0.018, -_map_size.y * 0.5 + base_inset)
	add_child(north_inst)

func _create_start_marker() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.08
	mesh.radial_segments = 32
	var marker := MeshInstance3D.new()
	marker.name = "ArrivalMarker"
	marker.mesh = mesh
	marker.material_override = _mats["start"]
	marker.position = Vector3(0, 0.06, _map_size.y * 0.5 - 4.0)
	add_child(marker)

# ---------------------------------------------------------------------------
# Biome sampling
# ---------------------------------------------------------------------------

# Returns 0..1
func _sample_moisture(x: float, z: float) -> float:
	return clamp((_moisture.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)

func _sample_temperature(x: float, z: float) -> float:
	# Slight latitudinal gradient (north = colder).
	var base: float = (_temperature.get_noise_2d(x, z) + 1.0) * 0.5
	var lat: float = clamp(0.5 - z / _map_size.y, 0.0, 1.0)  # 0 north..1 south
	return clamp(base * 0.6 + lat * 0.4, 0.0, 1.0)

# tundra | forest | meadow | swamp | desert
func _biome_at(x: float, z: float) -> String:
	var m := _sample_moisture(x, z)
	var t := _sample_temperature(x, z)
	if t < 0.35:
		return "tundra"
	if m > 0.65:
		return "swamp"
	if m < 0.35 and t > 0.55:
		return "desert"
	if m > 0.5:
		return "forest"
	return "meadow"

# ---------------------------------------------------------------------------
# Vegetation
# ---------------------------------------------------------------------------

func _scatter_vegetation() -> void:
	var area := _map_size.x * _map_size.y
	var attempts: int = int(area * 0.6)
	var min_x := -_map_size.x * 0.5 + 2.0
	var max_x := _map_size.x * 0.5 - 2.0
	var min_z := -_map_size.y * 0.5 + 2.0
	var max_z := _map_size.y * 0.5 - 2.0

	var placed: Array[Vector3] = []
	var min_spacing := 2.6

	for i in attempts:
		var x := _rng.randf_range(min_x, max_x)
		var z := _rng.randf_range(min_z, max_z)
		if abs(x) < ROAD_HALF_WIDTH:
			continue

		var biome := _biome_at(x, z)
		var density := _density.get_noise_2d(x * 1.5, z * 1.5) * 0.5 + 0.5
		var spawn_chance := _vegetation_chance_for_biome(biome)
		if _rng.randf() > spawn_chance * density:
			continue

		var pos := Vector3(x, 0, z)
		var ok := true
		for other in placed:
			if other.distance_to(pos) < min_spacing:
				ok = false
				break
		if not ok:
			continue
		placed.append(pos)

		_spawn_vegetation_for_biome(biome, pos)

func _vegetation_chance_for_biome(biome: String) -> float:
	match biome:
		"forest": return 0.85
		"swamp":  return 0.70
		"meadow": return 0.45
		"tundra": return 0.30
		"desert": return 0.20
		_: return 0.4

func _spawn_vegetation_for_biome(biome: String, pos: Vector3) -> void:
	# Decide tree vs bush ratio per biome.
	var tree_chance := 0.6
	match biome:
		"forest": tree_chance = 0.75
		"swamp":  tree_chance = 0.55
		"meadow": tree_chance = 0.30
		"tundra": tree_chance = 0.45
		"desert": tree_chance = 0.10

	if _rng.randf() < tree_chance:
		_spawn_tree_for_biome(biome, pos)
	else:
		_spawn_bush_for_biome(biome, pos)

func _spawn_tree_for_biome(biome: String, pos: Vector3) -> void:
	var species_pool: Array[String] = []
	match biome:
		"forest": species_pool = ["oak", "oak", "birch", "pine"]
		"swamp":  species_pool = ["willow", "willow", "birch"]
		"meadow": species_pool = ["oak", "birch"]
		"tundra": species_pool = ["pine", "pine", "birch"]
		"desert": species_pool = ["pine"]
		_: species_pool = ["oak"]

	var species: String = species_pool[_rng.randi() % species_pool.size()]
	# Growth stage: 0=sapling, 1=young, 2=mature, 3=ancient
	var stage := _rng.randi() % 4
	var scale_factor: float = [0.45, 0.75, 1.0, 1.35][stage]
	scale_factor *= _rng.randf_range(0.92, 1.12)
	var rot := _rng.randf() * TAU

	match species:
		"oak":    _make_oak(pos, scale_factor, rot, biome)
		"pine":   _make_pine(pos, scale_factor, rot, biome)
		"birch":  _make_birch(pos, scale_factor, rot, biome)
		"willow": _make_willow(pos, scale_factor, rot, biome)

# ----- Oak: rounded broad crown -----
func _make_oak(pos: Vector3, scale_factor: float, rot: float, biome: String) -> void:
	var tree := _make_tree_root("Oak", pos, scale_factor, rot)
	_make_trunk(tree, 0.30, 0.42, 2.6, _mats["bark_oak"], 8)

	var crown_color: StandardMaterial3D = _mats["leaf_oak"]
	if biome == "tundra":
		crown_color = _mats["leaf_oak_dark"]
	elif _rng.randf() < 0.15:
		crown_color = _mats["leaf_birch_autumn"]  # autumn variant

	_leaf_blob(tree, Vector3(0, 2.8, 0), 1.6, crown_color)
	_leaf_blob(tree, Vector3(0.45, 3.3, -0.2), 1.15, _mats["leaf_oak_dark"])
	_leaf_blob(tree, Vector3(-0.5, 3.2, 0.3), 1.0, crown_color)
	_collide_trunk(tree, 0.42, 2.5)

# ----- Pine: tall, conical layered crown -----
func _make_pine(pos: Vector3, scale_factor: float, rot: float, _biome: String) -> void:
	var tree := _make_tree_root("Pine", pos, scale_factor, rot)
	var trunk_h := 3.4
	_make_trunk(tree, 0.18, 0.30, trunk_h, _mats["bark_pine"], 8)

	var layers := 4
	var leaf_mat: StandardMaterial3D = _mats["leaf_pine"] if _rng.randf() > 0.4 else _mats["leaf_pine_dark"]
	for i in layers:
		var t: float = float(i) / float(layers - 1)
		var radius: float = lerp(1.4, 0.4, t)
		var height: float = lerp(1.4, 0.7, t)
		var y: float = 1.7 + i * 0.85
		_cone(tree, Vector3(0, y, 0), radius, height, leaf_mat)
	_collide_trunk(tree, 0.32, trunk_h)

# ----- Birch: slim white trunk, light foliage -----
func _make_birch(pos: Vector3, scale_factor: float, rot: float, biome: String) -> void:
	var tree := _make_tree_root("Birch", pos, scale_factor, rot)
	_make_trunk(tree, 0.16, 0.22, 3.0, _mats["bark_birch"], 8)

	# Bark marks
	for i in 4:
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.21
		rm.bottom_radius = 0.21
		rm.height = 0.06
		rm.radial_segments = 8
		ring.mesh = rm
		ring.material_override = _mats["bark_birch_marks"]
		ring.position.y = 0.6 + i * 0.7
		tree.add_child(ring)

	var leaf_mat: StandardMaterial3D = _mats["leaf_birch"]
	if biome == "tundra" or _rng.randf() < 0.25:
		leaf_mat = _mats["leaf_birch_autumn"]
	_leaf_blob(tree, Vector3(0, 3.1, 0), 1.1, leaf_mat)
	_leaf_blob(tree, Vector3(0.3, 3.5, 0.0), 0.8, leaf_mat)
	_collide_trunk(tree, 0.24, 3.0)

# ----- Willow: short trunk, weeping wide canopy -----
func _make_willow(pos: Vector3, scale_factor: float, rot: float, _biome: String) -> void:
	var tree := _make_tree_root("Willow", pos, scale_factor, rot)
	_make_trunk(tree, 0.30, 0.45, 2.0, _mats["bark_willow"], 8)

	# Wide drooping canopy made of overlapping flattened spheres.
	for i in 6:
		var angle: float = float(i) / 6.0 * TAU
		var px: float = cos(angle) * 0.9
		var pz: float = sin(angle) * 0.9
		_leaf_blob(tree, Vector3(px, 2.2, pz), 1.0, _mats["leaf_willow"], Vector3(1.0, 0.6, 1.0))
	_leaf_blob(tree, Vector3(0, 2.6, 0), 1.4, _mats["leaf_willow"], Vector3(1.0, 0.5, 1.0))
	_collide_trunk(tree, 0.45, 2.0)

# Helpers ---------------------------------------------------------------

func _make_tree_root(node_name: String, pos: Vector3, scale_factor: float, rot: float) -> StaticBody3D:
	var tree := StaticBody3D.new()
	tree.name = node_name
	tree.position = pos
	tree.rotation.y = rot
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)
	return tree

func _make_trunk(parent: Node3D, top_r: float, bot_r: float, height: float, mat: Material, segments: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = height
	mesh.radial_segments = segments
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = mesh
	trunk.material_override = mat
	trunk.position.y = height * 0.5
	parent.add_child(trunk)

func _collide_trunk(parent: Node3D, radius: float, height: float) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height * 0.5
	parent.add_child(col)

func _leaf_blob(parent: Node3D, pos: Vector3, radius: float, mat: Material, blob_scale: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.6
	mesh.radial_segments = 12
	mesh.rings = 6
	var leaves := MeshInstance3D.new()
	leaves.name = "Leaves"
	leaves.mesh = mesh
	leaves.material_override = mat
	leaves.position = pos
	leaves.scale = blob_scale
	parent.add_child(leaves)

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	cone.material_override = mat
	cone.position = pos
	parent.add_child(cone)

# ---------------------------------------------------------------------------
# Bushes
# ---------------------------------------------------------------------------

func _spawn_bush_for_biome(biome: String, pos: Vector3) -> void:
	var bush := StaticBody3D.new()
	bush.name = "Bush"
	bush.position = pos
	bush.rotation.y = _rng.randf() * TAU
	add_child(bush)

	var variant: String = "green"
	match biome:
		"forest": variant = "berry" if _rng.randf() < 0.35 else "green"
		"swamp":  variant = "dark"
		"meadow": variant = "green" if _rng.randf() < 0.7 else "berry"
		"tundra": variant = "dark"
		"desert": variant = "dry"

	var color_mat: StandardMaterial3D = _mats["bush_green"]
	match variant:
		"green": color_mat = _mats["bush_green"]
		"dark":  color_mat = _mats["bush_dark"]
		"dry":   color_mat = _mats["bush_dry"]
		"berry": color_mat = _mats["bush_berry"]

	var width: float = _rng.randf_range(0.6, 1.4)
	var height: float = _rng.randf_range(0.5, 1.1)

	# Multiple sphere blobs to vary shape.
	var blob_count := 2 + (_rng.randi() % 3)
	for i in blob_count:
		var mesh := SphereMesh.new()
		var r: float = width * _rng.randf_range(0.45, 0.7)
		mesh.radius = r
		mesh.height = r * 1.7
		mesh.radial_segments = 10
		mesh.rings = 5
		var b := MeshInstance3D.new()
		b.mesh = mesh
		b.material_override = color_mat
		b.position = Vector3(_rng.randf_range(-width * 0.3, width * 0.3),
			height * 0.5 + _rng.randf_range(-0.1, 0.1),
			_rng.randf_range(-width * 0.3, width * 0.3))
		bush.add_child(b)

	if variant == "berry":
		var berries := 4 + _rng.randi() % 4
		for i in berries:
			var berry := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.07
			bm.height = 0.14
			bm.radial_segments = 6
			bm.rings = 4
			berry.mesh = bm
			berry.material_override = _mats["berry"]
			berry.position = Vector3(_rng.randf_range(-width * 0.5, width * 0.5),
				height * 0.7,
				_rng.randf_range(-width * 0.5, width * 0.5))
			bush.add_child(berry)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = max(0.4, width * 0.5)
	col.shape = shape
	col.position.y = height * 0.5
	bush.add_child(col)

# ---------------------------------------------------------------------------
# Rocks (clustering, sizes, weathering)
# ---------------------------------------------------------------------------

func _scatter_rocks() -> void:
	var area := _map_size.x * _map_size.y
	var cluster_count: int = clamp(int(area / 250.0), 4, 30)

	for i in cluster_count:
		var cx := _rng.randf_range(-_map_size.x * 0.5 + 2, _map_size.x * 0.5 - 2)
		var cz := _rng.randf_range(-_map_size.y * 0.5 + 2, _map_size.y * 0.5 - 2)
		if abs(cx) < ROAD_HALF_WIDTH:
			continue

		var biome := _biome_at(cx, cz)
		var rocks_in_cluster := 1 + _rng.randi() % 5  # 1..5
		# Big formation chance
		var big_formation := _rng.randf() < 0.15

		for j in rocks_in_cluster:
			var offset := Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
			var pos := Vector3(cx, 0, cz) + offset
			if abs(pos.x) < ROAD_HALF_WIDTH:
				continue
			var size_scale: float
			if big_formation and j == 0:
				size_scale = _rng.randf_range(2.2, 3.2)  # boulder
			else:
				# Mix: pebbles, small rocks, boulders
				var roll := _rng.randf()
				if roll < 0.3:
					size_scale = _rng.randf_range(0.25, 0.5)  # pebble
				elif roll < 0.85:
					size_scale = _rng.randf_range(0.6, 1.2)   # rock
				else:
					size_scale = _rng.randf_range(1.4, 2.2)   # boulder
			_spawn_rock(pos, size_scale, biome)

func _spawn_rock(pos: Vector3, scale_factor: float, biome: String) -> void:
	var rock := StaticBody3D.new()
	rock.name = "Rock"
	rock.position = pos
	rock.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
	add_child(rock)

	# Pick base material by biome / random weathering.
	var color_mat: StandardMaterial3D = _mats["rock_grey"]
	var roll := _rng.randf()
	if biome == "swamp" or roll < 0.2:
		color_mat = _mats["rock_moss"]
	elif biome == "desert":
		color_mat = _mats["rock_warm"]
	elif roll < 0.5:
		color_mat = _mats["rock_dark"]

	# Build 1-3 stacked random boxes/spheres for varied silhouettes.
	var pieces := 1 + _rng.randi() % 3
	var max_extent := 0.0
	for i in pieces:
		var use_sphere := _rng.randf() < 0.4
		var piece := MeshInstance3D.new()
		var sx: float = scale_factor * _rng.randf_range(0.7, 1.3)
		var sy: float = scale_factor * _rng.randf_range(0.4, 0.9)
		var sz: float = scale_factor * _rng.randf_range(0.7, 1.3)
		if use_sphere:
			var sm := SphereMesh.new()
			sm.radius = sx * 0.6
			sm.height = sy * 1.2
			sm.radial_segments = 8
			sm.rings = 4
			piece.mesh = sm
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(sx, sy, sz)
			piece.mesh = bm
		piece.material_override = color_mat
		piece.position = Vector3(_rng.randf_range(-0.3, 0.3) * scale_factor,
			sy * 0.5,
			_rng.randf_range(-0.3, 0.3) * scale_factor)
		piece.rotation.y = _rng.randf() * TAU
		rock.add_child(piece)
		max_extent = max(max_extent, max(sx, sz))

	# Single approximate collider (skip for tiny pebbles to save physics work).
	if scale_factor > 0.4:
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(max_extent, scale_factor * 0.6, max_extent)
		col.shape = cs
		col.position.y = scale_factor * 0.3
		rock.add_child(col)

# ---------------------------------------------------------------------------
# Grass (multi-blade tufts, biome-driven density & color)
# ---------------------------------------------------------------------------

func _scatter_grass() -> void:
	var area := _map_size.x * _map_size.y
	# Use MultiMeshInstance3D for performance.
	var target_count: int = int(area * 1.2)

	# Group tufts by visual type to avoid one giant draw.
	var groups := {
		"lush":   {"mat": _mats["grass_lush"], "tufts": [] as Array[Transform3D]},
		"normal": {"mat": _mats["grass_normal"], "tufts": [] as Array[Transform3D]},
		"dry":    {"mat": _mats["grass_dry"], "tufts": [] as Array[Transform3D]},
		"tundra": {"mat": _mats["grass_tundra"], "tufts": [] as Array[Transform3D]},
	}

	var min_x := -_map_size.x * 0.5 + 1.0
	var max_x := _map_size.x * 0.5 - 1.0
	var min_z := -_map_size.y * 0.5 + 1.0
	var max_z := _map_size.y * 0.5 - 1.0

	for i in target_count:
		var x := _rng.randf_range(min_x, max_x)
		var z := _rng.randf_range(min_z, max_z)
		if abs(x) < ROAD_HALF_WIDTH - 0.5:
			continue

		var biome := _biome_at(x, z)
		var moisture := _sample_moisture(x, z)
		var density := (_density.get_noise_2d(x * 2.5, z * 2.5) + 1.0) * 0.5

		var spawn_chance: float
		var key: String
		match biome:
			"forest":
				spawn_chance = 0.85
				key = "lush" if moisture > 0.55 else "normal"
			"meadow":
				spawn_chance = 0.95
				key = "lush" if moisture > 0.55 else "normal"
			"swamp":
				spawn_chance = 0.7
				key = "lush"
			"tundra":
				spawn_chance = 0.5
				key = "tundra"
			"desert":
				spawn_chance = 0.25
				key = "dry"
			_:
				spawn_chance = 0.5
				key = "normal"

		if _rng.randf() > spawn_chance * density:
			continue

		var height_scale: float = _rng.randf_range(0.6, 1.4)
		# Tundra and desert grass shorter
		if biome == "tundra" or biome == "desert":
			height_scale *= 0.7

		var t := Transform3D()
		t = t.scaled(Vector3(_rng.randf_range(0.8, 1.2), height_scale, _rng.randf_range(0.8, 1.2)))
		t = t.rotated(Vector3.UP, _rng.randf() * TAU)
		t.origin = Vector3(x, 0, z)
		groups[key]["tufts"].append(t)

	for key in groups.keys():
		var tufts: Array = groups[key]["tufts"]
		if tufts.is_empty():
			continue
		_make_grass_multimesh(tufts, groups[key]["mat"], key)

func _make_grass_multimesh(transforms: Array, mat: StandardMaterial3D, group_name: String) -> void:
	var blade_mesh := _build_grass_blade_mesh(mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass_" + group_name
	mmi.multimesh = mm
	add_child(mmi)

func _build_grass_blade_mesh(mat: StandardMaterial3D) -> Mesh:
	# A short trio of crossed quads-ish using a small prism + box for variety.
	# For perf use a simple BoxMesh that visually reads as a tuft.
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.18, 0.4, 0.05)
	# Embed material via SurfaceTool/ArrayMesh-less path: wrap with a MeshInstance material override
	# but MultiMesh shares one material — apply directly to the resource.
	var arr_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	# Build two crossed quads to simulate a tuft.
	_add_quad(st, Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), Vector3(0.1, 0.5, 0), Vector3(-0.1, 0.5, 0))
	_add_quad(st, Vector3(0, 0, -0.1), Vector3(0, 0, 0.1), Vector3(0, 0.5, 0.1), Vector3(0, 0.5, -0.1))
	st.generate_normals()
	st.commit(arr_mesh)
	return arr_mesh

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	# Back faces for double-sided look
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)
