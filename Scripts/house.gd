extends Node2D

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("houses")
	# 1. Connect signal for future changes
	Global.era_changed.connect(_on_era_updated)
	
	# 2. IMMEDIATELY set texture based on current Global state
	_on_era_updated(Global.current_era)

func _on_era_updated(new_era):
	match new_era:
		"Rural":
			sprite.texture = load("res://Sprites/House/house.1.png")
		"Suburban":
			sprite.texture = load("res://Sprites/House/brick.house.png")
		"Urban":
			sprite.texture = load("res://Sprites/House/modern.house.png")
	# Visual 'Bounce' effect when evolving
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
