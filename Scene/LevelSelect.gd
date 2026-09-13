# LevelSelect.gd
extends Control

func _ready():
	_setup_level_buttons()

func _setup_level_buttons():
	# Get the progress for the module we just picked
	var progress = 1
	if Global.selected_module_id == 1:
		progress = Global.module1_progress
	elif Global.selected_module_id == 2:
		progress = Global.module2_progress
	elif Global.selected_module_id == 3:
		progress = Global.module3_progress

	# Loop through buttons 1 to 5
	for i in range(1, 6):
		var btn = get_node("MarginContainer/VBoxContainer/GridContainer/Level" + str(i)) # Adjust path to your buttons
		
		# Set the level number and module in the button's data
		btn.pressed.connect(_on_level_picked.bind(i))
		
		# LOCK LOGIC: Disable buttons higher than our progress
		if i > progress:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5) # Make it look grey/locked
	# Connect the Back button manually in code
	#$BackButton.pressed.connect(_on_back_button_pressed)

func _on_level_picked(lvl_num):
	# NOW we set the variables to start the game
	Global.current_module = Global.selected_module_id
	Global.current_level = lvl_num
	Global.is_free_will_mode = false
	
	# Go to the actual game
	get_tree().change_scene_to_file("res://Scene/main.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scene/ModuleSelect.tscn")
