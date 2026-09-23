extends Node2D

# 1. NODE REFERENCES
var bot: Node2D
@onready var city_grid = $CityGrid
@onready var container = $LevelContainer # The node that holds the tutorial islands
@onready var sequence = $CanvasLayer/Terminal/VBoxContainer/ScrollContainer/Sequence
@onready var run_button = $CanvasLayer/Terminal/VBoxContainer/RunButton
@onready var stop_button = $CanvasLayer/Terminal/VBoxContainer/StopButton
@onready var back_button = $CanvasLayer/HUD/MainHBox/BackButton
@onready var win_popup = $CanvasLayer/WinPopup
@onready var editor_button = $CanvasLayer/HUD/MainHBox/ModeToggleButton  # The button to switch modes
@onready var research_button = $CanvasLayer/HUD/MainHBox/Research
@onready var skill_tree_window = $CanvasLayer/Skilltree # Path to the node you just added


var is_executing: bool = false # Add this near your other variables
var active_slot: VBoxContainer
var python_cmd_queue: Array = []
var is_processing_python_queue: bool = false
var call_depth: int = 0 # Recursion guard for call_func

# Resource Labels
@onready var money_label = $CanvasLayer/HUD/MainHBox/HBoxContainer3/MoneyLabel
@onready var wood_label = $CanvasLayer/HUD/MainHBox/HBoxContainer/WoodLabel
@onready var stone_label = $CanvasLayer/HUD/MainHBox/HBoxContainer2/StoneLabel
@onready var pop_label = $CanvasLayer/HUD/MainHBox/HBoxContainer4/PopLabel
@onready var inventory_label = $CanvasLayer/HUD/MainHBox/HBoxContainer5/InventoryLabel

# Win condition for current level
var current_win_type: String = "reach_goal"
var current_win_target: int = 0
var showing_mastery: bool = false

# Preloaded Scenes
@onready var block_scene = preload("res://Scene/Action_block.tscn") 
@onready var house_scene = preload("res://Scene/House.tscn")
@onready var road_scene = preload("res://Scene/Road.tscn")
var level_1_scene = preload("res://Scene/TutorialLevel/Level1.tscn")
var level_2_scene = preload("res://Scene/TutorialLevel/Level2.tscn")
var level_3_scene = preload("res://Scene/TutorialLevel/Level3.tscn")
var level_4_scene = preload("res://Scene/TutorialLevel/Level4.tscn")
var level_5_scene = preload("res://Scene/TutorialLevel/Level5.tscn")

var level_2_1_scene = preload("res://Scene/TutorialLevel/Module2/Level2_1.tscn")
var level_2_2_scene = preload("res://Scene/TutorialLevel/Module2/Level2_2.tscn")
var level_2_3_scene = preload("res://Scene/TutorialLevel/Module2/Level2_3.tscn")
var level_2_4_scene = preload("res://Scene/TutorialLevel/Module2/Level2_4.tscn")
var level_2_5_scene = preload("res://Scene/TutorialLevel/Module2/Level2_5.tscn")

var level_3_1_scene = preload("res://Scene/TutorialLevel/Module3/Level3_1.tscn")
var level_3_2_scene = preload("res://Scene/TutorialLevel/Module3/Level3_2.tscn")
var level_3_3_scene = preload("res://Scene/TutorialLevel/Module3/Level3_3.tscn")
var level_3_4_scene = preload("res://Scene/TutorialLevel/Module3/Level3_4.tscn")
var level_3_5_scene = preload("res://Scene/TutorialLevel/Module3/Level3_5.tscn")

@onready var tutorial_overlay_scene = preload("res://Scene/TutorialOverlay.tscn")
@onready var while_loop_scene = preload("res://Scene/Blocks/WhileLoopBlock.tscn")
@onready var if_else_scene = preload("res://Scene/Blocks/IfElseBlock.tscn")
@onready var set_var_scene = preload("res://Scene/Blocks/SetVarBlock.tscn")
@onready var define_func_scene = preload("res://Scene/Blocks/DefineFuncBlock.tscn")
@onready var call_func_scene = preload("res://Scene/Blocks/CallFuncBlock.tscn")
@onready var find_nearest_scene = preload("res://Scene/Blocks/FindNearestBlock.tscn")
@onready var move_to_scene = preload("res://Scene/Blocks/MoveToBlock.tscn")
@onready var warehouse_scene = preload("res://Scene/Warehouse.tscn")
@onready var park_scene = preload("res://Scene/Park.tscn")
@onready var quarry_scene = preload("res://Scene/Quarry.tscn")

# Registry for user-defined functions (populated by DefineFunc blocks at runtime)
var func_registry: Dictionary = {}

func _ready():
	win_popup.hide()
	Global.stats_changed.connect(_update_hud)
	Global.inventory_changed.connect(_update_hud)
	Global.item_collected.connect(_on_item_collected)
	active_slot = sequence
	
	# Let us save before the window closes
	get_tree().set_auto_accept_quit(false)
	
	# SET UP THE WEB BRIDGE (Only runs if game is on a website)
	if OS.has_feature("web"):
		# Initialize the JS-side command queue
		JavaScriptBridge.eval("window.pythonCommandQueue = [];")
		print("[GD] Web bridge initialized (polling mode)")
	
	# Set up drop zone on the main Sequence
	sequence.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
	sequence.block_dropped.connect(_on_slot_block_dropped.bind(sequence))
	
	# START THE FIRST LEVEL
	load_mission(Global.current_module, Global.current_level)
	_update_hud()
	# TEMPORARY TEST:
	research_button.show()
#reseachbutton
	if research_button:
		research_button.pressed.connect(_on_research_pressed)
		#research_button.hide() # <--- ADD THIS: Hide it at the start of Level 1

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[SYSTEM] Window closing, saving progress...")
		if Global and Supabase.auth.client:
			await Global.save_game_to_cloud()
		get_tree().quit()

func _process(delta):
	if OS.has_feature("web"):
		# Export bot state every 5 frames only (throttle to reduce web overhead)
		if Engine.get_process_frames() % 5 == 0:
			var goal = get_tree().get_first_node_in_group("goals")
			var state = {
				"build_count": city_grid.get_child_count(), # --- ADDED THIS LINE ---
				"scan": bot.scan() if is_instance_valid(bot) else "empty",
				"at_goal": bot.is_at_goal() if is_instance_valid(bot) else false,
				"is_path_ahead": bot.is_path_ahead(bot.facing_direction) if is_instance_valid(bot) else false,
				"bot_x": bot.global_position.x if is_instance_valid(bot) else 0,
				"bot_y": bot.global_position.y if is_instance_valid(bot) else 0,
				"goal_x": goal.global_position.x if is_instance_valid(goal) else 99999,
				"goal_y": goal.global_position.y if is_instance_valid(goal) else 99999,
				"grid_size": bot.grid_size if is_instance_valid(bot) else 32,
				"wood": Global.wood,
				"wood_inventory": Global.wood_inventory,
				"stone": Global.stone,
				"stone_inventory": Global.stone_inventory,
				"money": Global.money,
				"population": Global.population,
				"max_wood_capacity": Global.max_wood_capacity
			}
			var state_json = JSON.stringify(state)
			JavaScriptBridge.eval("window.botState = " + state_json + ";")
		
		if not is_processing_python_queue:
			var queue_len = JavaScriptBridge.eval("window.pythonCommandQueue.length")
			if queue_len > 0:
				print("[GD] JS queue length: ", queue_len)
				while true:
					var js_cmd = JavaScriptBridge.eval("window.pythonCommandQueue.shift()")
					if js_cmd == null:
						break
					
					print("[GD] Polled command: ", js_cmd)
					
					if js_cmd is String:
						# --- NEW LOGIC: SPLIT COMMAND AND ARGUMENT ---
						if "|" in js_cmd:
							var parts = js_cmd.split("|")
							var cmd_name = parts[0]
							var cmd_arg = parts[1] if parts.size() > 1 else ""
							python_cmd_queue.append({"cmd": cmd_name, "arg": cmd_arg})
						else:
							# No pipe found, treat as normal command
							python_cmd_queue.append({"cmd": js_cmd, "arg": ""})
						# ----------------------------------------------
					else:
						print("[GD] WARNING: unexpected type: ", typeof(js_cmd))
						
				if python_cmd_queue.size() > 0:
					_process_python_queue()
					
