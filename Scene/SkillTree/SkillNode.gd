extends PanelContainer

signal purchase_requested(skill_id: String)

@export var skill_id: String = ""
@export var skill_name: String = "Unknown Skill"
@export var skill_desc: String = "Skill description..."
@export var skill_code: String = "python_code()"

@onready var title_label = $VBox/TitleLabel
@onready var cost_label = $VBox/CostLabel
@onready var badge_label = $VBox/BadgeLabel
@onready var button = $Button

var state: String = "locked"

func _ready():
	title_label.text = skill_name
	
	# Pass clicks from button up to the container
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)

func update_state():
	if skill_id == "": return
	
	var is_unlocked = Global.skill_unlocked.get(skill_id, false)
	var cost = Global.skill_costs.get(skill_id, 0)
	var prereq = Global.skill_prereqs.get(skill_id, "")
	
	var prereq_met = prereq == "" or Global.skill_unlocked.get(prereq, false)
	var can_afford = Global.money >= cost
	
	if is_unlocked:
		state = "researched"
	elif not prereq_met:
		state = "locked"
	elif prereq_met and not can_afford:
		state = "unaffordable"
	elif prereq_met and can_afford:
		state = "available"

	_apply_visual_state(cost)

func _apply_visual_state(cost: int):
	# Base style setup
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	
	cost_label.text = "$" + str(cost)
	cost_label.visible = true
	badge_label.visible = false
	
	match state:
		"locked":
			sb.bg_color = Color(0.1, 0.1, 0.15, 1) # Dim gray/blue
			sb.border_color = Color(0.2, 0.2, 0.3, 1)
			title_label.modulate = Color(0.5, 0.5, 0.5, 1)
			cost_label.modulate = Color(0.5, 0.5, 0.5, 1)
		"available":
			sb.bg_color = Color(0.15, 0.2, 0.3, 1)
			sb.border_color = Color(0.8, 0.8, 1.0, 1) # White highlight
			title_label.modulate = Color(1, 1, 1, 1)
			cost_label.modulate = Color(1, 1, 0, 1)
		"unaffordable":
			sb.bg_color = Color(0.15, 0.1, 0.1, 1)
			sb.border_color = Color(0.8, 0.3, 0.3, 1)
			title_label.modulate = Color(0.8, 0.8, 0.8, 1)
			cost_label.modulate = Color(1, 0, 0, 1) # Red cost
		"researched":
			sb.bg_color = Color(0.1, 0.3, 0.15, 1)
			sb.border_color = Color(0.2, 0.8, 0.3, 1)
			title_label.modulate = Color(1, 1, 1, 1)
			cost_label.visible = false
			badge_label.visible = true
			badge_label.text = "[INSTALLED]"
			badge_label.modulate = Color(0, 1, 0, 1)

	add_theme_stylebox_override("panel", sb)

func _on_button_pressed():
	if state == "available":
		purchase_requested.emit(skill_id)

func _on_mouse_entered():
	# Simple tooltip using standard tooltip system for now
	button.tooltip_text = "Code: " + skill_code + "\n\n" + skill_desc

func _on_mouse_exited():
	pass
