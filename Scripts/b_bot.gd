extends AnimatedSprite2D

var grid_size = 32
var move_speed = 0.2
var facing_direction = Vector2.RIGHT # NEW: Tracks where the bot is looking
var starting_position: Vector2

# --- VARIABLE STORAGE (unlocked by Variables skill) ---
var variables: Dictionary = {}

func _ready():
	starting_position = position
	stop()
	frame = 0

func move_bot(direction: Vector2) -> bool:
	facing_direction = direction # Update facing direction when moving
	# --- ANIMATION START ---
	# 1. Flip based on direction
	if direction == Vector2.LEFT:
		flip_h = true
	elif direction == Vector2.RIGHT:
		flip_h = false
	
	# 2. Start playing the movement animation
	play("move") 
	# -----------------------
	var target_pos = position + (direction * grid_size)
	
	# --- 1. FOG OF WAR COLLISION CHECK ---
	# We check if the target tile has a fog tile (source_id != -1)
	var level = get_parent()
	var fog = level.get_node_or_null("GroundLayer/FogLayer")
	if fog:
		var target_cell = fog.local_to_map(target_pos)
		if fog.get_cell_source_id(target_cell) != -1:
			print("BONK! The fog is too thick. Increase population to expand!")
			stop()
			frame = 0
			await get_tree().create_timer(move_speed).timeout 
			return false
			
	# --- NEW: SOLID OBSTACLE CHECK ---
	# Before moving, check if a tree is physically blocking the target tile
	var is_blocked = false
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.global_position.distance_to(target_pos) < 24.0:
			is_blocked = true
			break
			
	if is_blocked:
		print("BONK! B-Bot hit a tree and cannot move.")
		# Wait so the rhythm of the game doesn't break, then return false
		# Stop animation because we can't move
		stop()
		frame = 0
		await get_tree().create_timer(move_speed).timeout 
		return false
	# ---------------------------------
	
	# Smooth gliding animation
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, move_speed)
	
	await tween.finished
	# --- ANIMATION STOP ---
	# When the movement is done, stop the animation and go to frame 0
	stop()
	frame = 0
	print("B-Bot moved to: ", position)
	
	# --- CHECK IF STILL ON GROUND ---
	var tilemap = level.get_node_or_null("TileMapLayer")
	if tilemap:
		var bot_cell = tilemap.local_to_map(position)
		var tile_data = tilemap.get_cell_tile_data(bot_cell)
		if tile_data == null:
			print("B-Bot fell off the map! Resetting to start.")
			position = starting_position
			return false
	# --------------------------------
	
	return true

func get_object_under_bot():
	# Get all overlapping areas or bodies
	var areas = $Area2D.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent.is_in_group("trees"):
			return parent
		if parent.is_in_group("rocks"):
			return parent
		if parent.is_in_group("houses"):
			return parent
		if parent.is_in_group("warehouse"):
			return parent
	return null

func get_nearby_object():
	# 1. First check if something is directly under B-Bot
	var obj = get_object_under_bot()
	if obj != null:
		return obj

	# 2. Check the four adjacent grid cells for trees or rocks
	var bot_cell = Vector2i(round(global_position.x / float(grid_size)), round(global_position.y / float(grid_size)))
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in directions:
		var check_cell = bot_cell + dir
		for tree in get_tree().get_nodes_in_group("trees"):
			var tree_cell = Vector2i(round(tree.global_position.x / float(grid_size)), round(tree.global_position.y / float(grid_size)))
			if tree_cell == check_cell:
				return tree
		for rock in get_tree().get_nodes_in_group("rocks"):
			var rock_cell = Vector2i(round(rock.global_position.x / float(grid_size)), round(rock.global_position.y / float(grid_size)))
			if rock_cell == check_cell:
				return rock

	return null

func is_at_goal() -> bool:
	# This checks the Area2D you added to the B-Bot
	var areas = $Area2D.get_overlapping_areas()
	for a in areas:
		# Check if the thing we touched is in the 'goals' group
		if a.get_parent().is_in_group("goals"):
			return true
	return false

