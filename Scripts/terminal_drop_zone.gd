extends VBoxContainer

signal block_dropped(data: Dictionary, at_position: Vector2)

func _can_drop_data(_at_position, data):
	return data is Dictionary and (data.has("command_id") or data.has("block_ref"))

func _drop_data(at_position, data):
	block_dropped.emit(data, at_position)
