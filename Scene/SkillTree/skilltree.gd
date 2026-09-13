extends Control

@onready var canvas = $Panel/VBoxOuter/ScrollContainer/Canvas
@onready var close_button = $Panel/VBoxOuter/TitleBar/HBox/CloseButton
@onready var money_label = $Panel/VBoxOuter/TitleBar/HBox/MoneyLabel

func _ready():
	Global.stats_changed.connect(_update_nodes)
	canvas.draw.connect(_on_canvas_draw)
	
	if close_button:
		close_button.pressed.connect(func(): hide())
	
	# Delay initialization slightly so UI lays out first
	call_deferred("_init_tree")

func _init_tree():
	for child in canvas.get_children():
		if child.has_signal("purchase_requested"):
			child.purchase_requested.connect(_on_purchase_requested)
	_update_nodes()

func _update_nodes():
	# Update money display
	if money_label:
		money_label.text = "  Money: $" + str(Global.money) + "  "
	
	for child in canvas.get_children():
		if child.has_method("update_state"):
			child.update_state()
	canvas.queue_redraw()

func _on_purchase_requested(skill_id: String):
	Global.try_unlock_skill(skill_id)

func _on_canvas_draw():
	for child in canvas.get_children():
		if "skill_id" in child and child.skill_id != "":
			var prereq_id = Global.skill_prereqs.get(child.skill_id, "")
			if prereq_id != "":
				var prereq_node = _find_node_by_id(prereq_id)
				if prereq_node:
					var start_pos = prereq_node.position + Vector2(prereq_node.size.x / 2, prereq_node.size.y)
					var end_pos = child.position + Vector2(child.size.x / 2, 0)
					
					var color = Color(0.2, 0.3, 0.4, 0.5) # Locked line
					if Global.skill_unlocked.get(prereq_id, false):
						if Global.skill_unlocked.get(child.skill_id, false):
							color = Color(0.2, 0.8, 0.3, 0.9) # Both unlocked (Green)
						else:
							color = Color(0.8, 0.8, 1.0, 0.9) # Available (White/Blue)
					
					canvas.draw_line(start_pos, end_pos, color, 3.0, true)

func _find_node_by_id(id: String) -> Node:
	for child in canvas.get_children():
		if "skill_id" in child and child.skill_id == id:
			return child
	return null
