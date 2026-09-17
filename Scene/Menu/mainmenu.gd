extends Control

# 1. References to your buttons
@onready var play_button = $Main/VBoxContainer/Play
@onready var setting_button = $Main/VBoxContainer/Setting
@onready var admin_button = $Main/VBoxContainer/AdminButton

func _ready():
	# 2. Connect the "Play" button signal via code
	play_button.pressed.connect(_on_play_pressed)
	admin_button.pressed.connect(_on_admin_pressed)
	
	# 3. Show admin button only for admin accounts
	admin_button.visible = Global.is_admin()

func _on_play_pressed():
	print("DEBUG: Play button clicked") # Add this to test
	var target_scene = "res://Scene/modeselection/modeselection.tscn"
	
	# Use ResourceLoader instead of FileAccess
	if ResourceLoader.exists(target_scene):
		print("DEBUG: Scene found, changing...")
		get_tree().change_scene_to_file(target_scene)
	else:
		printerr("ERROR: Cannot find ", target_scene)

func _on_admin_pressed():
	print("DEBUG: Admin Portal button clicked")
	get_tree().change_scene_to_file("res://Scene/Admin/AdminDashboard.tscn")

func _on_logout_pressed():
	await Global.logout()
