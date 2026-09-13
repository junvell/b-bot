extends PanelContainer

@export var command_id: String = "set_var"
@export var var_name: String = "count"
@export var var_value: int = 0

@onready var name_option = $HBox/NameOption
@onready var value_spin = $HBox/ValueSpin

func _ready():
	# Populate the variable name dropdown
	name_option.clear()
	name_option.add_item("count")
	name_option.add_item("x")
	name_option.add_item("y")
	name_option.add_item("steps")
	name_option.add_item("target")
	
	name_option.item_selected.connect(func(idx): var_name = name_option.get_item_text(idx))
	value_spin.value_changed.connect(func(val): var_value = int(val))
	
	# Make sure child controls pass right-clicks up to the parent
	name_option.mouse_filter = Control.MOUSE_FILTER_PASS
	value_spin.mouse_filter = Control.MOUSE_FILTER_PASS
	value_spin.get_line_edit().mouse_filter = Control.MOUSE_FILTER_PASS

func _get_drag_data(_at_position):
	var preview = Button.new()
	preview.text = "Set " + var_name + " = " + str(var_value)
	preview.modulate = Color(1, 1, 1, 0.5)
	set_drag_preview(preview)
	return {"command_id": "set_var", "block_ref": self, "var_name": var_name, "var_value": var_value}

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		queue_free()