func _setup_saved_city(map_data: Array):
	print("[SYSTEM] Reconstructing ", map_data.size(), " structures...")
	
	# 1. Clear the current grid to avoid duplicates
	for child in city_grid.get_children():
		child.queue_free()
	
	# 2. Reset local population to 0 before we recount based on saved houses
	Global.population = 0

	# 3. Spawn the buildings from the data
	for building_data in map_data:
		var type = building_data["type"]
		var pos = Vector2(building_data["pos_x"], building_data["pos_y"])
		
		# Choose the right scene
		var scene_to_spawn: PackedScene = null
		var is_tree = false
		match type:
			"house": scene_to_spawn = house_scene
			"planted_tree": 
				scene_to_spawn = preload("res://Scene/tree.tscn")
				is_tree = true
			"warehouse": scene_to_spawn = warehouse_scene
			"park": scene_to_spawn = park_scene
			"quarry": scene_to_spawn = quarry_scene
		
		if scene_to_spawn == null:
			continue
			
		var instance = scene_to_spawn.instantiate()
		
		# Place it back in the world
		instance.position = pos
		if is_tree and "is_planted" in instance:
			instance.is_planted = true
		city_grid.add_child(instance)
		
		# 4. CRITICAL: Add the population value back for every house found
		if type == "house":
			Global.population += 5 # Match the value you give in _spawn_building

	# 5. --- THE FIX ---
	# Now that all houses are on screen and population is correct, 
	# force the game to check the Era and update all house textures.
	Global.check_for_evolution() 
	
	# Refresh labels
	Global.update_stats()
	_update_hud()
	
	print("[SYSTEM] Visual city state restored. Current Era: ", Global.current_era)
# --- 2. MISSION MANAGEMENT ---
func load_mission(module_id, lvl_id):
	
	# Clear old level and any built structures
	for child in container.get_children(): child.queue_free()
	for child in city_grid.get_children(): child.queue_free()
		# If we are loading a tutorial level (1-5), turn off Free Will Mode
	if lvl_id < 6:
		Global.is_free_will_mode = false
	else:
		Global.is_free_will_mode = true
	# --- FIX 1: RESOURCE PROTECTION ---
	# We ONLY reset resources if we are starting the very first Tutorial.
	# If lvl_id is 6 (Open World), we skip this so we can keep our Cloud Data!
	if lvl_id < 6:
		Global.money = 500
		Global.wood = 0
		Global.stone = 0
		Global.population = 0
		Global.current_era = "Rural" 
		Global.reset_inventory()
		Global.update_stats()
	# ----------------------------------
	
	# Back button visible only in tutorial mode
	#back_button.visible = not Global.is_free_will_mode
		# 3. Handle UI visibility globally
	# We start by assuming the back button is visible for tutorials
	back_button.show() 
	research_button.hide()
	editor_button.hide()
	$CanvasLayer/MissionPanel.show()
	$CanvasLayer/Terminal.show()
	# Load level-specific logic
	match module_id:
		1:
			match lvl_id:
				1:
					var map = level_1_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(1, 1)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Level 1: Move Forward"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Move 4 steps right to the flag."
					_add_tutorial_overlay(map, "How to Move", "Drag Move Right blocks into the Program. Press Run to make B-Bot move.")
				
				2:
					var map = level_2_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(1, 2)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Level 2: Multiple Movements"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Navigate the path to the flag."
					_add_tutorial_overlay(map, "Multiple Movements", "Chain multiple Move blocks to navigate turns.")
				
				3:
					var map = level_3_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(1, 3)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Level 3: Loops"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Use a while loop to reach the flag."
					_add_tutorial_overlay(map, "Using Loops", "Use a While Loop block to repeat commands. Drag blocks inside the loop body.")
				
				4:
					var map = level_4_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(1, 4)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Level 4: If & Else"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Choose the correct path \n using if/else."
					_add_tutorial_overlay(map, "If & Else", "Use If/Else to choose different paths. Drag blocks into the If and Else slots.")
				
				5:
					var map = level_5_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(1, 5)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Level 5: Nested Logic"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Navigate the maze \n using loops and conditions."
					_add_tutorial_overlay(map, "Nested Logic", "Combine loops and conditions to solve complex mazes.")
				
				6: # THE OPEN WORLD TRIGGER
					Global.is_free_will_mode = true
					
					# 1. Clear everything
					for child in container.get_children(): child.queue_free()
					for child in city_grid.get_children(): child.queue_free()
					
					# 2. Load the Open World Map
					var world = preload("res://Scene/Openworld/OpenWorld.tscn").instantiate()
					container.add_child(world)
					bot = world.get_node("BBot")
					
					# 3. Restore saved city
					if Global.saved_city_map.size() > 0:
						_setup_saved_city(Global.saved_city_map)
					
					# 4. UI Setup
					$CanvasLayer/MissionPanel.hide()
					$CanvasLayer/Terminal.show()
					editor_button.show()
					research_button.show()
					back_button.show()
					
					_setup_palette_for_level(3, 6)
					_log("Open World Initiated. Welcome, Mayor.")
		
		2:
			match lvl_id:
				1:
					var map = level_2_1_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(2, 1)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 2 - Level 1: First Harvest"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Move to the tree and collect it, then reach the flag."
					_add_tutorial_overlay(map, "First Harvest", "Stand next to a tree and use the Collect block to gather wood.")
				
				2:
					var map = level_2_2_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(2, 2)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 2 - Level 2: Clear Cutting"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Collect a straight row of 5 trees."
					_add_tutorial_overlay(map, "Clear Cutting", "Use a While Loop to collect multiple trees in a row.")
				
				3:
					var map = level_2_3_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(2, 3)
					current_win_type = "reach_goal"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 2 - Level 3: Quality Control"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Only collect trees. Skip the rocks!"
					_add_tutorial_overlay(map, "Quality Control", "Use Scan + If/Else to only collect trees and skip rocks.")
				
				4:
					var map = level_2_4_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(2, 4)
					current_win_type = "collect_count"
					current_win_target = 50
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 2 - Level 4: Inventory Management"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Collect exactly 50 Wood. Watch your bag limit!"
					_add_tutorial_overlay(map, "Inventory Management", "Your bag has a limit! Collect wood, then Deposit at the Warehouse. Repeat until you have 50 wood.")
				
				5:
					var map = level_2_5_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(2, 5)
					current_win_type = "deposit"
					current_win_target = 0
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 2 - Level 5: The Warehouse"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Collect wood, go to the Warehouse, and deposit it."
					_add_tutorial_overlay(map, "The Warehouse", "Stand on the Warehouse tile and use Deposit to store your wood.")
				
				6: # THE OPEN WORLD TRIGGER
					Global.is_free_will_mode = true
					
					# 1. Clear everything
					for child in container.get_children(): child.queue_free()
					for child in city_grid.get_children(): child.queue_free()
					
					# 2. Load the Open World Map
					var world = preload("res://Scene/Openworld/OpenWorld.tscn").instantiate()
					container.add_child(world)
					bot = world.get_node("BBot")
					
					# 3. Restore saved city
					if Global.saved_city_map.size() > 0:
						_setup_saved_city(Global.saved_city_map)
					
					# 4. UI Setup
					$CanvasLayer/MissionPanel.hide()
					$CanvasLayer/Terminal.show()
					editor_button.show()
					research_button.show()
					back_button.show()
					
					_setup_palette_for_level(3, 6)
					_log("Open World Initiated. Welcome, Mayor.")
		
		3:
			match lvl_id:
				1:
					var map = level_3_1_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(3, 1)
					current_win_type = "build_count"
					current_win_target = 1
					Global.money = 500
					Global.wood = 10
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 3 - Level 1: First Foundation"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Construct one house on a clear tile."
					_add_tutorial_overlay(map, "First Foundation", "Use the Build House block on an empty tile to construct a house.")
				
				2:
					var map = level_3_2_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(3, 2)
					current_win_type = "build_count"
					current_win_target = 3
					Global.money = 300
					Global.wood = 10
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 3 - Level 2: Green Thumb"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Plant a row of 3 trees."
					_add_tutorial_overlay(map, "Green Thumb", "Use the Plant Tree block on empty tiles to grow trees.")
				
				3:
					var map = level_3_3_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(3, 3)
					current_win_type = "build_count"
					current_win_target = 2
					Global.money = 200
					Global.wood = 15
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 3 - Level 3: Budgeting"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Build 2 houses. Each costs $100 and 5 wood."
					_add_tutorial_overlay(map, "Budgeting", "Houses cost money and wood! Plan your resources carefully.")
				
				4:
					var map = level_3_4_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(3, 4)
					current_win_type = "build_count"
					current_win_target = 1
					Global.money = 0
					Global.wood = 5
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 3 - Level 4: Land Clearing"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Chop the tree for money, then build a house."
					_add_tutorial_overlay(map, "Land Clearing", "Chop trees to earn money, then use that money to build houses.")
				
				5:
					var map = level_3_5_scene.instantiate()
					container.add_child(map)
					bot = map.get_node("BBot")
					_setup_palette_for_level(3, 5)
					current_win_type = "build_count"
					current_win_target = 6
					Global.money = 500
					Global.wood = 30
					$CanvasLayer/MissionPanel/VBoxContainer/Title.text = "Module 3 - Level 5: Green Suburb"
					$CanvasLayer/MissionPanel/VBoxContainer2/Task.text = "Goal: Build 3 houses and plant 3 trees."
					_add_tutorial_overlay(map, "Green Suburb", "Combine houses and trees to build a sustainable city!")
				
				6: # THE OPEN WORLD TRIGGER
					Global.is_free_will_mode = true
					
					# 1. Clear everything
					for child in container.get_children(): child.queue_free()
					for child in city_grid.get_children(): child.queue_free()
					
					# 2. Load the Open World Map
					var world = preload("res://Scene/Openworld/OpenWorld.tscn").instantiate()
					container.add_child(world)
					
					# 3. Re-assign the bot
					bot = world.get_node("BBot")
