extends Control

# 1. References to your buttons
@onready var play_button = $Main/VBoxContainer/Play
@onready var setting_button = $Main/VBoxContainer/Setting

func _ready():
	# 2. Connect the "Play" button signal via code
	play_button.pressed.connect(_on_play_pressed)
	
	# Optional: Connect settings if you have a scene for it
	# setting_button.pressed.connect(_on_settings_pressed)

func _on_play_pressed():
	print("DEBUG: Play button clicked") # Add this to test
	var target_scene = "res://Scene/modeselection/modeselection.tscn"
	
	# Use ResourceLoader instead of FileAccess
	if ResourceLoader.exists(target_scene):
		print("DEBUG: Scene found, changing...")
		get_tree().change_scene_to_file(target_scene)
	else:
		printerr("ERROR: Cannot find ", target_scene)

func _on_logout_pressed():
	await Global.logout()
