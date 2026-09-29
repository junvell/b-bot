extends Control

@onready var email_input = $CenterContainer/PanelContainer/VBoxContainer/EmailInput
@onready var password_input = $CenterContainer/PanelContainer/VBoxContainer/PasswordInput
@onready var accept_dialog = $ErrorDialog
@onready var login_button = $CenterContainer/PanelContainer/VBoxContainer/LoginButton
@onready var signup_button = $CenterContainer/PanelContainer/VBoxContainer/SignupButton

func _ready():
	# Ensure clean auth state when arriving at the login screen
	Supabase.auth.client = null
	Supabase.auth._auth = ""
	
	signup_button.pressed.connect(_on_signup_pressed)
	login_button.pressed.connect(_on_login_pressed)

func _show_popup(message: String):
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

func is_valid_email(email: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return regex.search(email) != null

func _get_error_message(err) -> String:
	if err == null:
		return "Unknown error."
	if "hint" in err and err.hint != "" and err.hint != "empty" and err.hint != "(undefined)":
		return str(err.hint)
	if "message" in err and err.message != "" and err.message != "empty" and err.message != "(undefined)":
		return str(err.message)
	if "type" in err and err.type != "" and err.type != "empty" and err.type != "(undefined)":
		return str(err.type)
	if "_error" in err and err._error is Dictionary:
		if err._error.has("error_description"):
			return str(err._error["error_description"])
		if err._error.has("message"):
			return str(err._error["message"])
		if err._error.has("msg"):
			return str(err._error["msg"])
	return str(err)

# --- SIGNUP LOGIC ---
func _on_signup_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	if email == "" or password == "":
		_show_popup("Please enter an email and password.")
		return
	
	if not is_valid_email(email):
		_show_popup("Signup Error: Please enter a valid email address.")
		return
		
	if password.length() < 6:
		_show_popup("Signup Error: Password must be at least 6 characters.")
		return

	login_button.disabled = true
	signup_button.disabled = true
	
	print("DEBUG: Sending Signup for ", email)
	var task = Supabase.auth.sign_up(email, password)
	var auth = await task.completed
	
	login_button.disabled = false
	signup_button.disabled = false
	
	if auth == null:
		_show_popup("Plugin Error: Task returned null. Check your Global.gd keys!")
		return

	if auth.error == null:
		var user = auth.user
		# Check if Supabase auto-logged in (email confirmation disabled in Supabase)
		if user != null and user.access_token != "":
			print("DEBUG: Auto-login after Signup successful! User ID: ", user.id)
			_show_popup("Account created successfully! Loading your city...")
			login_button.disabled = true
			signup_button.disabled = true
			await Global.load_game_from_cloud()
			get_tree().change_scene_to_file("res://Scene/Menu/mainmenu.tscn")
		else:
			# Supabase has email confirmation enabled
			_show_popup("Account created successfully!\n\nNote: If 'Confirm email' is enabled in your Supabase project, please check your inbox and verify your email before clicking Login.")
	else:
		print("SUPABASE REJECTION: ", auth.error)
		var display_error = _get_error_message(auth.error)
		_show_popup("Signup Error: " + display_error)

# --- LOGIN LOGIC ---
func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	if email == "" or password == "":
		_show_popup("Please enter your credentials.")
		return

	# 1. Disable buttons
	login_button.disabled = true
	signup_button.disabled = true
	print("DEBUG: Attempting Login for: ", email)

	# 2. Directly await the sign_in function
	var auth = await Supabase.auth.sign_in(email, password).completed
	
	if auth == null:
		login_button.disabled = false
		signup_button.disabled = false
		_show_popup("Plugin Error: Task returned null. Check your internet connection or Global.gd keys.")
		return
	
	if auth.error == null:
		var user = auth.user 
		if user == null:
			user = Supabase.auth.client
			
		if user != null:
			print("DEBUG: Login Successful! User ID: ", user.id)
			await Global.load_game_from_cloud()
			print("DEBUG: Scene switching...")
			get_tree().change_scene_to_file("res://Scene/Menu/mainmenu.tscn")
		else:
			login_button.disabled = false
			signup_button.disabled = false
			_show_popup("Login Error: Could not retrieve user session.")
	else:
		# 4. If it fails, re-enable buttons
		login_button.disabled = false
		signup_button.disabled = false
		
		var error_msg = _get_error_message(auth.error)
		print("DEBUG: Login Failed. Error: ", error_msg)
		if "email not confirmed" in error_msg.to_lower():
			_show_popup("Login Error: Email not confirmed yet!\n\nPlease check your email inbox to verify your account, or disable 'Confirm email' in your Supabase Dashboard under Authentication -> Providers -> Email.")
		elif "invalid login credentials" in error_msg.to_lower() or "invalid_grant" in error_msg.to_lower():
			_show_popup("Login Error: Incorrect email or password.")
		else:
			_show_popup("Login Error: " + error_msg)