# --- FIX 2: RECONSTRUCT SAVED CITY ---
					# We only run this if we have data from the cloud
					if Global.saved_city_map.size() > 0:
						_setup_saved_city(Global.saved_city_map)
					# ------------------------------------	
					
					# 4. UI Setup - ONLY show buttons in Open World
					research_button.show() # <--- NOW it appears
					editor_button.show()
					$CanvasLayer/MissionPanel.hide()
					$CanvasLayer/Terminal.show()
					
					# 5. Unlock palette
					_setup_palette_for_level(3, 6) 
					_log("Open World Initiated. Welcome, Mayor.")

func _add_tutorial_overlay(map, title: String, description: String):
	var overlay = tutorial_overlay_scene.instantiate()
	map.add_child(overlay)
	overlay.title_label.text = title
	overlay.desc_label.text = description

func _setup_palette_for_level(module_id, lvl_id):
	# 1. Path to the container inside the ScrollContainer
	var palette = $CanvasLayer/Palette/VBoxContainer/ScrollContainer/HBoxContainer
	
	# 2. Hide everything first to reset the tray
	for child in palette.get_children():
		child.visible = false

	# --- CASE A: OPEN WORLD (Level 6+) ---
	if lvl_id >= 6:
		# Data-driven skill map: node name -> skill key (empty string = always visible)
		var skill_map = {
			"Block_ up":      "",
			"Block_down":     "",
			"Block3_left":    "",
			"Block4_right":   "",
			"Collect":        "collect",
			"Scan":           "scan",
			"Deposit":        "deposit",
			"BuildHouse":     "build_house",
			"PlantTree":      "plant_tree",
			"Chop":           "chop",
			"WhileLoop":      "while_loop",
			"IfElse":         "if_else",
			# Branch 1 — Logic
			"SetVar":         "variables",
			"DefineFunc":     "functions",
			"CallFunc":       "functions",
			# Branch 2 — Sensors
			"GetX":           "gps",
			"GetY":           "gps",
			"FindNearest":    "radar",
			"MoveTo":         "pathfinding",
			# Branch 3 — Infrastructure
			"BuildWarehouse": "warehouse",
			"BuildPark":      "park",
			"BuildQuarry":    "quarry",
		}

		for node_name in skill_map:
			var skill_key = skill_map[node_name]
			var block = palette.get_node_or_null(node_name)
			if block == null:
				continue
			if skill_key == "":
				block.visible = true  # Always show movement blocks
			else:
				block.visible = Global.skill_unlocked.get(skill_key, false)

		# Connect stats_changed for live palette refresh (disconnect first to avoid duplicates)
		if not Global.stats_changed.is_connected(_refresh_open_world_palette):
			Global.stats_changed.connect(_refresh_open_world_palette)
		return

	# Disconnect the live refresh if we leave the Open World
	if Global.stats_changed.is_connected(_refresh_open_world_palette):
		Global.stats_changed.disconnect(_refresh_open_world_palette)

	# --- CASE B: TUTORIAL MODE ---
	
	# Movement is ALWAYS visible
	palette.get_node("Block_ up").visible = true
	palette.get_node("Block_down").visible = true
	palette.get_node("Block3_left").visible = true
	palette.get_node("Block4_right").visible = true

	match module_id:
		1: # MODULE 1: MOVEMENT
			if lvl_id >= 3: palette.get_node("WhileLoop").visible = true
			if lvl_id >= 4: palette.get_node("IfElse").visible = true
		
		2: # MODULE 2: RESOURCES
			palette.get_node("Collect").visible = true
			
			# --- FIXED: Show Deposit for ALL levels in Module 2 ---
			if palette.has_node("Deposit"):
				palette.get_node("Deposit").visible = true 
			
			if lvl_id >= 3:
				palette.get_node("Scan").visible = true
				palette.get_node("IfElse").visible = true
			if lvl_id >= 4:
				palette.get_node("WhileLoop").visible = true

		3: # MODULE 3: BUILDING
			palette.get_node("BuildHouse").visible = true
			
			# --- FIXED: Show Deposit for ALL levels in Module 3 ---
			if palette.has_node("Deposit"):
				palette.get_node("Deposit").visible = true
				
			if lvl_id >= 2: palette.get_node("PlantTree").visible = true
			if lvl_id >= 3: palette.get_node("IfElse").visible = true
			if lvl_id >= 4: palette.get_node("Chop").visible = true
			if lvl_id >= 5: palette.get_node("WhileLoop").visible = true

