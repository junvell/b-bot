extends PanelContainer

@export var command_id: String = "define_func"
@export var func_name: String = "my_function"

@onready var body_slot: VBoxContainer = $VBoxContainer/BodySlot
@onready var name_edit: LineEdit = $VBoxContainer/Header/NameEdit

signal body_clicked
signal remove_requested

func _ready():
	$VBoxContainer/Header/RemoveButton.pressed.connect(func(): remove_requested.emit())
	$VBoxContainer/Header/BodyHeader.pressed.connect(func(): body_clicked.emit())
	name_edit.text_changed.connect(func(txt): func_name = txt)
	_add_spacer(body_slot)
	
	name_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	$VBoxContainer/Header/BodyHeader.mouse_filter = Control.MOUSE_FILTER_PASS
	$VBoxContainer/Header/RemoveButton.mouse_filter = Control.MOUSE_FILTER_PASS

func _add_spacer(slot: VBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.name = "DropSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(spacer)

func get_body_blocks() -> Array:
	return body_slot.get_children().filter(func(c): return c.name != "DropSpacer")

	# Deletion is handled exclusively by the RemoveButton in the header.
	# Do NOT add a global _input handler here — it would fire when right-clicking
	# any child block inside the function body, deleting the entire function.

