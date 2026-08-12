extends Control

## Main Menu - Entry point for the game

@onready var play_button: Button = $CenterContainer/VBox/ButtonsContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/VBox/ButtonsContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBox/ButtonsContainer/QuitButton
@onready var settings_popup: Control = $SettingsPopup


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Connect settings popup buttons
	var close_btn = settings_popup.get_node_or_null("PopupContainer/Panel/VBox/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_settings_close)
	
	# Grab focus on play button for keyboard/controller navigation
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/pregame_setup_menu.tscn")


func _on_settings_pressed() -> void:
	settings_popup.visible = true


func _on_settings_close() -> void:
	settings_popup.visible = false


func _on_quit_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_popup.visible:
			settings_popup.visible = false