# Called automatically whenever Global.stats_changed fires (while in Open World)
func _refresh_open_world_palette():
	_setup_palette_for_level(Global.current_module, Global.current_level)


# --- 3. THE PYTHON BRIDGE (The Reveal) ---
func _reveal_python():
	# We call the recursive function and pass the list of blocks in the sequence
	var python_code = "# B-Bot Python Script\n\n"
	python_code += generate_python_code(sequence.get_children())
	
	win_popup.show()
	$CanvasLayer/WinPopup/PythonCode.text = python_code
	
	# Automatically save winning solution to history
	var lvl_title = "Module " + str(Global.current_module) + " Level " + str(Global.current_level)
	Global.add_history_entry(lvl_title, python_code, "Blocks (Cleared)")

# --- 4. INTERPRETER LOGIC ---
func execute_blocks(block_list):
	for block in block_list:
		# 1. STOP CHECK: Exit immediately if user clicked "Stop Program"
		if not is_executing:
			return
			
		# 2. SAFETY CHECK: Make sure the block still exists (wasn't deleted)
		if not is_instance_valid(block):
			continue
			
		block.modulate = Color(1, 1, 0) # Highlight block in Yellow
		
		# Flag to determine if we check the Skill Tree (Only in Open World)
		var needs_check = Global.is_free_will_mode

		match block.command_id:
			# --- MOVEMENT (Always Free) ---
			"up":    await bot.move_bot(Vector2.UP)
			"down":  await bot.move_bot(Vector2.DOWN)
			"left":  await bot.move_bot(Vector2.LEFT)
			"right": await bot.move_bot(Vector2.RIGHT)

			# --- COLLECTION (Requires Skill) ---
			"collect":
				if not needs_check or Global.skill_unlocked.get("collect", false):
					bot.collect()
				else:
					_log("ERROR: 'Collect' hardware not installed.")

			"chop":
				if not needs_check or Global.skill_unlocked.get("chop", false):
					if Global.is_free_will_mode and not Global.can_carry("wood", 10):
						_log("ERROR: Bag full! Deposit wood at the Warehouse.")
					else:
						if bot.chop():
							# --- TUTORIAL LEVEL 3-4 SPECIAL CASE ---
							if Global.current_module == 3 and Global.current_level == 4:
								Global.add_money(100)
								_spawn_floating_text("+$100")
								_log("Money received from clearing land!")
							
							# --- NORMAL WOOD COLLECTION ---
							if Global.add_to_inventory("wood", 10):
								_spawn_floating_text("+10 Wood")
							
							Global.update_stats()
							_update_hud()
				else:
					_log("ERROR: 'Chop' module not installed.")

			"deposit":
				bot.deposit()

			"scan":
				bot.scan()

			# --- CONSTRUCTION (Requires Skill) ---
			"build_house":
				if not needs_check or Global.skill_unlocked.get("build_house", false):
					if not Global.is_free_will_mode or Global.spend_resources(Global.house_build_cost, Global.house_wood_required):
						await _spawn_building("house")
				else:
					_log("ERROR: 'Build House' module missing. Visit Research Lab.")

			"plant_tree":
				if not needs_check or Global.skill_unlocked.get("plant_tree", false):
					if not Global.is_free_will_mode or Global.spend_resources(Global.plant_tree_cost, Global.plant_tree_wood_required):
						await _spawn_building("planted_tree")
				else:
					_log("ERROR: 'Plant Tree' module missing. Visit Research Lab.")

			# Legacy "build" fallback — used by tutorial levels (Module 3 Levels 1-5)
			"build":
				if not needs_check or Global.skill_unlocked.get("build_house", false):
					var b_type = block.build_type if "build_type" in block else "house"
					if b_type == "house":
						if not Global.is_free_will_mode or Global.spend_resources(Global.house_build_cost, Global.house_wood_required):
							await _spawn_building("house")
					elif b_type == "planted_tree":
						if not Global.is_free_will_mode or Global.spend_resources(Global.plant_tree_cost, Global.plant_tree_wood_required):
							await _spawn_building("planted_tree")
				else:
					_log("ERROR: 'Build' module missing.")


			# --- LOOPS (Requires Skill) ---
			"while_loop":
				if not needs_check or Global.skill_unlocked.get("while_loop", false):
					var max_iter = 100
					var iter = 0
					while is_executing and _evaluate_while_condition(block) and iter < max_iter:
						iter += 1
						await execute_blocks(block.get_body_blocks())
						await get_tree().process_frame # Let the game breathe
						if _check_win_mid_execution(): break
					if iter >= max_iter: _log("Loop timeout: Infinite loop detected.")
				else:
					_log("ERROR: Loop Processor not installed.")

			# --- LOGIC (Requires Skill) ---
			"if_else":
				if not needs_check or Global.skill_unlocked.get("if_else", false):
					if _evaluate_if_condition(block):
						await execute_blocks(block.get_if_blocks())
					else:
						await execute_blocks(block.get_else_blocks())
				else:
					_log("ERROR: Logic Comparator missing.")

			# --- VARIABLES (Requires Skill) ---
			"set_var":
				if not needs_check or Global.skill_unlocked.get("variables", false):
					var vname = block.var_name if "var_name" in block else "count"
					var vval  = block.var_value if "var_value" in block else 0
					bot.set_var(vname, vval)
				else:
					_log("ERROR: Variable memory not installed.")

			# --- GPS (Requires Skill) ---
			"get_x":
				if not needs_check or Global.skill_unlocked.get("gps", false):
					bot.get_x()
				else:
					_log("ERROR: GPS Transponder not installed.")

			"get_y":
				if not needs_check or Global.skill_unlocked.get("gps", false):
					bot.get_y()
				else:
					_log("ERROR: GPS Transponder not installed.")

			# --- RADAR (Requires Skill) ---
			"find_nearest":
				if not needs_check or Global.skill_unlocked.get("radar", false):
					var ttype = block.target_type if "target_type" in block else "trees"
					bot.find_nearest(ttype)
				else:
					_log("ERROR: Resource Radar not installed.")

			# --- PATHFINDING (Requires Skill) ---
			"move_to":
				if not needs_check or Global.skill_unlocked.get("pathfinding", false):
					var ttype = block.target_type if "target_type" in block else "trees"
					await bot.move_to(ttype)
				else:
					_log("ERROR: Pathfinding module not installed.")

			# --- FUNCTIONS (Requires Skill) ---
			"define_func":
				if not needs_check or Global.skill_unlocked.get("functions", false):
					var fname = block.func_name if "func_name" in block else ""
					if fname != "":
						func_registry[fname] = block.get_body_blocks()
						_log("Function '" + fname + "' defined.")
				else:
					_log("ERROR: Function compiler not installed.")

			"call_func":
				if not needs_check or Global.skill_unlocked.get("functions", false):
					var fname = block.func_name if "func_name" in block else ""
					if func_registry.has(fname):
						if call_depth >= 10:
							_log("ERROR: Max recursion depth reached. Function '" + fname + "' called itself too many times.")
						else:
							call_depth += 1
							await execute_blocks(func_registry[fname])
							call_depth -= 1
					else:
						_log("ERROR: Function '" + str(fname) + "' not defined. Use Define Function first.")
				else:
					_log("ERROR: Function compiler not installed.")

			# --- INFRASTRUCTURE BUILDINGS (Require Skills) ---
			"build_warehouse":
				if not needs_check or Global.skill_unlocked.get("warehouse", false):
					if not Global.is_free_will_mode or Global.spend_resources(Global.warehouse_build_cost, Global.warehouse_wood_required):
						await _spawn_building("warehouse")
				else:
					_log("ERROR: Warehouse blueprint not installed.")

			"build_park":
				if not needs_check or Global.skill_unlocked.get("park", false):
					if not Global.is_free_will_mode or Global.spend_resources(Global.park_build_cost, Global.park_wood_required):
						await _spawn_building("park")
				else:
					_log("ERROR: City Park blueprint not installed.")

			"build_quarry":
				if not needs_check or Global.skill_unlocked.get("quarry", false):
					if not Global.is_free_will_mode or Global.spend_resources(Global.quarry_build_cost, Global.quarry_stone_required):
						await _spawn_building("quarry")
				else:
					_log("ERROR: Stone Quarry blueprint not installed.")

		# Reset color and wait for next command
		if is_instance_valid(block):
			block.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.1).timeout