# --- ADD THIS NEW FUNCTION ---
func get_object_ahead():
	# Calculate the tile 1 step in front of the bot
	var target_pos = global_position + (facing_direction * grid_size)
	var max_dist = grid_size * 0.75 # Allow misaligned trees to be chopped
	
	# Look for trees
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.global_position.distance_to(target_pos) < max_dist:
			return tree
	# Look for rocks
	for rock in get_tree().get_nodes_in_group("rocks"):
		if rock.global_position.distance_to(target_pos) < max_dist:
			return rock
			
	return null

func scan() -> String:
	var obj = get_nearby_object()
	if obj == null:
		return "empty"
	if obj.is_in_group("trees"):
		return "tree"
	if obj.is_in_group("rocks"):
		return "rock"
	if obj.is_in_group("warehouse"):
		return "warehouse"
	return "empty"

func collect() -> bool:
	var obj = get_nearby_object()
	if obj == null:
		return false
	var type = ""
	var amount = 0
	if obj.is_in_group("trees"):
		type = "wood"
		amount = 10
	elif obj.is_in_group("rocks"):
		type = "stone"
		amount = 10
	else:
		return false
	
	if not Global.can_carry(type, amount):
		return false
	
	obj.queue_free()
	Global.add_to_inventory(type, amount)
	return true

func deposit() -> bool:
	var areas = $Area2D.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent.is_in_group("warehouse") or parent.is_in_group("base"):
			Global.deposit_inventory()
			return true
	return false

func move_to(target_name: String) -> bool:
	var nodes = get_tree().get_nodes_in_group(target_name)
	if nodes.is_empty():
		print("[PATHFINDING] No ", target_name, " found on map.")
		return false
	
	# 1. Find closest target by distance
	var best_node = null
	var best_dist = INF
	for node in nodes:
		var d = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_node = node
	
	if best_node == null:
		return false
	
	var target_pos = best_node.global_position
	var is_obstacle_target = (target_name == "trees" or target_name == "rocks")
	var steps = 0
	var max_steps = 60
	
	while steps < max_steps:
		var diff = target_pos - position
		var dist_grid_x = abs(diff.x) / float(grid_size)
		var dist_grid_y = abs(diff.y) / float(grid_size)
		
		# If target is solid (tree/rock), stop when adjacent (1 tile away) and face it
		if is_obstacle_target:
			if (dist_grid_x <= 1.1 and dist_grid_y < 0.4) or (dist_grid_y <= 1.1 and dist_grid_x < 0.4):
				if dist_grid_x > dist_grid_y:
					facing_direction = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
				else:
					facing_direction = Vector2.DOWN if diff.y > 0 else Vector2.UP
				flip_h = (facing_direction == Vector2.LEFT)
				print("[PATHFINDING] Reached adjacent to ", target_name, ". Facing: ", facing_direction)
				return true
		else:
			if position.distance_to(target_pos) <= grid_size / 2:
				print("[PATHFINDING] Reached ", target_name)
				return true
		
		steps += 1
		
		# Choose primary and secondary directions
		var primary_dir = Vector2.ZERO
		var secondary_dir = Vector2.ZERO
		if abs(diff.x) >= abs(diff.y):
			primary_dir = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
			if abs(diff.y) > 0.1:
				secondary_dir = Vector2.DOWN if diff.y > 0 else Vector2.UP
		else:
			primary_dir = Vector2.DOWN if diff.y > 0 else Vector2.UP
			if abs(diff.x) > 0.1:
				secondary_dir = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
		
		var moved = await move_bot(primary_dir)
		if not moved and secondary_dir != Vector2.ZERO:
			# Primary blocked, try secondary to slide around
			moved = await move_bot(secondary_dir)
		
		if not moved:
			print("[PATHFINDING] Path blocked toward ", target_name)
			break
		
		await get_tree().create_timer(0.05).timeout
	
	# Final check if adjacent or on target
	var final_diff = target_pos - position
	if is_obstacle_target:
		var fx = abs(final_diff.x) / float(grid_size)
		var fy = abs(final_diff.y) / float(grid_size)
		if (fx <= 1.1 and fy < 0.4) or (fy <= 1.1 and fx < 0.4):
			if fx > fy:
				facing_direction = Vector2.RIGHT if final_diff.x > 0 else Vector2.LEFT
			else:
				facing_direction = Vector2.DOWN if final_diff.y > 0 else Vector2.UP
			flip_h = (facing_direction == Vector2.LEFT)
			return true
	return position.distance_to(target_pos) <= grid_size / 2

