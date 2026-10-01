@tool
extends BaseTask
class_name DatabaseTask

func match_code(code : int) -> int:
	match code:
		SupabaseQuery.REQUESTS.INSERT: return HTTPClient.METHOD_POST
		SupabaseQuery.REQUESTS.SELECT: return HTTPClient.METHOD_GET
		SupabaseQuery.REQUESTS.UPDATE: return HTTPClient.METHOD_PATCH
		SupabaseQuery.REQUESTS.DELETE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_POST

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, handler: HTTPRequest) -> void:
	# 1. Get the raw string
	var raw_string = body.get_string_from_utf8()
	
	# 2. DEBUG: Print the first 50 characters to see what we actually got
	# print("[DEBUG] Response Code: ", response_code)

	# 3. Handle empty or null bodies
	if raw_string == "" or raw_string == "null":
		complete(null)
		handler.queue_free()
		return

	# 4. Safe JSON Parsing
	var json = JSON.new()
	var err = json.parse(raw_string)
	
	if err != OK:
		# Catch JSON failure to prevent crash
		printerr("[DATABASE] Failed to parse JSON: ", json.get_error_message())
		complete(null, SupabaseDatabaseError.new({
			"message": "JSON Parse Failure", 
			"details": "The server response was not valid JSON."
		}))
	else:
		var result_body = json.get_data()
		if response_code < 300:
			complete(result_body)
		else:
			var supabase_error : SupabaseDatabaseError = SupabaseDatabaseError.new(result_body)
			complete(null, supabase_error)
			
	handler.queue_free()

func complete(_data = null, _error : SupabaseDatabaseError = null) -> void:
	super._complete(_data, _error)