func _on_back_button_pressed():
	# 1. Save progress first
	await Global.save_game_to_cloud()
	
	# The Module Select scene has no city nodes. Mark the mode as inactive
	# after saving so a later logout preserves saved_city_map instead of
	# scanning the empty menu scene and overwriting it.
	if Global.is_free_will_mode:
		Global.is_free_will_mode = false
	
	get_tree().change_scene_to_file("res://Scene/modeselection/modeselection.tscn")

func _on_run_button_pressed():
	if sequence.get_child_count() == 0: return
	
	# If in Open World, log the executed blocks as Python code
	if Global.is_free_will_mode:
		var code = generate_python_code(sequence.get_children())
		Global.add_history_entry("Open World", code, "Blocks")
	
	# 1. Update State
	is_executing = true
	call_depth = 0       # Reset recursion counter
	func_registry = {}   # Clear user functions so definitions are re-read each run
	run_button.visible = false # Hide Run button
	stop_button.visible = true  # Show Stop button
	
	# 2. Run the sequence
	await execute_blocks(sequence.get_children())
	
	# 3. If the script finished naturally (not stopped), clean up
	if is_executing:
		_cleanup_execution()

func _on_stop_button_pressed():
	# This triggers the 'return' checks inside your execute_blocks function
	is_executing = false
	_log("Program stopped manually.")
	_cleanup_execution()

# We use this helper function to reset the UI buttons and check win condition
func _cleanup_execution():
	is_executing = false
	run_button.visible = true
	stop_button.visible = false
	
	# Reset all block colors to white in case they stayed yellow
	for block in sequence.get_children():
		if is_instance_valid(block):
			block.modulate = Color(1, 1, 1)

	# CHECK FOR WIN AFTER PROGRAM FINISHES
	if not Global.is_free_will_mode:
		if _check_win_condition():
			_reveal_python()
		else:
			_log("Goal not reached. Try again!")

# --- 5. HELPER FUNCTIONS ---
func _update_hud():
	money_label.text = "Money: $" + str(Global.money)
	wood_label.text = "Wood: " + str(Global.wood) + " (Carrying: " + str(Global.wood_inventory) + ")"
	if stone_label:
		stone_label.text = "Stone: " + str(Global.stone)
	if inventory_label:
		inventory_label.text = "Bag: " + str(Global.wood_inventory + Global.stone_inventory) + "/" + str(Global.max_wood_capacity + Global.max_stone_capacity)
	pop_label.text = "Pop: " + str(Global.population)

func _check_win_condition() -> bool:
	match current_win_type:
		"reach_goal":
			return bot.is_at_goal()
		"collect_count":
			return Global.wood >= current_win_target
		"deposit":
			return Global.wood_inventory == 0 and Global.wood > 0
		"build_count":
			var built_count = 0
			for child in city_grid.get_children():
				if child.is_in_group("houses") or child.is_in_group("planted_trees"):
					built_count += 1
			return built_count >= current_win_target
	return false

func _check_win_mid_execution() -> bool:
	if current_win_type == "reach_goal":
		return bot.is_at_goal()
	if current_win_type == "collect_count":
		return Global.wood >= current_win_target
	if current_win_type == "build_count":
		var built_count = 0
		for child in city_grid.get_children():
			if child.is_in_group("houses") or child.is_in_group("planted_trees"):
				built_count += 1
		return built_count >= current_win_target
	return false

func _evaluate_while_condition(block) -> bool:
	# Default: while not at goal
	if current_win_type == "collect_count":
		return Global.wood < current_win_target
	if current_win_type == "build_count":
		var built_count = 0
		for child in city_grid.get_children():
			if child.is_in_group("houses") or child.is_in_group("planted_trees"):
				built_count += 1
		return built_count < current_win_target
	return not bot.is_at_goal()

func _evaluate_if_condition(block) -> bool:
	# 1. If the user put a 'Scan' block in the condition slot, always check for trees
	var condition_slot = block.get_node_or_null("VBoxContainer/ConditionSlot")
	if condition_slot and condition_slot.get_child_count() > 0:
		var cond_block = condition_slot.get_child(0)
		if cond_block.command_id == "scan":
			return bot.scan() == "tree"
	
	# 2. MODULE 3 LOGIC (Strategic Scaffolding)
	if Global.current_module == 3:
		# Level 3 is about money
		if Global.current_level == 3:
			return Global.money >= Global.house_build_cost
		# Level 4 is about the Tree obstacle, so we use the sensor!
		else:
			return bot.is_path_ahead()

	# 3. Default: use the physical sensor (Module 1 & 2)
	return bot.is_path_ahead()

