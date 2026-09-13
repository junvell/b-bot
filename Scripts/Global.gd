# Global.gd (Autoload / Singleton)
extends Node

# --- 1. SUPABASE CONFIGURATION ---
var supabase_url = "https://nekrydqajfekyzcvtynu.supabase.co"
var supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5la3J5ZHFhamZla3l6Y3Z0eW51Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNTQzNTAsImV4cCI6MjEwMjczMDM1MH0.ntR0pOEElFflDnDThe5r2xwzCLdcAwnvJl1mdSDaTTg"
var is_data_ready: bool = false # THE GUARD FLAG
# --- SIGNALS ---
signal stats_changed
signal inventory_changed
signal item_collected(type: String, amount: int)
signal mission_complete(python_code)
signal era_changed(new_era_name)

# --- STRATEGY RESOURCES ---
var money: int = 500
var wood: int = 0
var stone: int = 0
var population: int = 0
var current_era: String = "Rural"
var saved_city_map: Array = []

# --- INVENTORY SYSTEM ---
var wood_inventory: int = 0
var stone_inventory: int = 0
var max_wood_capacity: int = 30
var max_stone_capacity: int = 30

# --- GAME STATE ---
var selected_module_id: int = 3
var current_level: int = 6
var current_module: int = 3
var module1_progress: int = 1
var module2_progress: int = 1
var module3_progress: int = 1
var is_free_will_mode: bool = false

# --- SKILL TREE (Expanded) ---
var skill_unlocked = {
	"chop": false,
	"collect": false,
	"deposit": false,
	# Branch 1: Logic
	"while_loop": false,
	"if_else": false,
	"variables": false,
	"functions": false,
	# Branch 2: Sensors
	"scan": false,
	"gps": false,
	"radar": false,
	"pathfinding": false,
	# Branch 3: Infrastructure
	"build_house": true,
	"build_road": false,
	"warehouse": false,
	"park": false,
	"quarry": false
}

var skill_costs = {
	"chop": 50,
	"collect": 60,
	"deposit": 50,
	# Branch 1
	"while_loop": 100,
	"if_else": 200,
	"variables": 300,
	"functions": 500,
	# Branch 2
	"scan": 150,
	"gps": 250,
	"radar": 400,
	"pathfinding": 600,
	# Branch 3
	"build_house": 0,
	"build_road": 100,
	"warehouse": 250,
	"park": 400,
	"quarry": 800
}

var skill_prereqs = {
	"chop": "",
	"collect": "",
	"deposit": "",
	# Branch 1
	"while_loop": "",
	"if_else": "while_loop",
	"variables": "if_else",
	"functions": "variables",
	# Branch 2
	"scan": "",
	"gps": "scan",
	"radar": "gps",
	"pathfinding": "radar",
	# Branch 3
	"build_house": "",
	"build_road": "build_house",
	"warehouse": "build_road",
	"park": "warehouse",
	"quarry": "park"
}

# --- BALANCING VARIABLES ---
var tax_per_person: int = 5
var house_build_cost: int = 50
var house_wood_required: int = 5
var road_build_cost: int = 30
var road_wood_required: int = 2
var warehouse_build_cost: int = 200
var warehouse_wood_required: int = 8
var park_build_cost: int = 300
var park_wood_required: int = 5
var quarry_build_cost: int = 400
var quarry_stone_required: int = 0
var park_tax_bonus: int = 3   # Per park, added to tax_per_person
var maintenance_tick: float = 5.0

func _ready():
	# 1. Set the configuration variables directly
	# Note: Use these exact names (supabaseUrl and supabaseKey)
	Supabase.config.supabaseUrl = supabase_url
	Supabase.config.supabaseKey = supabase_key
	
	# 2. Verify it is connected
	print("[SYSTEM] Supabase initialized at: ", Supabase.config.supabaseUrl)

	# 3. Start your existing Economy Timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = maintenance_tick
	timer.timeout.connect(_on_economy_tick)
	timer.start()

func _on_economy_tick():
	# Count parks for tax multiplier (each park adds park_tax_bonus per person)
	var parks = []
	if get_tree():
		parks = get_tree().get_nodes_in_group("parks")
	var active_tax = tax_per_person + (parks.size() * park_tax_bonus)
	var total_taxes = population * active_tax
	money += total_taxes
	
	# Count quarries for passive stone income (+5 per quarry per tick)
	var quarries = []
	if get_tree():
		quarries = get_tree().get_nodes_in_group("quarries")
	if quarries.size() > 0:
		stone += quarries.size() * 5
		print("[QUARRY] Passive stone: +", quarries.size() * 5, " (total: ", stone, ")")
	
	update_stats()

