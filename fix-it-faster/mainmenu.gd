extends Control

@onready var grid: GridContainer = $LevelGrid
@onready var reset_btn: Button = $ResetButton
@onready var debug_btn: Button = $DebugUnlockButton
@onready var exit_btn: Button = $ExitButton

func _ready() -> void:
	_build_level_buttons()
	reset_btn.pressed.connect(_on_reset)
	debug_btn.pressed.connect(_on_debug_unlock)
	exit_btn.pressed.connect(_on_exit)

func _build_level_buttons() -> void:
	for child in grid.get_children():
		child.queue_free()

	for level in range(1, GameState.TOTAL_LEVELS + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 110)
		btn.add_theme_font_size_override("font_size", 28)

		if GameState.is_level_unlocked(level):
			btn.text = str(level)
			btn.disabled = false
			btn.pressed.connect(func(): GameState.start_level(level))
		else:
			btn.text = "Locked"
			btn.add_theme_font_size_override("font_size", 14)
			btn.disabled = true
		grid.add_child(btn)

func _on_reset() -> void:
	GameState.reset_progress()
	_build_level_buttons()

func _on_debug_unlock() -> void:
	GameState.unlock_all()
	_build_level_buttons()

func _on_exit() -> void:
	get_tree().quit()
