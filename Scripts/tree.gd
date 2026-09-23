extends Node2D

var is_planted: bool = false
var planted_position: Vector2 = Vector2.ZERO

@onready var sprite = $Sprite2D
@onready var area = $Area2D

func _ready():
	if is_planted:
		planted_position = global_position
		add_to_group("planted_trees")

func chop():
	# Hide the tree instead of deleting it immediately
	sprite.hide()
	
	# Disable collision so it doesn't block pathfinding or radar
	if area:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	
	# Remove it from groups so it isn't detected by find_nearest etc
	if is_in_group("trees"):
		remove_from_group("trees")
		
	# If it's a planted tree, wait and regrow
	if is_planted:
		var timer = get_tree().create_timer(7.0)
		await timer.timeout
		regrow()
	else:
		# Wild trees just disappear completely
		queue_free()

func regrow():
	sprite.show()
	if area:
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
	add_to_group("trees")
	# Add a little pop-in animation
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