# --- CLOUD DATA LOGIC (OBJECTIVE 5) ---
# --- DATA SERIALIZATION ---

func get_city_map_as_json() -> Array:
	var map_data = []
	
	# Get all nodes that are currently in these groups
	var houses = get_tree().get_nodes_in_group("houses")
	var roads = get_tree().get_nodes_in_group("roads")
	
	print("[DEBUG] Save Check: Found ", houses.size(), " houses and ", roads.size(), " roads.")
	
	for b in houses:
		map_data.append({"pos_x": b.position.x, "pos_y": b.position.y, "type": "house"})
	for r in roads:
		map_data.append({"pos_x": r.position.x, "pos_y": r.position.y, "type": "road"})
		
	return map_data

# UPDATED: Saves EVERYTHING to the cloud
# --- SAVE TO CLOUD ---
# Saves EVERYTHING to the cloud
func save_game_to_cloud():
	# 1. THE GUARD: Don't save if we are still loading from the internet
	if not is_data_ready:
		print("[SAVE BLOCKED] Initial load has not finished yet!")
		return 
	
	var user = Supabase.auth.client
	if user == null: return

	# 2. Prepare the standard data (Money, Progress, etc. ALWAYS save these)
	var data = {
		"money": money,
		"wood": wood,
		"stone": stone,
		"population": population,
		"current_module": current_module,
		"current_level": current_level,
		"module1_progress": module1_progress,
		"module2_progress": module2_progress,
		"module3_progress": module3_progress,
		"skill_data": skill_unlocked,
		"is_free_will_mode": is_free_will_mode,
		"current_era": current_era
	}
	
	# 3. --- THE CITY SHIELD ---
	if is_free_will_mode:
		# If we are physically in the Open World, scan the screen for new houses
		var current_map = get_city_map_as_json()
		data["city_map"] = current_map
		saved_city_map = current_map # Update the local memory too
		print("[SAVE] Updating city layout...")
	else:
		# If we are in the Main Menu, don't scan the screen (it's empty!)
		# Instead, send the 'saved_city_map' we already have in memory
		data["city_map"] = saved_city_map
		print("[SAVE] Preserving existing city layout while in menu.")
	# ---------------------------

	# 4. Push to Supabase
	var query = SupabaseQuery.new().from("profiles").update(data).eq("id", user.id)
	var task = Supabase.database.query(query)
	
	var result = await task.completed 
	return result

# Loads everything when the user logs in
# --- LOAD FROM CLOUD ---
# Loads everything when the user logs in
func load_game_from_cloud():
	var user = Supabase.auth.client 
	if user == null: return

	# --- THE GUARD: Lock saving until loading is 100% finished ---
	is_data_ready = false 
	
	reset_session_data()
	saved_city_map.clear() 

	print("[CLOUD] Fetching specific data for: ", user.email)
	
	var query = SupabaseQuery.new().from("profiles").select().eq("id", user.id)
	var task = Supabase.database.query(query)
	var result = await task.completed
	
	if result.error == null and result.data is Array and result.data.size() > 0:
		var profile = result.data[0]
		
		# Map data back to Godot variables
		money = int(profile.get("money", 500))
		wood = int(profile.get("wood", 0))
		stone = int(profile.get("stone", 0))
		population = int(profile.get("population", 0))
		current_module = int(profile.get("current_module", 1))
		current_level = int(profile.get("current_level", 1))
		current_era = profile.get("current_era", "Rural")
		is_free_will_mode = profile.get("is_free_will_mode", false)
		
		module1_progress = int(profile.get("module1_progress", 1))
		module2_progress = int(profile.get("module2_progress", 1))
		module3_progress = int(profile.get("module3_progress", 1))
		
		if profile.has("skill_data"):
			skill_unlocked = profile.skill_data
			
		if profile.has("city_map"):
			saved_city_map = profile.city_map
			
		update_stats()
		era_changed.emit(current_era)
		
		# --- THE GUARD: Data is safe to be saved now ---
		is_data_ready = true 
		print("[LOAD SUCCESS] Progress and Map restored for: ", user.email)
	else:
		# If it's a new user, allow saving so they can create their first profile
		is_data_ready = true 
		print("[LOAD] No profile found or server error. Ready for new user.")

func add_history_entry(lvl_name: String, code: String):
	var user = Supabase.auth.get_user()
	if user:
		var data = {
			"user_id": user.id,
			"level_name": lvl_name,
			"python_code": code
		}
		var query = Supabase.database.query(SupabaseQuery.new().from("history").insert([data]))
		await query.completed