func chop():
	var obj = get_object_ahead() 
	if obj and obj.is_in_group("trees"):
		# Fix Ghost Tree Bug: If the Sprite2D was returned, delete its parent (the root Tree node)
		if obj is Sprite2D:
			obj = obj.get_parent()
			
		obj.remove_from_group("trees") 
		obj.queue_free() 
		return true
	return false

func is_path_ahead(direction: Vector2 = Vector2.RIGHT) -> bool:
	# Convert target position to grid cell for reliable tile-based detection
	var target_pos = global_position + (direction * grid_size)
	var target_cell = Vector2i(round(target_pos.x / float(grid_size)), round(target_pos.y / float(grid_size)))
	
	for tree in get_tree().get_nodes_in_group("trees"):
		var tree_cell = Vector2i(round(tree.global_position.x / float(grid_size)), round(tree.global_position.y / float(grid_size)))
		if tree_cell == target_cell:
			return false
	return true

func can_move(direction: Vector2) -> bool:
	return is_path_ahead(direction)

# --- GPS METHODS (unlocked by GPS skill) ---

func get_x() -> int:
	var gx = int(round(global_position.x / float(grid_size)))
	variables["x"] = gx
	print("[GPS] X = ", gx)
	return gx

func get_y() -> int:
	var gy = int(round(global_position.y / float(grid_size)))
	variables["y"] = gy
	print("[GPS] Y = ", gy)
	return gy

# --- VARIABLE METHODS (unlocked by Variables skill) ---

func set_var(var_name: String, value) -> void:
	variables[var_name] = value
	print("[VAR] ", var_name, " = ", value)

func get_var(var_name: String):
	if variables.has(var_name):
		return variables[var_name]
	print("[VAR] Warning: variable '", var_name, "' not set.")
	return null

# --- RADAR METHOD (unlocked by Radar skill) ---

func find_nearest(type: String) -> Dictionary:
	var group_name = type  # e.g. "trees", "rocks", "houses", "warehouse"
	var nodes = get_tree().get_nodes_in_group(group_name)
	
	if nodes.is_empty():
		variables["nearest_dir"] = "none"
		variables["nearest_dist"] = -1
		print("[RADAR] No ", type, " found.")
		return {"found": false, "direction": "none", "distance": -1}
	
	# Find closest by Manhattan grid distance
	var best_node = null
	var best_dist = INF
	for node in nodes:
		var dx = abs(node.global_position.x - global_position.x)
		var dy = abs(node.global_position.y - global_position.y)
		var dist = (dx + dy) / float(grid_size)
		if dist < best_dist:
			best_dist = dist
			best_node = node
	
	# Determine primary direction
	var diff = best_node.global_position - global_position
	var dir = "right"
	if abs(diff.x) >= abs(diff.y):
		dir = "right" if diff.x > 0 else "left"
	else:
		dir = "down" if diff.y > 0 else "up"
	
	var dist_int = int(round(best_dist))
	variables["nearest_dir"] = dir
	variables["nearest_dist"] = dist_int
	print("[RADAR] Nearest ", type, ": ", dir, " at ", dist_int, " steps.")
	return {"found": true, "direction": dir, "distance": dist_int}