func _on_item_collected(type: String, amount: int):
	_spawn_floating_text("+" + str(amount) + " " + type.capitalize())

func _spawn_floating_text(text: String):
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 0.5)
	var screen_pos = bot.get_global_transform_with_canvas().origin
	label.position = screen_pos
	$CanvasLayer.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -40), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	label.queue_free()

func _create_block(command_id: String, build_type: String = ""):
	match command_id:
		"while_loop":
			var block = while_loop_scene.instantiate()
			block.remove_requested.connect(_on_compound_remove.bind(block))
			var body_slot = block.get_node("VBoxContainer/BodySlot")
			block.body_clicked.connect(func(): active_slot = body_slot)
			body_slot.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
			body_slot.block_dropped.connect(_on_slot_block_dropped.bind(body_slot))
			return block
		"if_else":
			var block = if_else_scene.instantiate()
			block.remove_requested.connect(_on_compound_remove.bind(block))
			var if_slot = block.get_node("VBoxContainer/IfSlot")
			var else_slot = block.get_node("VBoxContainer/ElseSlot")
			block.if_clicked.connect(func(): active_slot = if_slot)
			block.else_clicked.connect(func(): active_slot = else_slot)
			if_slot.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
			if_slot.block_dropped.connect(_on_slot_block_dropped.bind(if_slot))
			else_slot.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
			else_slot.block_dropped.connect(_on_slot_block_dropped.bind(else_slot))
			return block
		"define_func":
			var block = define_func_scene.instantiate()
			block.remove_requested.connect(_on_compound_remove.bind(block))
			var body_slot = block.get_node("VBoxContainer/BodySlot")
			block.body_clicked.connect(func(): active_slot = body_slot)
			body_slot.set_script(preload("res://Scripts/terminal_drop_zone.gd"))
			body_slot.block_dropped.connect(_on_slot_block_dropped.bind(body_slot))
			block.self_modulate = Color(0.55, 0.1, 0.85, 1) # Deep purple
			return block
		"set_var":
			var block = set_var_scene.instantiate()
			block.self_modulate = Color(0.72, 0.3, 1.0, 1) # Violet
			return block
		"find_nearest":
			var block = find_nearest_scene.instantiate()
			block.self_modulate = Color(0.85, 0.75, 0.1, 1) # Yellow
			return block
		"move_to":
			var block = move_to_scene.instantiate()
			block.self_modulate = Color(0.4, 0.82, 0.2, 1) # Lime green
			return block
		"call_func":
			var block = call_func_scene.instantiate()
			block.self_modulate = Color(0.62, 0.2, 0.9, 1) # Purple
			return block
		_:
			var new_block = block_scene.instantiate()
			new_block.command_id = command_id
			if command_id == "build" and build_type != "":
				new_block.build_type = build_type
			# --- Color coding for all block types ---
			var target_color = Color(1, 1, 1) # Default White
			match command_id:
				"up", "down", "left", "right": target_color = Color("#4bb3e0") # Blue
				"scan":          target_color = Color("#ff7a81") # Pink
				"deposit":       target_color = Color("#f44336") # Red
				"build":         target_color = Color("#ff9800") # Orange
				"build_house":   target_color = Color("#ff9800") # Orange
				"plant_tree":    target_color = Color("#e67e00") # Darker orange
				"build_warehouse": target_color = Color("#8d6e63") # Brown
				"build_park":    target_color = Color("#66bb6a") # Green
				"build_quarry":  target_color = Color("#78909c") # Blue-gray
				"chop":          target_color = Color("#4caf50") # Green
				"get_x":         target_color = Color("#00bcd4") # Cyan
				"get_y":         target_color = Color("#00acc1") # Darker cyan
			new_block.self_modulate = target_color
			return new_block
	return null


func _get_insertion_index(slot: VBoxContainer, drop_pos: Vector2) -> int:
	for i in range(slot.get_child_count()):
		var child = slot.get_child(i)
		if drop_pos.y < child.position.y + child.size.y / 2:
			return i
	return slot.get_child_count()

func _is_in_palette(block) -> bool:
	var current_node = block.get_parent()
	
	# Look up the "family tree" of the node until we hit the top
	while current_node != null:
		# If we find a node named "Palette", then we know this block is from the tray
		if current_node.name == "Palette":
			return true
		# Keep moving up one level
		current_node = current_node.get_parent()
	
	# If we reached the top and never found "Palette", it's in the Terminal
	return false

func _on_slot_block_dropped(data: Dictionary, at_position: Vector2, slot: VBoxContainer):
	if data.has("block_ref") and not _is_in_palette(data.block_ref):
		# Moving / reordering an existing terminal block
		var block = data.block_ref
		var old_parent = block.get_parent()
		if old_parent == null:
			return
		var idx = _get_insertion_index(slot, at_position)
		if old_parent == slot:
			var current_idx = block.get_index()
			if idx > current_idx:
				idx -= 1
			slot.move_child(block, idx)
		else:
			old_parent.remove_child(block)
			slot.add_child(block)
			slot.move_child(block, idx)
	elif data.has("command_id"):
		# From palette: create a fresh block
		var command_id = data.command_id
		var bt = data.get("build_type", "")
		var new_block = _create_block(command_id, bt)
		if new_block:
			var idx = _get_insertion_index(slot, at_position)
			slot.add_child(new_block)
			slot.move_child(new_block, idx)

func _on_compound_remove(block):
	var was_active = false
	if block.has_method("get_body_blocks") and active_slot == block.body_slot:
		was_active = true
	elif block.has_method("get_if_blocks") and (active_slot == block.if_slot or active_slot == block.else_slot):
		was_active = true
	block.queue_free()
	if was_active:
		active_slot = sequence

func _spawn_building(type: String):
	var scene: PackedScene
	match type:
		"house":      scene = house_scene
		"planted_tree": scene = preload("res://Scene/tree.tscn")
		"warehouse":  scene = warehouse_scene
		"park":       scene = park_scene
		"quarry":     scene = quarry_scene
		_:
			_log("ERROR: Unknown building type: " + type)
			return
	
	var new_building = scene.instantiate()
	
	if type == "planted_tree" and "is_planted" in new_building:
		new_building.is_planted = true
	
	# Set position and add to the grid
	new_building.position = bot.position
	city_grid.add_child(new_building)
	
	# Wait one frame so Godot adds the node to its groups
	await get_tree().process_frame
	
	if Global.is_free_will_mode:
		if type == "house":
			Global.population += 5
			Global.check_for_evolution()
		
		# Update city map (only serialises houses and roads; others are ignored by get_city_map_as_json)
		Global.saved_city_map = Global.get_city_map_as_json()
		Global.save_game_to_cloud()
	
	Global.update_stats()
	print("[SYSTEM] Built '", type, "' at ", bot.position)


