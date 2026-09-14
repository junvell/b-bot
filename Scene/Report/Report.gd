extends Control

# --- NODE REFERENCES ---
@onready var back_button = $RootVBox/HeaderBg/MarginContainer/HeaderBar/BackButton
@onready var user_label = $RootVBox/HeaderBg/MarginContainer/HeaderBar/UserLabel

# City Stats (top-left panel)
@onready var era_label = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/EraContainer/EraLabel
@onready var pop_label = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/PopLabel
@onready var tax_label = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/TaxLabel
@onready var money_val = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/TreasuryGrid/MoneyVal
@onready var wood_val = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/TreasuryGrid/WoodVal
@onready var stone_val = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/TreasuryGrid/StoneVal
@onready var house_count_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/BuildingList/HouseCount
@onready var road_count_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/BuildingList/RoadCount
@onready var warehouse_count_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/BuildingList/WarehouseCount
@onready var park_count_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/BuildingList/ParkCount
@onready var quarry_count_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/BuildingList/QuarryCount
@onready var total_buildings_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CityPanel/VBox/TotalBuildingsLabel

# Curriculum & Skills (top-right panel)
@onready var mod1_bar = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod1Bar
@onready var mod1_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod1Label
@onready var mod2_bar = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod2Bar
@onready var mod2_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod2Label
@onready var mod3_bar = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod3Bar
@onready var mod3_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/Mod3Label
@onready var skills_ratio_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/SkillsRatioLabel
@onready var skills_container = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/TopRow/CurriculumPanel/VBox/ScrollSkills/SkillsVBox

# History Log (full-width bottom panel)
@onready var scroll_history = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/HistoryPanel/VBox/ScrollHistory
@onready var history_container = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/HistoryPanel/VBox/ScrollHistory/HistoryVBox
@onready var empty_history_lbl = $RootVBox/ScrollArea/ContentVBox/MarginWrap/InnerVBox/HistoryPanel/VBox/EmptyHistoryLabel


func _ready():
	back_button.pressed.connect(_on_back_pressed)
	if not Global.is_data_ready:
		await Global.load_game_from_cloud()
	_load_report_data()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scene/modeselection/modeselection.tscn")

func _load_report_data():
	# 1. User Header
	var user_email = "Guest Architect"
	if Supabase and Supabase.auth and Supabase.auth.client:
		var u = Supabase.auth.client
		if u and "email" in u and u.email != "":
			user_email = u.email
	user_label.text = "Account: " + user_email

	# 2. City Statistics
	era_label.text = "Era: " + str(Global.current_era)
	match Global.current_era:
		"Rural":
			era_label.modulate = Color(0.4, 0.9, 0.4)
		"Suburban":
			era_label.modulate = Color(0.9, 0.8, 0.2)
		"Urban":
			era_label.modulate = Color(0.2, 0.8, 1.0)

	pop_label.text = "Citizens: " + str(Global.population)
	
	# Calculate active tax rate
	var summary = Global.get_city_summary()
	var park_count = summary.get("park", 0)
	var active_tax = Global.tax_per_person + (park_count * Global.park_tax_bonus)
	tax_label.text = "Tax Rate: $" + str(active_tax) + " / pop / 5s"
	if park_count > 0:
		tax_label.text += " (+" + str(park_count * Global.park_tax_bonus) + " from Parks)"
	
	# Vault resources
	money_val.text = "$" + str(Global.money)
	wood_val.text = str(Global.wood) + " Wood"
	stone_val.text = str(Global.stone) + " Stone"
	
	# Buildings breakdown
	house_count_lbl.text = "Houses: " + str(summary.get("house", 0))
	road_count_lbl.text = "Roads: " + str(summary.get("road", 0))
	warehouse_count_lbl.text = "Warehouses: " + str(summary.get("warehouse", 0))
	park_count_lbl.text = "Parks: " + str(park_count)
	quarry_count_lbl.text = "Quarries: " + str(summary.get("quarry", 0))
	total_buildings_lbl.text = "Total Constructed: " + str(summary.get("total", 0)) + " Structures"

	# 3. Academic Curriculum
	var m1_prog = clamp(Global.module1_progress, 0, 5)
	var m2_prog = clamp(Global.module2_progress, 0, 5)
	var m3_prog = clamp(Global.module3_progress, 0, 5)
	
	mod1_bar.max_value = 5
	mod1_bar.value = m1_prog
	mod1_lbl.text = "Module 1 (Sequencing): " + str(m1_prog) + "/5"
	
	mod2_bar.max_value = 5
	mod2_bar.value = m2_prog
	mod2_lbl.text = "Module 2 (Loops & Logic): " + str(m2_prog) + "/5"
	
	mod3_bar.max_value = 5
	mod3_bar.value = m3_prog
	mod3_lbl.text = "Module 3 (Functions & Build): " + str(m3_prog) + "/5"

	# Skills tree calculation
	_populate_skills_list()

	# 4. History Logs
	_populate_history_log()

