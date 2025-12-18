#-------------------------------------------------------------------------------
# xrt2_start_xr.gd
#-------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2024-present Bastiaan Olij, Malcolm A Nixon and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#-------------------------------------------------------------------------------

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

## Physics rate multiplier compared to HMD frame rate
@export var physics_rate_multiplier : int = 1

## If non-zero, specifies the target refresh rate
@export var target_refresh_rate : float = 0

## Specify viewport used for HMD output (if unset, main viewport will be used)
@export var hmd_viewport : Viewport


# Our singleton (there shall be only one!)
static var _singleton : XRT2StartXR

# Current XR interface
var _xr_interface : XRInterface

# XR active flag (there shall be only one!)
var _xr_active : bool = false

# Current refresh rate
var _current_refresh_rate : float = 0


# Get access to this from anywhere
static func get_singleton() -> XRT2StartXR:
	return _singleton


static func is_xr_active() -> bool:
	if _singleton:
		return _singleton._xr_active
	else:
		return false


static func get_xr_interface() -> XRInterface:
	if _singleton:
		return _singleton._xr_interface
	else:
		return null


func get_xr_viewport() -> Viewport:
	if hmd_viewport:
		return hmd_viewport

	return get_viewport()


# Handle auto-initialization when ready
func _ready() -> void:
	if !Engine.is_editor_hint():
		if _singleton:
			push_error("There should be only one StartXR node")
			return

		_singleton = self
		initialize()


func _exit_tree():
	if _singleton:
		_singleton = null

		if _xr_interface:
			# TODO Shutdown XR
			pass

## Initialize the XR interface
func initialize() -> bool:
	# Check for OpenXR interface
	_xr_interface = XRServer.find_interface('OpenXR')
	if _xr_interface:
		return _setup_for_openxr()

	# TODO: re-introduce webxr

	# No XR interface
	_xr_interface = null
	print("No XR interface detected")
	xr_failed_to_start.emit()
	return false


## Return our reference space
func get_play_area_mode() -> XRInterface.PlayAreaMode:
	if not _xr_interface:
		return XRInterface.XR_PLAY_AREA_STAGE

	# Don't completely trust all XR interfaces, so vetting this...
	if _xr_interface.xr_play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		return _xr_interface.xr_play_area_mode
	elif _xr_interface.xr_play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
		return _xr_interface.xr_play_area_mode
	else:
		return XRInterface.XR_PLAY_AREA_STAGE


# Check for configuration issues
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if physics_rate_multiplier < 1:
		warnings.append("Physics rate multiplier should be at least 1x the HMD rate")

	return warnings


# Perform OpenXR setup
func _setup_for_openxr() -> bool:
	print("OpenXR: Configuring interface")

	var openxr_interface : OpenXRInterface = _xr_interface
	if not openxr_interface:
		print("OpenXR: Not an OpenXR interface")
		return false

	# Get our viewport
	var vp : Viewport = get_xr_viewport()

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
	# TODO: connect to other signals

	# TODO: Re-implement passthrough logic

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

	var openxr_interface : OpenXRInterface = _xr_interface
	if not openxr_interface:
		# This should not be possible!
		print("OpenXR: Not an OpenXR interface")
		return

	# Get the reported refresh rate
	_current_refresh_rate = openxr_interface.get_display_refresh_rate()
	if _current_refresh_rate > 0:
		print("OpenXR: Refresh rate reported as ", str(_current_refresh_rate))
	else:
		print("OpenXR: No refresh rate given by XR runtime")

	# Pick a desired refresh rate
	var desired_rate := target_refresh_rate if target_refresh_rate > 0 else _current_refresh_rate
	var available_rates : Array = openxr_interface.get_available_display_refresh_rates()
	if available_rates.size() == 0:
		print("OpenXR: Target does not support refresh rate extension")
	elif available_rates.size() == 1:
		print("OpenXR: Target supports only one refresh rate")
	elif desired_rate > 0:
		print("OpenXR: Available refresh rates are ", str(available_rates))
		var rate = _find_closest(available_rates, desired_rate)
		if rate > 0:
			print("OpenXR: Setting refresh rate to ", str(rate))
			openxr_interface.set_display_refresh_rate(rate)
			_current_refresh_rate = rate

	# Pick a physics rate
	var active_rate := _current_refresh_rate if _current_refresh_rate > 0 else 144.0
	var physics_rate := int(round(active_rate * physics_rate_multiplier))
	print("Setting physics rate to ", physics_rate)
	Engine.physics_ticks_per_second = physics_rate


# Handle OpenXR visible state
func _on_openxr_visible_state() -> void:
	# Report the XR ending
	if _xr_active:
		print("OpenXR: XR ended (visible_state)")
		_xr_active = false
		xr_ended.emit()


# Handle OpenXR focused state
func _on_openxr_focused_state() -> void:
	# Report the XR starting
	if not _xr_active:
		print("OpenXR: XR started (focused_state)")
		_xr_active = true
		xr_started.emit()


# Handle pose recenter
func _on_openxr_pose_recentered() -> void:
	xr_pose_recenter.emit()


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
