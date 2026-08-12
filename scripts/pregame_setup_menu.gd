extends Control

@onready var time_control_option: OptionButton = $CenterContainer/Panel/Margin/VBox/Grid/TimeControlOption
@onready var game_mode_option: OptionButton = $CenterContainer/Panel/Margin/VBox/Grid/GameModeOption
@onready var start_button: Button = $CenterContainer/Panel/Margin/VBox/Buttons/StartButton
@onready var back_button: Button = $CenterContainer/Panel/Margin/VBox/Buttons/BackButton

@onready var custom_time_label: Label = $CenterContainer/Panel/Margin/VBox/Grid/CustomTimeLabel
@onready var custom_time_spinbox: SpinBox = $CenterContainer/Panel/Margin/VBox/Grid/CustomTimeSpinBox

func _ready() -> void:
	setup_options()
	connect_signals()
	# Initial visibility check
	_on_time_control_selected(time_control_option.get_selected_id())

func setup_options() -> void:
	# Setup Time Controls
	time_control_option.clear()
	time_control_option.add_item("10 Minutes", 0)
	time_control_option.add_item("5 Minutes", 1)
	time_control_option.add_item("3 Minutes", 2)
	time_control_option.add_item("Unlimited", 3)
	time_control_option.add_item("Custom", 4)
	
	# Select default (10 mins)
	time_control_option.select(0)
	
	# Setup Game Modes
	game_mode_option.clear()
	game_mode_option.add_item("Standard", 0)
	game_mode_option.add_item("Quantum Mockup", 1)
	
	# Select default
	game_mode_option.select(0)

func connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	time_control_option.item_selected.connect(_on_time_control_selected)

func _on_time_control_selected(index: int) -> void:
	# Show custom time input only if "Custom" (id 4) is selected
	var is_custom = (index == 4)
	custom_time_label.visible = is_custom
	custom_time_spinbox.visible = is_custom

func _on_start_pressed() -> void:
	# Apply settings
	apply_settings()
	
	# Start game
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func apply_settings() -> void:
	# Apply Time Limit
	var time_idx = time_control_option.get_selected_id()
	match time_idx:
		0: GlobalSettings.time_limit = GlobalSettings.TIME_10_MIN
		1: GlobalSettings.time_limit = GlobalSettings.TIME_5_MIN
		2: GlobalSettings.time_limit = GlobalSettings.TIME_3_MIN
		3: GlobalSettings.time_limit = GlobalSettings.TIME_UNLIMITED
		4: # Custom
			var minutes = custom_time_spinbox.value
			GlobalSettings.time_limit = minutes * 60.0
		_: GlobalSettings.time_limit = GlobalSettings.TIME_10_MIN
	
	# Apply Game Mode
	var mode_idx = game_mode_option.get_selected_id()
	match mode_idx:
		0: GlobalSettings.game_mode = GlobalSettings.GameMode.STANDARD
		1: GlobalSettings.game_mode = GlobalSettings.GameMode.QUANTUM_MOCKUP
		_: GlobalSettings.game_mode = GlobalSettings.GameMode.STANDARD
