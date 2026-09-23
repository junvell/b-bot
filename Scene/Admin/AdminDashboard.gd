extends Control

# --- NODE REFERENCES ---
@onready var back_button = $RootVBox/HeaderBg/MarginContainer/HeaderBar/BackButton
@onready var admin_label = $RootVBox/HeaderBg/MarginContainer/HeaderBar/AdminLabel
@onready var export_button = $RootVBox/HeaderBg/MarginContainer/HeaderBar/ExportButton

# Analytics bar
@onready var total_students_lbl = $RootVBox/AnalyticsBar/MarginWrap/HBox/TotalStudentsCard/VBox/ValueLabel
@onready var avg_completion_lbl = $RootVBox/AnalyticsBar/MarginWrap/HBox/AvgCompletionCard/VBox/ValueLabel
@onready var total_runs_lbl = $RootVBox/AnalyticsBar/MarginWrap/HBox/TotalRunsCard/VBox/ValueLabel

# Search + list
@onready var search_bar = $RootVBox/SearchBar/MarginWrap/SearchInput
@onready var student_list = $RootVBox/ScrollArea/StudentVBox
@onready var loading_label = $RootVBox/ScrollArea/StudentVBox/LoadingLabel

var _all_students: Array = []

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	export_button.pressed.connect(_on_export_pressed)
	search_bar.text_changed.connect(_on_search_changed)

	# Set admin identity
	var user = Supabase.auth.client
	if user:
		admin_label.text = user.email + "  [ADMIN]"

	_load_students()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scene/Menu/mainmenu.tscn")

# ─────────────────────────────────────────────
#  LOAD ALL STUDENTS
# ─────────────────────────────────────────────
func _load_students():
	loading_label.text = "Loading student data..."
	loading_label.visible = true

	_all_students = await Global.fetch_all_students_from_cloud()

	loading_label.visible = false
	_render_student_list(_all_students)
	_update_analytics(_all_students)

func _update_analytics(students: Array):
	total_students_lbl.text = str(students.size())

	var total_mod_progress: float = 0.0
	var total_runs: int = 0

	for s in students:
		var m1 = clamp(int(s.get("module1_progress", 1)) - 1, 0, 5)
		var m2 = clamp(int(s.get("module2_progress", 1)) - 1, 0, 5)
		var m3 = clamp(int(s.get("module3_progress", 1)) - 1, 0, 5)
		total_mod_progress += (float(m1 + m2 + m3) / 15.0) * 100.0

	avg_completion_lbl.text = (
		"%.1f%%" % (total_mod_progress / students.size()) if students.size() > 0 else "0%"
	)
	# We'll update run count after all histories if needed (simplified here)
	total_runs_lbl.text = "—"

func _render_student_list(students: Array):
	# Clear previous cards (except LoadingLabel)
	for child in student_list.get_children():
		if child.name != "LoadingLabel":
			child.queue_free()

	if students.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No student profiles found in Supabase."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		student_list.add_child(empty_lbl)
		return

	for profile in students:
		_create_student_card(profile)