func _populate_skills_list():
	for child in skills_container.get_children():
		child.queue_free()

	var unlocked_count = 0
	var total_skills = Global.skill_unlocked.size()
	
	var display_names = {
		"chop": "Chop Trees",
		"collect": "Collect Resources",
		"deposit": "Deposit Vault",
		"while_loop": "While Loops",
		"if_else": "Conditionals (If/Else)",
		"variables": "Variables Memory",
		"functions": "Custom Functions",
		"scan": "Sensor Scanner",
		"gps": "GPS Coordinates",
		"radar": "Resource Radar",
		"pathfinding": "Autonomous Pathfinding",
		"build_house": "Build Houses",
		"build_road": "Pave Roads",
		"warehouse": "Secondary Warehouses",
		"park": "Public Parks",
		"quarry": "Stone Quarry"
	}

	for skill_id in Global.skill_unlocked.keys():
		var is_unlocked = Global.skill_unlocked.get(skill_id, false)
		if is_unlocked:
			unlocked_count += 1
		
		var row = HBoxContainer.new()
		var check_lbl = Label.new()
		check_lbl.text = "✓ " if is_unlocked else "✗ "
		check_lbl.modulate = Color(0.3, 0.9, 0.4) if is_unlocked else Color(0.6, 0.6, 0.6, 0.5)
		
		var name_lbl = Label.new()
		var nice_name = display_names.get(skill_id, skill_id.capitalize())
		name_lbl.text = nice_name
		name_lbl.modulate = Color(1, 1, 1) if is_unlocked else Color(0.6, 0.6, 0.6, 0.6)
		
		row.add_child(check_lbl)
		row.add_child(name_lbl)
		skills_container.add_child(row)
		
	skills_ratio_lbl.text = "Skills Mastered: " + str(unlocked_count) + " / " + str(total_skills)

func _populate_history_log():
	for child in history_container.get_children():
		child.queue_free()

	var history_items = Global.get_history_entries()
	if history_items.is_empty():
		empty_history_lbl.visible = true
		scroll_history.visible = false
		return
		
	empty_history_lbl.visible = false
	scroll_history.visible = true
	
	for entry in history_items:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.13, 0.22, 0.95)
		card_style.border_color = Color(0.28, 0.26, 0.48, 1)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		# Top row: Level title + Timestamp
		var top_row = HBoxContainer.new()
		var lvl_lbl = Label.new()
		lvl_lbl.text = str(entry.get("level_name", "Execution"))
		lvl_lbl.modulate = Color(0.95, 0.8, 0.2)
		lvl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var mode_lbl = Label.new()
		mode_lbl.text = "[" + str(entry.get("mode", "Code")) + "]"
		mode_lbl.modulate = Color(0.4, 0.7, 1.0)
		
		top_row.add_child(lvl_lbl)
		top_row.add_child(mode_lbl)
		vbox.add_child(top_row)
		
		var time_lbl = Label.new()
		time_lbl.text = str(entry.get("timestamp", ""))
		time_lbl.modulate = Color(0.7, 0.7, 0.7)
		time_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(time_lbl)

		# Code box
		var code_str = str(entry.get("python_code", "")).strip_edges()
		if code_str != "":
			var code_panel = PanelContainer.new()
			var code_bg = StyleBoxFlat.new()
			code_bg.bg_color = Color(0.07, 0.08, 0.14, 1)
			code_bg.set_corner_radius_all(4)
			code_bg.content_margin_left = 8
			code_bg.content_margin_right = 8
			code_bg.content_margin_top = 6
			code_bg.content_margin_bottom = 6
			code_panel.add_theme_stylebox_override("panel", code_bg)
			
			var code_lbl = Label.new()
			code_lbl.text = code_str
			code_lbl.modulate = Color(0.75, 0.9, 0.75)
			code_lbl.add_theme_font_size_override("font_size", 11)
			code_panel.add_child(code_lbl)
			vbox.add_child(code_panel)
			
		card.add_child(vbox)
		history_container.add_child(card)
