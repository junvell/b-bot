extends Button

@export var command_id: String = ""
@export var build_type: String = "house"

func _ready():
	match command_id:
		"up": text = "Move Up"
		"down": text = "Move Down"
		"left": text = "Move Left"
		"right": text = "Move Right"
		"collect": text = "Collect Stone" if Global.is_free_will_mode else "Collect"
		"scan": text = "Scan"
		"deposit": text = "Deposit"
		"build": text = "Build: " + build_type.capitalize()
		"build_house": text = "Build House"
		"plant_tree": text = "Plant Tree"
		"chop": text = "Chop"
		"while_loop": text = "While Loop"
		"if_else": text = "If / Else"
		"get_x": text = "Get X"
		"get_y": text = "Get Y"
		"build_warehouse": text = "Warehouse"
		"build_park": text = "Build Park"
		"build_quarry": text = "Build Quarry"
		_: text = command_id

func _get_drag_data(at_position):
	var preview = Button.new()
	preview.text = text
	preview.custom_minimum_size = custom_minimum_size
	preview.size = size
	preview.modulate = Color(1, 1, 1, 0.5)
	set_drag_preview(preview)
	var data = { "command_id": command_id, "block_ref": self }
	if command_id == "build":
		data["build_type"] = build_type
	return data

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		queue_free()
