extends Control

@onready var module1_button = $CenterContainer/VBoxContainer/Module1Button
@onready var module2_button = $CenterContainer/VBoxContainer/Module2Button
@onready var module3_button = $CenterContainer/VBoxContainer/Module3Button

func _ready():
	# This scene does not contain the city. Keep the saved map protected from
	# logout saves while preserving the profile's Open World unlock state.
	var open_world_unlocked = Global.is_free_will_mode
	Global.is_free_will_mode = false

	# Disable Module 2 if not yet unlocked (progress-based gating)
	if Global.module2_progress <= 0:
		module2_button.disabled = true
		module2_button.text = "Module 2: Locked"
	# Disable Module 3 if Module 2 Level 5 not beaten
	# TEMPORARILY UNLOCKED FOR TESTING
	if false:
		module3_button.disabled = true
		module3_button.text = "Module 3: Locked"

func _on_module1_pressed():
	Global.selected_module_id = 1 # Tell Global we picked Module 1
	get_tree().change_scene_to_file("res://Scene/LevelSelect.tscn")

func _on_module2_pressed():
	Global.selected_module_id = 2 # Tell Global we picked Module 2
	get_tree().change_scene_to_file("res://Scene/LevelSelect.tscn")

func _on_module3_pressed():
	Global.selected_module_id = 3 # Tell Global we picked Module 2
	get_tree().change_scene_to_file("res://Scene/LevelSelect.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scene/modeselection/modeselection.tscn")
