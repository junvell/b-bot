extends Button

@export var command_id: String = "call_func"
@export var func_name: String = "my_function"

@onready var name_edit: LineEdit = $HBox/NameEdit

func _ready():
	name_edit.text_changed.connect(func(txt): 
		func_name = txt
		text = ""  # The Button text is empty — HBox shows the content
	)
	name_edit.mouse_filter = Control.MOUSE_FILTER_PASS

func _get_drag_data(_at_position):
	var preview = Button.new()
	preview.text = "call " + func_name + "()"
	preview.modulate = Color(1, 1, 1, 0.5)
	set_drag_preview(preview)
	return {"command_id": "call_func", "block_ref": self, "func_name": func_name}

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		queue_free()

