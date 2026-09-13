extends PanelContainer

@export var command_id: String = "while_loop"

@onready var body_slot: VBoxContainer = $VBoxContainer/BodySlot

signal body_clicked
signal remove_requested

func _ready():
	$VBoxContainer/Header/RemoveButton.pressed.connect(func(): remove_requested.emit())
	$VBoxContainer/Header/BodyHeader.pressed.connect(func(): body_clicked.emit())
	_add_spacer(body_slot)

func _add_spacer(slot: VBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.name = "DropSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(spacer)

func add_child_block(block: Button):
	body_slot.add_child(block)
	block.pressed.connect(_on_child_pressed.bind(block))

func _on_child_pressed(child: Button):
	child.queue_free()

func get_body_blocks() -> Array:
	return body_slot.get_children().filter(func(c): return c.name != "DropSpacer")
