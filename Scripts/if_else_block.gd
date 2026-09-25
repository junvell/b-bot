extends PanelContainer

@export var command_id: String = "if_else"

@onready var if_slot: VBoxContainer = $VBoxContainer/IfSlot
@onready var else_slot: VBoxContainer = $VBoxContainer/ElseSlot
@onready var condition_slot: VBoxContainer = $VBoxContainer/ConditionSlot

signal if_clicked
signal else_clicked
signal remove_requested

func _ready():
	$VBoxContainer/Header/RemoveButton.pressed.connect(func(): remove_requested.emit())
	$VBoxContainer/Header/IfHeader.pressed.connect(func(): if_clicked.emit())
	$VBoxContainer/ElseHeader.pressed.connect(func(): else_clicked.emit())
	_add_spacer(if_slot)
	_add_spacer(else_slot)
	if condition_slot:
		condition_slot.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
		condition_slot.block_dropped.connect(_on_condition_dropped)

func _on_condition_dropped(data: Dictionary, _at_position: Vector2):
	if data.has("command_id") and data.command_id == "scan":
		var new_block = preload("res://Scene/Action_block.tscn").instantiate()
		new_block.command_id = "scan"
		new_block.text = "Scan"
		for child in condition_slot.get_children():
			if child.name != "DropSpacer":
				child.queue_free()
		condition_slot.add_child(new_block)
		$VBoxContainer/Header/IfHeader.text = "if b_bot.scan() == 'tree':"

func _add_spacer(slot: VBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.name = "DropSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(spacer)

func add_child_block_to_if(block: Button):
	if_slot.add_child(block)
	block.pressed.connect(_on_child_pressed.bind(block))

func add_child_block_to_else(block: Button):
	else_slot.add_child(block)
	block.pressed.connect(_on_child_pressed.bind(block))

func _on_child_pressed(child: Button):
	child.queue_free()

func get_if_blocks() -> Array:
	return if_slot.get_children().filter(func(c): return c.name != "DropSpacer")

func get_else_blocks() -> Array:
	return else_slot.get_children().filter(func(c): return c.name != "DropSpacer")
