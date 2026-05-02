extends CanvasLayer

signal resumed
signal exit_to_menu

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var menu_btn: Button = $Panel/VBox/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_btn.pressed.connect(_on_resume)
	menu_btn.pressed.connect(_on_menu)

func open() -> void:
	visible = true
	get_tree().paused = true
	resume_btn.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_resume() -> void:
	close()
	resumed.emit()

func _on_menu() -> void:
	get_tree().paused = false
	exit_to_menu.emit()
