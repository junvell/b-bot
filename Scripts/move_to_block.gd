extends Button

@export var command_id: String = "move_to"
@export var target_type: String = "trees"

@onready var type_option = $HBox/TypeOption

func _ready():
	type_option.clear()
	type_option.add_item("trees")
	type_option.add_item("rocks")
	type_option.add_item("warehouse")
	type_option.add_item("houses")
	
	type_option.item_selected.connect(func(idx): target_type = type_option.get_item_text(idx))
	type_option.mouse_filter = Control.MOUSE_FILTER_PASS

func _get_drag_data(_at_position):
	var preview = Button.new()
	preview.text = "Move To: " + target_type
	preview.modulate = Color(1, 1, 1, 0.5)
	set_drag_preview(preview)
	return {"command_id": "move_to", "block_ref": self, "target_type": target_type}

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		queue_free()

