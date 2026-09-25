extends Node2D

var is_planted: bool = false
var is_chopped: bool = false
var planted_position: Vector2 = Vector2.ZERO

@onready var sprite = $Sprite2D
@onready var area = $Area2D

func _ready():
	if is_planted:
		planted_position = global_position
		add_to_group("planted_trees")

func chop():
	# Prevent double-chopping while the tree is regrowing
	if is_chopped:
		return
	is_chopped = true
	
	# Hide the tree visually
	sprite.hide()
	
	# Disable collision so it doesn't block pathfinding or radar
	if area:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	
	# Remove it from groups so it isn't detected by find_nearest etc
	if is_in_group("trees"):
		remove_from_group("trees")
	
	# If it's a planted tree, use a child Timer (node-bound) so it
	# auto-cancels if this node is freed before the timer fires.
	if is_planted:
		var timer = Timer.new()
		timer.wait_time = 10.0
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(regrow)
		timer.start()
	else:
		# Wild trees just disappear completely
		queue_free()

func regrow():
	# Safety: sprite child could be gone if scene changed at the exact moment
	if not is_instance_valid(sprite):
		return
	is_chopped = false
	sprite.show()
	if area:
		area.set_deferred("monitoring", true)
		area.set_deferred("monitorable", true)
	add_to_group("trees")
	# Little pop-in animation at the same planted position
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