# --- SKILL TREE LOGIC ---

func try_unlock_skill(skill_id: String) -> bool:
	var id = skill_id.to_lower() # Case insensitive check
	
	if skill_unlocked.has(id):
		var cost = skill_costs[id]
		
		# Check prerequisites
		var prereq = skill_prereqs.get(id, "")
		if prereq != "" and not skill_unlocked.get(prereq, false):
			print("[SYSTEM] Prerequisite not met for ", id, ". Needs ", prereq)
			return false
			
		# Check if player has money and doesn't already own the skill
		if money >= cost and not skill_unlocked[id]:
			# 1. Deduct the cost
			money -= cost
			
			# 2. Unlock the requested skill
			skill_unlocked[id] = true
			
			# --- NEW: BUNDLE UNLOCK LOGIC ---
			# If they buy Chop, they get Deposit for free!
			if id == "chop":
				skill_unlocked["deposit"] = true
				print("[SYSTEM] Bundle Unlock: Chop and Deposit modules installed.")
			# --------------------------------
			
			# 3. Save and notify UI
			update_stats()
			save_game_to_cloud() 
			return true
			
	return false

# --- HELPER FUNCTIONS ---

func update_stats():
	stats_changed.emit()

func can_carry(type: String, amount: int) -> bool:
	match type:
		"wood": return wood_inventory + amount <= max_wood_capacity
		"stone": return stone_inventory + amount <= max_stone_capacity
	return false

func add_to_inventory(type: String, amount: int) -> bool:
	if not can_carry(type, amount): return false
	match type:
		"wood": wood_inventory += amount
		"stone": stone_inventory += amount
	inventory_changed.emit()
	item_collected.emit(type, amount)
	return true

func deposit_inventory():
	wood += wood_inventory
	stone += stone_inventory
	wood_inventory = 0
	stone_inventory = 0
	inventory_changed.emit()
	update_stats()
	save_game_to_cloud() # Auto-save after deposit

func reset_inventory():
	wood_inventory = 0
	stone_inventory = 0
	inventory_changed.emit()

func add_money(amount: int):
	money += amount
	update_stats()

func spend_resources(m_amount: int, w_amount: int) -> bool:
	if money >= m_amount and wood >= w_amount:
		money -= m_amount
		wood -= w_amount
		update_stats()
		save_game_to_cloud() # Auto-save after spending
		return true
	return false

func check_for_evolution():
	var old_era = current_era
	
	if population < 20:
		current_era = "Rural"
	elif population < 100: # I used 100 here to match your earlier strategy
		current_era = "Suburban"
	else:
		current_era = "Urban"
	
	# Always emit if we want to "Force" a refresh, 
	# but only print/log if it's a new evolution
	if current_era != old_era:
		print("[ERA SYSTEM] Evolved to: ", current_era)
	
	era_changed.emit(current_era) # Tell houses to update textures
		
		
# Add this function to Global.gd
func reset_session_data():
	print("[SYSTEM] Wiping session data for new user...")
	
	# 1. Reset Resources to starting values
	money = 500
	wood = 0
	stone = 0
	population = 0
	
	# 2. Reset Game State
	current_module = 1
	current_level = 1
	current_era = "Rural"
	is_free_will_mode = false
	
	# 3. Reset Module Progress
	module1_progress = 1
	module2_progress = 1
	module3_progress = 1
	
	# 4. Reset Skill Tree (Lock everything except root/default nodes)
	skill_unlocked = {
		"chop": false,
		"collect": false,
		"deposit": false,
		"while_loop": false,
		"if_else": false,
		"variables": false,
		"functions": false,
		"scan": false,
		"gps": false,
		"radar": false,
		"pathfinding": false,
		"build_house": true,
		"build_road": false,
		"warehouse": false,
		"park": false,
		"quarry": false
	}
	
	# 5. Refresh the UI
	update_stats()

func logout():
	print("[SYSTEM] Starting logout sequence...")
	
	# 1. Save one last time to be safe before the session ends
	if Supabase.auth.client:
		await save_game_to_cloud()
		
		# 2. Tell Supabase to sign out (Clears the web token)
		Supabase.auth.sign_out()
	
	# 3. Wipe local memory (the function we added earlier)
	reset_session_data()
	
	# 4. Change back to the Login scene
	get_tree().change_scene_to_file("res://Scene/Login.tscn")
	print("[SYSTEM] Logout complete.")
