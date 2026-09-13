extends Node2D

@onready var floor_layer = $GroundLayer
@onready var fog_layer = $GroundLayer/FogLayer
@onready var bot = $BBot

@onready var tree_scene = preload("res://Scene/tree.tscn")
@onready var rock_scene = preload("res://Scene/Rock.tscn")
var map_center_cell = Vector2i(0,0) 
var resource_density_percent = 0.15 # 15% of the bright area can have resources

var tile_size = 32

func _ready():
	bot.add_to_group("bot")
	
	# 1. We do NOT generate grass anymore. We keep your editor map!
	# 2. We generate the fog only over the tiles you drew
	_generate_fog_over_active_map()
	
	# 3. Spawn resources safely on your grass
	_spawn_resources_on_grass()
	
	# 4. Start the regrowth timer
	var spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = 5.0 # Try to grow something every 5 seconds
	spawn_timer.timeout.connect(_on_regrowth_tick)
	spawn_timer.start()
	# Set the center cell based on where the bot starts
	map_center_cell = fog_layer.local_to_map(bot.position)
	_update_fog_vision()
	
	# Connect to Global stats so fog updates automatically when someone moves in!
	Global.stats_changed.connect(_update_fog_vision)

func _generate_fog_over_active_map():
	# This reads every tile you drew in the GroundLayer and covers it with fog
	var used_cells = floor_layer.get_used_cells()
	for cell in used_cells:
		fog_layer.set_cell(cell, 2, Vector2i(0, 0)) # Assumes black tile is at 0,0

func _spawn_resources_on_grass():
	# Find all grass tiles you drew
	var safe_tiles = _get_safe_spawn_tiles()
	safe_tiles.shuffle() # Randomize the list
	
	# Spawn 5 Trees and 3 Rocks on random empty tiles
	var trees_to_spawn = min(5, safe_tiles.size())
	for i in range(trees_to_spawn):
		var cell = safe_tiles.pop_front()
		_spawn_object(tree_scene, floor_layer.map_to_local(cell))
		
	var rocks_to_spawn = min(3, safe_tiles.size())
	for i in range(rocks_to_spawn):
		var cell = safe_tiles.pop_front()
		_spawn_object(rock_scene, floor_layer.map_to_local(cell))

func _get_safe_spawn_tiles() -> Array[Vector2i]:
	var safe_tiles: Array[Vector2i] = []
	var bot_cell = floor_layer.local_to_map(bot.position)
	
	# Loop through all tiles we have drawn in the editor
	for cell in floor_layer.get_used_cells():
		
		# --- NEW: FOG CHECK ---
		# Only spawn if the fog is REMOVED (source_id == -1)
		if fog_layer.get_cell_source_id(cell) != -1:
			continue # Skip this tile because it is still dark
		# ----------------------

		# Rule 1: Don't spawn exactly on the B-Bot
		if cell.distance_to(bot_cell) < 2:
			continue
			
		# Rule 2: Only spawn on Grass (Assuming Atlas 0,0 is grass)
		var atlas_coords = floor_layer.get_cell_atlas_coords(cell)
		if atlas_coords != Vector2i(0, 0):
			continue
			
		# Rule 3: Check if there is already an object there (Tree, House, etc)
		if _is_object_at_cell(cell):
			continue
			
		safe_tiles.append(cell)
	return safe_tiles

func _is_object_at_cell(cell: Vector2i) -> bool:
	var global_pos = floor_layer.map_to_local(cell)
	var max_dist = 24.0 # Allow for misaligned manually placed objects
	# Check trees
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.global_position.distance_to(global_pos) < max_dist: return true
	# Check rocks
	for rock in get_tree().get_nodes_in_group("rocks"):
		if rock.global_position.distance_to(global_pos) < max_dist: return true
	# Check houses
	for house in get_tree().get_nodes_in_group("houses"):
		if house.global_position.distance_to(global_pos) < max_dist: return true
	return false

func _spawn_object(scene: PackedScene, pos: Vector2):
	var instance = scene.instantiate()
	instance.position = pos
	floor_layer.add_child(instance) 
	
	# Add a "Pop-in" animation
	instance.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(instance, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# --- REGROWTH TICK ---
func _on_regrowth_tick():
	# 1. Calculate how many tiles are currently bright
	# We use the same math as your fog expansion
	var radius = 2 + (Global.population / 10) 
	var side_length = (radius * 2) + 1
	var total_bright_tiles = side_length * side_length
	
	# 2. Calculate the Max Capacity for this area size
	var max_resources_allowed = int(total_bright_tiles * resource_density_percent)
	
	# 3. Count how many trees and rocks currently exist in the world
	var current_tree_count = get_tree().get_nodes_in_group("trees").size()
	var current_rock_count = get_tree().get_nodes_in_group("rocks").size()
	var total_current_resources = current_tree_count + current_rock_count
	
	# 4. STRATEGIC CHECK: Only spawn if there is "room" in the bright zone
	if total_current_resources < max_resources_allowed:
		var safe_tiles = _get_safe_spawn_tiles()
		if safe_tiles.size() > 0:
			safe_tiles.shuffle()
			# Choose Tree (70% chance) or Rock (30% chance)
			var chosen_scene = tree_scene if randf() > 0.3 else rock_scene
			_spawn_object(chosen_scene, floor_layer.map_to_local(safe_tiles[0]))
			# print("New resource grown. Current: ", total_current_resources + 1, "/", max_resources_allowed)
	else:
		pass
		# print("Area reached maximum natural capacity. Build more houses to expand!")

# --- DYNAMIC FOG OF WAR ---
func _update_fog_vision():
	# Radius grows: 2 base + 1 for every 10 people
	var total_radius = 2 + (Global.population / 10)
	
	# Loop through the square area centered on the MAP START
	for x in range(-total_radius, total_radius + 1):
		for y in range(-total_radius, total_radius + 1):
			var target_cell = map_center_cell + Vector2i(x, y)
			fog_layer.set_cell(target_cell, -1) # Clear fog permanently
