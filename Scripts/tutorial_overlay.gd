extends CanvasLayer

@onready var title_label = $Panel/VBoxContainer/Title
@onready var desc_label = $Panel/VBoxContainer/Description
@onready var start_button = $Panel/VBoxContainer/StartButton

@export var overlay_title: String = "How to Play"
@export var overlay_description: String = ""

func _ready():
	# Connect button
	start_button.pressed.connect(_on_start_pressed)
	
	# Pause the game
	get_tree().paused = true

func _on_start_pressed():
	get_tree().paused = false
	visible = false