func _create_student_card(profile: Dictionary):
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.22, 0.95)
	card_style.border_color = Color(0.28, 0.26, 0.48, 1)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Left: Identity + Era
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)

	var email_lbl = Label.new()
	var email = profile.get("email", profile.get("id", "Unknown"))
	email_lbl.text = str(email)
	email_lbl.modulate = Color(0.85, 0.88, 1, 1)
	email_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(email_lbl)

	var era_lbl = Label.new()
	var era = profile.get("current_era", "Rural")
	era_lbl.text = "Era: " + str(era)
	match era:
		"Rural":   era_lbl.modulate = Color(0.4, 0.9, 0.4)
		"Suburban": era_lbl.modulate = Color(0.9, 0.8, 0.2)
		"Urban":    era_lbl.modulate = Color(0.2, 0.8, 1.0)
		"Metropolis": era_lbl.modulate = Color(0.8, 0.2, 1.0)
	era_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(era_lbl)

	# Middle: Module progress
	var progress_vbox = VBoxContainer.new()
	progress_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_vbox.add_theme_constant_override("separation", 3)

	for i in [1, 2, 3]:
		var key = "module%d_progress" % i
		var prog = clamp(int(profile.get(key, 1)) - 1, 0, 5)
		var bar_row = HBoxContainer.new()
		var bar_lbl = Label.new()
		bar_lbl.text = "Mod %d: %d/5" % [i, prog]
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.custom_minimum_size.x = 80
		var bar = ProgressBar.new()
		bar.max_value = 5
		bar.value = prog
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 12
		bar_row.add_child(bar_lbl)
		bar_row.add_child(bar)
		progress_vbox.add_child(bar_row)

	# Right: Skills + Inspect button
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)

	var skills_data = profile.get("skill_data", {})
	var unlocked_count = 0
	if skills_data is Dictionary:
		for k in skills_data.keys():
			if skills_data[k] == true:
				unlocked_count += 1
	var skills_lbl = Label.new()
	skills_lbl.text = "Skills: %d / 16" % unlocked_count
	skills_lbl.modulate = Color(0.9, 0.75, 1.0)
	skills_lbl.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(skills_lbl)

	var inspect_btn = Button.new()
	inspect_btn.text = "INSPECT REPORT ➔"
	inspect_btn.add_theme_font_size_override("font_size", 12)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.22, 0.15, 0.48, 1)
	btn_style.set_corner_radius_all(6)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	inspect_btn.add_theme_stylebox_override("normal", btn_style)
	inspect_btn.pressed.connect(func(): _on_inspect_student(profile))
	right_vbox.add_child(inspect_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(progress_vbox)
	hbox.add_child(right_vbox)
	card.add_child(hbox)
	student_list.add_child(card)

# ─────────────────────────────────────────────
#  SEARCH / FILTER
# ─────────────────────────────────────────────
func _on_search_changed(query: String):
	var q = query.to_lower().strip_edges()
	if q == "":
		_render_student_list(_all_students)
		return
	var filtered: Array = []
	for s in _all_students:
		var email = str(s.get("email", s.get("id", ""))).to_lower()
		if q in email:
			filtered.append(s)
	_render_student_list(filtered)

# ─────────────────────────────────────────────
#  INSPECT A STUDENT
# ─────────────────────────────────────────────
func _on_inspect_student(profile: Dictionary):
	var student_id = str(profile.get("id", ""))
	print("[ADMIN] Inspecting student: ", student_id)

	# Fetch their history
	var history = await Global.fetch_student_history(student_id)

	# Set global inspection state
	Global.is_inspecting = true
	Global.inspecting_student_data = profile
	Global.inspecting_student_history = history

	get_tree().change_scene_to_file("res://Scene/Report/Report.tscn")

# ─────────────────────────────────────────────
#  EXPORT TO CSV
# ─────────────────────────────────────────────
func _on_export_pressed():
	if _all_students.is_empty():
		print("[ADMIN] No student data to export.")
		return

	var csv_lines: Array = []
	csv_lines.append("Email,Era,Money,Wood,Stone,Module1,Module2,Module3,Skills Mastered,City Total")

	for s in _all_students:
		var email = str(s.get("email", s.get("id", "N/A")))
		var era = str(s.get("current_era", "Rural"))
		var money = str(s.get("money", 0))
		var wood = str(s.get("wood", 0))
		var stone = str(s.get("stone", 0))
		var m1 = str(clamp(int(s.get("module1_progress", 1)) - 1, 0, 5))
		var m2 = str(clamp(int(s.get("module2_progress", 1)) - 1, 0, 5))
		var m3 = str(clamp(int(s.get("module3_progress", 1)) - 1, 0, 5))

		var skills_data = s.get("skill_data", {})
		var skill_count = 0
		if skills_data is Dictionary:
			for k in skills_data.keys():
				if skills_data[k] == true:
					skill_count += 1

		var city_map = s.get("city_map", [])
		var city_total = city_map.size() if city_map is Array else 0

		csv_lines.append(",".join([email, era, money, wood, stone, m1, m2, m3, str(skill_count), str(city_total)]))

	var csv_text = "\n".join(csv_lines)

	if OS.has_feature("web"):
		# Web: trigger a browser download
		var buffer = csv_text.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buffer, "b_bot_student_progress.csv", "text/csv")
		print("[ADMIN] CSV download triggered in browser.")
	else:
		# Desktop: write to user:// folder
		var file = FileAccess.open("user://b_bot_student_progress.csv", FileAccess.WRITE)
		if file:
			file.store_string(csv_text)
			file.close()
			print("[ADMIN] CSV exported to: ", OS.get_user_data_dir() + "/b_bot_student_progress.csv")