func _on_next_button_pressed():
	# 1. Hide the Win Popup
	win_popup.hide()
	
	# 2. Clear all blocks currently in the terminal (Sequence)
	for block in sequence.get_children():
		block.queue_free()
	
	# 3. Check if we already showed mastery and should enter Open World
	if showing_mastery:
		showing_mastery = false
		Global.is_free_will_mode = true
		win_popup.get_node("NextButton").text = "Next"
		load_mission(3, 6) 
		return
	
	# 4. Increase local level tracker
	Global.current_level += 1
	
	# 5. Update module progress trackers
	if Global.current_module == 1:
		if Global.current_level > Global.module1_progress:
			Global.module1_progress = Global.current_level
	elif Global.current_module == 2:
		if Global.current_level > Global.module2_progress:
			Global.module2_progress = Global.current_level
	elif Global.current_module == 3:
		if Global.current_level > Global.module3_progress:
			Global.module3_progress = Global.current_level
	
	# --- THE CRITICAL FIX: AWAIT THE SAVE ---
	# We use 'await' to make sure the data REACHES Supabase 
	# before we change the scene or load the next level.
	print("[SYSTEM] Attempting to save level progress to cloud...")
	await Global.save_game_to_cloud()
	print("[SYSTEM] Save confirmed.")
	
	# 6. Handle transitions after Level 5
	if Global.current_level > 5:
		if Global.current_module == 3:
			_show_mastery_screen()
		else:
			# Go back to menu if Module 1 or 2 is finished
			# We already saved, so it's safe to switch scenes now
			get_tree().change_scene_to_file("res://Scene/ModuleSelect.tscn")
	else:
		# Load the next tutorial level (2, 3, 4, or 5)
		load_mission(Global.current_module, Global.current_level)

func _show_mastery_screen():
	showing_mastery = true
	win_popup.get_node("Message").text = "Mastery Achieved!"
	win_popup.get_node("PythonCode").text = """Congratulations, Architect!

You have mastered visual programming.
Drag-and-drop blocks were just the beginning.

The Python Editor is now unlocked.
Write real code to build your city in the Open World!"""
	win_popup.get_node("NextButton").text = "Enter Open World"
	win_popup.show()

# This function reads blocks and returns a string of REAL Python code
func generate_python_code(block_list, indent_level = 0) -> String:
	var python_code = ""
	var tabs = "    ".repeat(indent_level) # Real Python 4-space indentation
	
	for block in block_list:
		match block.command_id:
			"up":
				python_code += tabs + "b_bot.move_up()\n"
			"down":
				python_code += tabs + "b_bot.move_down()\n"
			"left":
				python_code += tabs + "b_bot.move_left()\n"
			"right":
				python_code += tabs + "b_bot.move_right()\n"
			"collect":
				python_code += tabs + "b_bot.collect()\n"
			"scan":
				python_code += tabs + "b_bot.scan()\n"
			"deposit":
				python_code += tabs + "b_bot.deposit()\n"
			"build":
				var bt = "house"
				if "build_type" in block:
					bt = block.build_type
				python_code += tabs + "b_bot.build('" + bt + "')\n"
			"build_house":
				python_code += tabs + "b_bot.build_house()\n"
			"plant_tree":
				python_code += tabs + "b_bot.plant_tree()\n"

			"chop":
				python_code += tabs + "b_bot.chop()\n"
			"while_loop":
				if current_win_type == "collect_count":
					python_code += tabs + "while b_bot.wood < " + str(current_win_target) + ":\n"
				elif current_win_type == "build_count":
					python_code += tabs + "while b_bot.build_count < " + str(current_win_target) + ":\n"
				else:
					python_code += tabs + "while not b_bot.at_goal():\n"
				var body = block.get_body_blocks()
				if body.size() == 0:
					python_code += tabs + "    pass\n"
				else:
					python_code += generate_python_code(body, indent_level + 1)
			"if_else":
				var condition_str = "b_bot.is_path_ahead()"
				var condition_slot = block.get_node_or_null("VBoxContainer/ConditionSlot")
				if condition_slot and condition_slot.get_child_count() > 0:
					var cond_block = condition_slot.get_child(0)
					if cond_block.command_id == "scan":
						condition_str = "b_bot.scan() == 'tree'"
				elif Global.current_module == 3:
					condition_str = "city.money >= 100"
				python_code += tabs + "if " + condition_str + ":\n"
				var if_blocks = block.get_if_blocks()
				if if_blocks.size() == 0:
					python_code += tabs + "    pass\n"
				else:
					python_code += generate_python_code(if_blocks, indent_level + 1)
				var else_blocks = block.get_else_blocks()
				if else_blocks.size() > 0:
					python_code += tabs + "else:\n"
					python_code += generate_python_code(else_blocks, indent_level + 1)

			# --- New blocks ---
			"set_var":
				var vn = block.var_name if "var_name" in block else "count"
				var vv = block.var_value if "var_value" in block else 0
				python_code += tabs + vn + " = " + str(vv) + "\n"
			"get_x":
				python_code += tabs + "x = b_bot.get_x()\n"
			"get_y":
				python_code += tabs + "y = b_bot.get_y()\n"
			"find_nearest":
				var ttype = block.target_type if "target_type" in block else "trees"
				python_code += tabs + "result = b_bot.find_nearest('" + ttype + "')\n"
			"move_to":
				var ttype = block.target_type if "target_type" in block else "trees"
				python_code += tabs + "b_bot.move_to('" + ttype + "')\n"
			"define_func":
				var fname = block.func_name if "func_name" in block else "my_function"
				python_code += tabs + "def " + fname + "():\n"
				var body = block.get_body_blocks()
				if body.size() == 0:
					python_code += tabs + "    pass\n"
				else:
					python_code += generate_python_code(body, indent_level + 1)
				python_code += "\n"
			"call_func":
				var fname = block.func_name if "func_name" in block else "my_function"
				python_code += tabs + fname + "()\n"
			"build_warehouse":
				python_code += tabs + "b_bot.build_warehouse()\n"
			"build_park":
				python_code += tabs + "b_bot.build_park()\n"
			"build_quarry":
				python_code += tabs + "b_bot.build_quarry()\n"

	return python_code

# --- MODE SWITCHING (Blocks vs Python Editor) ---
func _on_mode_toggle_pressed():
	# Toggle between Block Mode and Editor Mode
	var editor = $CanvasLayer/PythonEditor
	editor.visible = !editor.visible
	
	if editor.visible:
		$CanvasLayer/HUD/MainHBox/ModeToggleButton.text = "Switch to Blocks"
		# Auto-translate current blocks to Python text as a hint
		$CanvasLayer/PythonEditor/VBoxContainer/CodeEdit.text = generate_python_code(sequence.get_children())
	else:
		$CanvasLayer/HUD/MainHBox/ModeToggleButton.text = "Switch tos Text Editor"

func _on_run_python_pressed():
	var pure_code = $CanvasLayer/PythonEditor/VBoxContainer/CodeEdit.text
	print("[GD] Run Python pressed. Code:\n", pure_code)
	
	var mode_title = "Open World" if Global.is_free_will_mode else ("Module " + str(Global.current_module) + " Level " + str(Global.current_level))
	Global.add_history_entry(mode_title, pure_code, "Python Code")
	
	if OS.has_feature("web"):
		var js_call = "window.runPythonCode(" + JSON.stringify(pure_code) + ");"
		print("[GD] Calling JS:", js_call)
		JavaScriptBridge.eval(js_call)
	else:
		print("[DEBUG] Python bridge only works in Web Export!")

