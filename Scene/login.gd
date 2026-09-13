extends Control

@onready var email_input = $CenterContainer/PanelContainer/VBoxContainer/EmailInput
@onready var password_input = $CenterContainer/PanelContainer/VBoxContainer/PasswordInput
@onready var accept_dialog = $ErrorDialog

func _ready():
	# Connect signals via code to ensure they work
	# Note: If these are already connected in the Editor, you can delete these two lines
	$CenterContainer/PanelContainer/VBoxContainer/SignupButton.pressed.connect(_on_signup_pressed)
	$CenterContainer/PanelContainer/VBoxContainer/LoginButton.pressed.connect(_on_login_pressed)

func _show_popup(message: String):
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

# --- SIGNUP LOGIC ---
func _on_signup_pressed():
	var email = email_input.text
	var password = password_input.text
	
	print("DEBUG: Sending Signup for ", email)
	var task = Supabase.auth.sign_up(email, password)
	var auth = await task.completed
	
	if auth == null:
		_show_popup("Plugin Error: Task returned null. Check your Global.gd keys!")
		return

	if auth.error == null:
		_show_popup("Success! Now click Login.")
	else:
		# This will print the error object so we can read it in the log
		print("SUPABASE REJECTION: ", auth.error)
		
		# If the message is empty, show the error code instead
		var display_error = str(auth.error)
		if "message" in auth.error and auth.error.message != "":
			display_error = auth.error.message
			
		_show_popup("Signup Error: " + display_error)
		
# --- LOGIN LOGIC ---
# --- LOGIN LOGIC ---
# --- LOGIN LOGIC ---
func _on_login_pressed():
	var email = email_input.text
	var password = password_input.text
	
	if email == "" or password == "":
		_show_popup("Please enter your credentials.")
		return

	# 1. Disable buttons
	$CenterContainer/PanelContainer/VBoxContainer/LoginButton.disabled = true
	$CenterContainer/PanelContainer/VBoxContainer/SignupButton.disabled = true
	print("DEBUG: Attempting Login for: ", email)

	# 2. Directly await the sign_in function
	var auth = await Supabase.auth.sign_in(email, password).completed
	
	if auth.error == null:
		# --- FIXED: Use auth.user instead of Supabase.auth.get_user() ---
		var user = auth.user 
		print("DEBUG: Login Successful! User ID: ", user.id)
		
		# 3. Load the specific cloud data for this user
		await Global.load_game_from_cloud()
		
		print("DEBUG: Scene switching...")
		get_tree().change_scene_to_file("res://Scene/Menu/mainmenu.tscn")
	else:
		# 4. If it fails, re-enable buttons
		$CenterContainer/PanelContainer/VBoxContainer/LoginButton.disabled = false
		$CenterContainer/PanelContainer/VBoxContainer/SignupButton.disabled = false
		
		print("DEBUG: Login Failed. Error: ", auth.error.message)
		_show_popup("Login Error: " + str(auth.error.message))
