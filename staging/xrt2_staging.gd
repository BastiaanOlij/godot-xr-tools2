@tool
class_name XRT2Staging
extends Node3D

## Main scene file
@export_file('*.tscn') var main_scene : String

## If true, the player is prompted to continue
@export var prompt_for_continue : bool = false

## The current scene
var _current_scene : XRT2StageBase

## The current scene path
var _current_scene_path : String

# Tween for fading
var _tween : Tween

# Node helpers
@onready var _fade : Node3D = $Fade
@onready var _xr_origin : XROrigin3D = $Player/XROrigin3D
@onready var _xr_camera : XRCamera3D = $Player/XROrigin3D/XRCamera3D
@onready var _loading_screen : Node3D = $LoadingScreen
@onready var _scene : Node3D = $Scene
@onready var _start_xr : XRT2StartXR = $StartXR

# Misc
var _is_loading : bool = false
var _must_prompt_for_continue = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do not initialise if in the editor
	if Engine.is_editor_hint():
		return

	# We start by loading our main level scene
	load_scene(main_scene)


# Verifies our staging has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Report main scene not specified
	if main_scene.is_empty():
		warnings.append("No main scene selected")

	# Report main scene invalid
	elif !FileAccess.file_exists(main_scene):
		warnings.append("Main scene doesn't exist")

	# Return warnings
	return warnings


## This function loads the [param p_scene_path] scene file.
##
## The [param user_data] parameter contains optional data passed from the old
## scene to the new scene.
##
## See [method XRT2StageBase.scene_loaded] for details on how to implement
## advanced scene-switching.
func load_scene(p_scene_path : String, user_data = null) -> void:
	# Do not load if in the editor
	if Engine.is_editor_hint():
		return

	# We're already in the process of loading a new scene
	if _is_loading:
		print("Already processing scene switching!")
		return

	# While we're loading a new scene..
	_is_loading = true

	# Start the threaded loading of the scene. If the scene is already cached
	# then this will finish immediately with THREAD_LOAD_LOADED
	ResourceLoader.load_threaded_request(p_scene_path)

	# If a current scene is visible then fade it out and unload it.
	if _current_scene:
		# Report pre-exiting and remove the scene signals
		_current_scene.scene_pre_exiting(user_data)
		_remove_signals(_current_scene)

		# Fade to black
		if _tween:
			_tween.kill()
		_tween = get_tree().create_tween()
		_tween.tween_method(_set_fade, 0.0, 1.0, 1.0)
		await _tween.finished

		# Now we remove our scene
		_current_scene.scene_exiting(user_data)
		_scene.remove_child(_current_scene)
		_current_scene.queue_free()
		_current_scene = null

	# If a continue-prompt is desired or the new scene has not finished
	# loading, then switch to the loading screen.
	if prompt_for_continue or _must_prompt_for_continue or \
		ResourceLoader.load_threaded_get_status(p_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:

		# Make our loading screen visible again and reset some stuff
		_xr_origin.set_process_internal(true)
		_xr_origin.current = true
		_xr_camera.current = true
		_loading_screen.progress = 0.0
		_loading_screen.enable_press_to_continue = false
		_loading_screen.follow_camera_enabled = true
		_loading_screen.visible = true

		# Recenter our pose, will only work on Stage,
		# we can't trigger a recenter in local or local floor modes
		# and this will be ignored
		_on_xr_pose_recenter()

		# Fade to visible
		if _tween:
			_tween.kill()
		_tween = get_tree().create_tween()
		_tween.tween_method(_set_fade, 1.0, 0.0, 1.0)
		await _tween.finished

	# If the loading screen is visible then show the progress and optionally
	# wait for the continue. Once done fade out the loading screen.
	if _loading_screen.visible:
		# Loop waiting for the scene to load
		var res : ResourceLoader.ThreadLoadStatus
		while true:
			var progress := []
			res = ResourceLoader.load_threaded_get_status(p_scene_path, progress)
			if res != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				break;

			_loading_screen.progress = progress[0]
			await get_tree().create_timer(0.1).timeout

		# Handle load error
		if res != ResourceLoader.THREAD_LOAD_LOADED:
			# Report the error to the log and console
			push_error("Error ", res, " loading resource ", p_scene_path)

			# Halt if running in the debugger
			# gdlint:ignore=expression-not-assigned
			breakpoint

			# Terminate with a non-zero error code to indicate failure
			get_tree().quit(1)

		# Wait for user to be ready
		if prompt_for_continue or _must_prompt_for_continue:
			_loading_screen.enable_press_to_continue = true
			await _loading_screen.continue_pressed

		# Now that we've prompted, we don't have to until user takes off headset
		_must_prompt_for_continue = false

		# Fade to black
		if _tween:
			_tween.kill()
		_tween = get_tree().create_tween()
		_tween.tween_method(_set_fade, 0.0, 1.0, 1.0)
		await _tween.finished

		# Hide our loading screen
		_loading_screen.visible = false
		_loading_screen.follow_camera_enabled = false

	# Get the loaded scene
	var new_scene : PackedScene = ResourceLoader.load_threaded_get(p_scene_path)

	# Setup our new scene
	_current_scene = new_scene.instantiate()
	_current_scene_path = p_scene_path
	_scene.add_child(_current_scene)
	_add_signals(_current_scene)

	# We create a small delay here to give tracking some time to update our nodes...
	await get_tree().create_timer(0.1).timeout
	_current_scene.scene_loaded(user_data)

	# Fade to visible
	if _tween:
		_tween.kill()
	_tween = get_tree().create_tween()
	_tween.tween_method(_set_fade, 1.0, 0.0, 1.0)
	await _tween.finished

	# Report new scene visible
	_current_scene.scene_visible(user_data)

	# And we're done.
	_is_loading = false


# Updates fade setting, callback for tweening
func _set_fade(p_value : float) -> void:
	_fade.fade = p_value


# Add signals to our scene
func _add_signals(p_scene : XRT2StageBase):
	p_scene.request_exit_to_main_menu.connect(_on_exit_to_main_menu)
	p_scene.request_load_scene.connect(_on_load_scene)
	p_scene.request_reset_scene.connect(_on_reset_scene)


# Remove signals from our scene
func _remove_signals(p_scene : XRT2StageBase):
	p_scene.request_exit_to_main_menu.disconnect(_on_exit_to_main_menu)
	p_scene.request_load_scene.disconnect(_on_load_scene)
	p_scene.request_reset_scene.disconnect(_on_reset_scene)


# Return to the main scene
func _on_exit_to_main_menu():
	load_scene(main_scene)


# Change to a new scene
func _on_load_scene(p_scene_path : String, user_data):
	load_scene(p_scene_path, user_data)


# Reload the current scene
func _on_reset_scene(user_data):
	load_scene(_current_scene_path, user_data)


# Handle user requesting a recenter
func _on_xr_pose_recenter():
	if not _is_loading:
		return

	var play_area_mode : XRInterface.PlayAreaMode = _start_xr.get_play_area_mode()
	if play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		# This is already handled by the headset, no need to do more!
		pass
	elif play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
		# This is already handled by the headset, we ignore the height
		pass
	else:
		# Center our player on the XROrigin3D node.
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

	# Reset origin
	_xr_origin.transform = Transform3D()


func _on_xr_ended():
	# Focus lost
	_must_prompt_for_continue = true
