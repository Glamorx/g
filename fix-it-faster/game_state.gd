extends Node

const TOTAL_LEVELS := 10
const SAVE_PATH := "user://progress.cfg"

var current_level: int = 1
var levels_unlocked: int = 1
var level_seeds: Dictionary = {}

func _ready() -> void:
	load_progress()
	if not level_seeds.has(1):
		level_seeds[1] = randi()
		save_progress()

func get_seed_for_level(level: int) -> int:
	if not level_seeds.has(level):
		level_seeds[level] = hash(str(level) + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()))
		save_progress()
	return level_seeds[level]

func complete_level(level: int) -> void:
	if level >= levels_unlocked and level < TOTAL_LEVELS:
		levels_unlocked = level + 1
		save_progress()

func is_level_unlocked(level: int) -> bool:
	return level <= levels_unlocked

func start_level(level: int) -> void:
	current_level = level
	get_tree().change_scene_to_file("res://game.tscn")

func map_size_for_level(level: int) -> Vector2:
	# Bigger maps each level. Level 1 = 50x40, Level 10 ~ 140x110.
	var scale := 1.0 + (level - 1) * 0.22
	return Vector2(50.0 * scale, 40.0 * scale)

func parts_needed_for_level(level: int) -> int:
	return 3 + level  # level 1 = 4 parts, level 10 = 13 parts

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "levels_unlocked", levels_unlocked)
	cfg.set_value("progress", "seeds", level_seeds)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	levels_unlocked = cfg.get_value("progress", "levels_unlocked", 1)
	level_seeds = cfg.get_value("progress", "seeds", {})

func reset_progress() -> void:
	levels_unlocked = 1
	level_seeds.clear()
	level_seeds[1] = randi()
	current_level = 1
	save_progress()

func unlock_all() -> void:
	levels_unlocked = TOTAL_LEVELS
	for lv in range(1, TOTAL_LEVELS + 1):
		if not level_seeds.has(lv):
			level_seeds[lv] = hash(str(lv) + "_" + str(randi()))
	save_progress()
