@tool
class_name XRT2StartXR
extends Node3D


## XRTools v2 Start XR Class
##
## This class supports the OpenXR interface, and handles the initialization of
## the interface as well as reporting when the user starts and ends the XR
## session (WebXR will be added later).
##
## For OpenXR this class also supports passthrough on compatible devices such
## as the Meta Quest.


## This signal is emitted when XR becomes active. For OpenXR this corresponds
## with the 'openxr_focused_state' signal which occurs when the application
## starts receiving XR input, and for WebXR this corresponds with the
## 'session_started' signal.
signal xr_started

## This signal is emitted when XR ends. For OpenXR this corresponds with the
## 'openxr_visible_state' state which occurs when the application has lost
## XR input focus, and for WebXR this corresponds with the 'session_ended'
## signal.
signal xr_ended

## This signal is emitted if we fail to start XR.
signal xr_failed_to_start

## This signal is emitted if user has requested a pose recenter.
signal xr_pose_recenter

## If true, the XR passthrough is enabled (OpenXR only)
@export var enable_passthrough : bool = false: set = _set_enable_passthrough

## Physics rate multiplier compared to HMD frame rate
@export var physics_rate_multiplier : int = 1

## If non-zero, specifies the target refresh rate
@export var target_refresh_rate : float = 0

## Specify viewport used for HMD output (if unset, main viewport will be used)
@export var hmd_viewport : Viewport


## Current XR interface
var xr_interface : XRInterface

## XR active flag
var xr_active : bool = false

# Current refresh rate
var _current_refresh_rate : float = 0


# Handle auto-initialization when ready
func _ready() -> void:
	if !Engine.is_editor_hint():
		initialize()


## Initialize the XR interface
func initialize() -> bool:
	# Check for OpenXR interface
	xr_interface = XRServer.find_interface('OpenXR')
	if xr_interface:
		return _setup_for_openxr()

	# No XR interface
	xr_interface = null
	print("No XR interface detected")
	xr_failed_to_start.emit()
	return false


# Check for configuration issues
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if physics_rate_multiplier < 1:
		warnings.append("Physics rate multiplier should be at least 1x the HMD rate")

	return warnings


# Perform OpenXR setup
func _setup_for_openxr() -> bool:
	print("OpenXR: Configuring interface")

	var openxr_interface : OpenXRInterface = xr_interface
	if not openxr_interface:
		print("OpenXR: Not an OpenXR interface")
		return false

	# Get our viewport
	var vp : Viewport = hmd_viewport
	if !vp:
		vp = get_viewport()

	# Initialize the OpenXR interface
	if not openxr_interface.is_initialized():
		print("OpenXR: Initializing interface")
		if not openxr_interface.initialize():
			push_error("OpenXR: Failed to initialize")
			xr_failed_to_start.emit()
			return false

	# Connect the OpenXR events
	openxr_interface.session_begun.connect(_on_openxr_session_begun)
	openxr_interface.session_visible.connect(_on_openxr_visible_state)
	openxr_interface.session_focussed.connect(_on_openxr_focused_state)
	openxr_interface.pose_recentered.connect(_on_openxr_pose_recentered)
	# TODO connect to other signals

	# Check for passthrough
	if enable_passthrough and xr_interface.is_passthrough_supported():
		enable_passthrough = xr_interface.start_passthrough()

	# Disable vsync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Switch the viewport to XR
	vp.use_xr = true

	# Enable VRS
	if RenderingServer.get_rendering_device():
		vp.vrs_mode = Viewport.VRS_XR
	elif int(ProjectSettings.get_setting("xr/openxr/foveation_level")) == 0:
		push_warning("OpenXR: Recommend setting Foveation level to High in Project Settings")

	# Report success
	return true


# Handle OpenXR session ready
func _on_openxr_session_begun() -> void:
	print("OpenXR: Session begun")

	# Get the reported refresh rate
	_current_refresh_rate = xr_interface.get_display_refresh_rate()
	if _current_refresh_rate > 0:
		print("OpenXR: Refresh rate reported as ", str(_current_refresh_rate))
	else:
		print("OpenXR: No refresh rate given by XR runtime")

	# Pick a desired refresh rate
	var desired_rate := target_refresh_rate if target_refresh_rate > 0 else _current_refresh_rate
	var available_rates : Array = xr_interface.get_available_display_refresh_rates()
	if available_rates.size() == 0:
		print("OpenXR: Target does not support refresh rate extension")
	elif available_rates.size() == 1:
		print("OpenXR: Target supports only one refresh rate")
	elif desired_rate > 0:
		print("OpenXR: Available refresh rates are ", str(available_rates))
		var rate = _find_closest(available_rates, desired_rate)
		if rate > 0:
			print("OpenXR: Setting refresh rate to ", str(rate))
			xr_interface.set_display_refresh_rate(rate)
			_current_refresh_rate = rate

	# Pick a physics rate
	var active_rate := _current_refresh_rate if _current_refresh_rate > 0 else 144.0
	var physics_rate := int(round(active_rate * physics_rate_multiplier))
	print("Setting physics rate to ", physics_rate)
	Engine.physics_ticks_per_second = physics_rate


# Handle OpenXR visible state
func _on_openxr_visible_state() -> void:
	# Report the XR ending
	if xr_active:
		print("OpenXR: XR ended (visible_state)")
		xr_active = false
		xr_ended.emit()


# Handle OpenXR focused state
func _on_openxr_focused_state() -> void:
	# Report the XR starting
	if not xr_active:
		print("OpenXR: XR started (focused_state)")
		xr_active = true
		xr_started.emit()


# Handle pose recenter
func _on_openxr_pose_recentered() -> void:
	xr_pose_recenter.emit()


# Handle changes to the enable_passthrough property
func _set_enable_passthrough(p_new_value : bool) -> void:
	# Save the new value
	enable_passthrough = p_new_value

	# Only actually start our passthrough if our interface has been instanced
	# if not this will be delayed until initialise is successfully called.
	if xr_interface:
		if enable_passthrough:
			# unset enable_passthrough if we can't start it.
			enable_passthrough = xr_interface.start_passthrough()
		else:
			xr_interface.stop_passthrough()


# Find the closest value in the array to the target
func _find_closest(values : Array, target : float) -> float:
	# Return 0 if no values
	if values.size() == 0:
		return 0.0

	# Find the closest value to the target
	var best : float = values.front()
	for v in values:
		if abs(target - v) < abs(target - best):
			best = v

	# Return the best value
	return best
