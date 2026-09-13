# ModeSelection.gd
extends Control

@onready var tutorial_btn = $VBoxContainer/TutorialButton # Verify these paths!
@onready var open_world_btn = $VBoxContainer/OpenWorldButton
@onready var back_btn = $BackButton

func _ready():
	print("[DEBUG] ModeSelection scene loaded.")
	
	# Connect signals via code as a backup safety measure
	tutorial_btn.pressed.connect(_on_tutorial_button_pressed)
	open_world_btn.pressed.connect(_on_open_world_button_pressed)
	back_btn.pressed.connect(_on_back_button_pressed)
	
	_check_locks()

func _check_locks():
	var was_unlocked = Global.is_free_will_mode
	# Protect city map in menu
	Global.is_free_will_mode = false
	
	if Global.module3_progress < 5 and not was_unlocked:
		open_world_btn.disabled = true
		open_world_btn.text = "Open World (Locked)"
		print("[DEBUG] Open World is currently locked.")
	else:
		open_world_btn.disabled = false
		print("[DEBUG] Open World is unlocked.")

func _on_tutorial_button_pressed():
	print("[DEBUG] Tutorial button clicked. Changing scene...")
	get_tree().change_scene_to_file("res://Scene/ModuleSelect.tscn")

func _on_open_world_button_pressed():
	print("[DEBUG] Open World button clicked. Loading cloud data...")
	open_world_btn.disabled = true
	
	await Global.load_game_from_cloud()
	
	Global.current_module = 3
	Global.current_level = 6
	Global.is_free_will_mode = true
	
	print("[DEBUG] Data loaded. Entering world...")
	get_tree().change_scene_to_file("res://Scene/main.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scene/Menu/mainmenu.tscn")