func _on_js_callback(args):
	var command = args[0]
	var argument = args[1] if args.size() > 1 else ""
	print("[GD] JS callback received:", command, "arg:", argument)
	python_cmd_queue.append({"cmd": command, "arg": argument})
	if not is_processing_python_queue:
		_process_python_queue()

func _process_python_queue():
	print("[GD] Starting python queue processing")
	is_processing_python_queue = true
	while python_cmd_queue.size() > 0:
		var item = python_cmd_queue.pop_front()
		print("[GD] Executing command:", item.cmd)
		await _execute_python_command(item.cmd, item.arg)
		print("[GD] Command finished:", item.cmd)
	is_processing_python_queue = false
	print("[GD] Queue processing done")

func _execute_python_command(command: String, argument: String):
	if bot == null:
		_log("ERROR: B-Bot not found in the current scene.")
		return

	# Logic: In Open World, we must check if the module is bought in the Skill Tree.
	# In tutorial modules (1, 2, 3), we allow everything.
	var needs_skill_check = Global.is_free_will_mode

	match command:
		# --- MOVEMENT (Always Unlocked) ---
		"move_up":    await bot.move_bot(Vector2.UP)
		"move_down":  await bot.move_bot(Vector2.DOWN)
		"move_left":  await bot.move_bot(Vector2.LEFT)
		"move_right": await bot.move_bot(Vector2.RIGHT)
		
		# --- LOGISTICS ---
		"deposit":    bot.deposit()

		"collect":
			if not needs_skill_check or Global.skill_unlocked.get("collect", false):
				bot.collect()
			else:
				_log("ERROR: 'Collect' module not installed. Visit Research Lab.")
#bypassing the chop in the moudle 3 tutorial stage
		"chop":
			if not needs_skill_check or Global.skill_unlocked.get("chop", false):
				if Global.is_free_will_mode and not Global.can_carry("wood", 10):
					_log("ERROR: Bag full! Deposit wood at the Warehouse.")
				else:
					if bot.chop():
						# --- STRATEGIC BRANCHING ---
						if Global.is_free_will_mode:
							if Global.add_to_inventory("wood", 10):
								_spawn_floating_text("+10 Wood")
						else:
							if Global.current_module == 3:
								Global.add_money(100)
								Global.add_to_inventory("wood", 10)
								_spawn_floating_text("+$100 & Wood")
							else:
								Global.add_to_inventory("wood", 10)
								_spawn_floating_text("+10 Wood")
						
						_update_hud()
			else:
				_log("ERROR: 'Chop' module not installed.")

		# --- CONSTRUCTION ---
		"build_house":
			if not needs_skill_check or Global.skill_unlocked.get("build_house", false):
				if Global.spend_resources(Global.house_build_cost, Global.house_wood_required):
					if bot.get_object_under_bot() == null:
						_spawn_building("house")
						Global.population += 5
						Global.check_for_evolution()
						Global.update_stats()
			else:
				_log("ERROR: 'Build House' module not installed. Visit Research Lab.")

		"plant_tree":
			if not needs_skill_check or Global.skill_unlocked.get("plant_tree", false):
				if Global.spend_resources(Global.plant_tree_cost, Global.plant_tree_wood_required):
					if bot.get_object_under_bot() == null:
						_spawn_building("planted_tree")
						Global.update_stats()
			else:
				_log("ERROR: 'Plant Tree' module not installed. Visit Research Lab.")

		# Legacy "build" fallback — used by older Python scripts / tutorial code
		"build":
			var final_type = argument if argument != "" else "house"
			var required_skill = "build_house" if final_type == "house" else "plant_tree"
			if not needs_skill_check or Global.skill_unlocked.get(required_skill, false):
				if final_type == "house":
					if Global.spend_resources(Global.house_build_cost, Global.house_wood_required):
						if bot.get_object_under_bot() == null:
							_spawn_building("house")
							Global.population += 5
							Global.check_for_evolution()
							Global.update_stats()
				elif final_type == "planted_tree":
					if Global.spend_resources(Global.plant_tree_cost, Global.plant_tree_wood_required):
						if bot.get_object_under_bot() == null:
							_spawn_building("planted_tree")
							Global.update_stats()
			else:
				_log("ERROR: 'Build' module not installed. Visit Research Lab.")

		# --- VARIABLES ---
		"set_var":
			if not needs_skill_check or Global.skill_unlocked.get("variables", false):
				var parts = argument.split("=")
				if parts.size() == 2:
					var vname = parts[0].strip_edges()
					var vval = int(parts[1].strip_edges()) if parts[1].strip_edges().is_valid_int() else parts[1].strip_edges()
					bot.set_var(vname, vval)
				else:
					_log("set_var usage: set_var name=value")
			else:
				_log("ERROR: Variable memory not installed.")

		# --- GPS ---
		"get_x":
			if not needs_skill_check or Global.skill_unlocked.get("gps", false):
				bot.get_x()
			else:
				_log("ERROR: GPS Transponder not installed.")

		"get_y":
			if not needs_skill_check or Global.skill_unlocked.get("gps", false):
				bot.get_y()
			else:
				_log("ERROR: GPS Transponder not installed.")

		# --- RADAR ---
		"find_nearest":
			if not needs_skill_check or Global.skill_unlocked.get("radar", false):
				bot.find_nearest(argument if argument != "" else "trees")
			else:
				_log("ERROR: Resource Radar not installed.")

		# --- PATHFINDING ---
		"move_to":
			if not needs_skill_check or Global.skill_unlocked.get("pathfinding", false):
				await bot.move_to(argument if argument != "" else "trees")
			else:
				_log("ERROR: Pathfinding module not installed.")

		# --- INFRASTRUCTURE ---
		"build_warehouse":
			if not needs_skill_check or Global.skill_unlocked.get("warehouse", false):
				if Global.spend_resources(Global.warehouse_build_cost, Global.warehouse_wood_required):
					await _spawn_building("warehouse")
			else:
				_log("ERROR: Warehouse blueprint not installed.")

		"build_park":
			if not needs_skill_check or Global.skill_unlocked.get("park", false):
				if Global.spend_resources(Global.park_build_cost, Global.park_wood_required):
					await _spawn_building("park")
			else:
				_log("ERROR: City Park blueprint not installed.")

		"build_quarry":
			if not needs_skill_check or Global.skill_unlocked.get("quarry", false):
				if Global.spend_resources(Global.quarry_build_cost, Global.quarry_stone_required):
					await _spawn_building("quarry")
			else:
				_log("ERROR: Stone Quarry blueprint not installed.")

		"_":
			_log("ERROR: Unknown command received: " + command)
#reseachbutton
func _on_research_pressed():
	# Show the hidden overlay
	$CanvasLayer/Skilltree.show()
	# IMPORTANT: Refresh the money display so it shows the latest cash
	$CanvasLayer/Skilltree._update_nodes()

func _on_help_button_pressed():
	var cheat = $CanvasLayer/PythonEditor/CheatSheet
	if cheat:
		cheat.visible = !cheat.visible

func _log(msg: String):
	print("[SYSTEM]: ", msg)
