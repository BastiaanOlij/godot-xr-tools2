#-------------------------------------------------------------------------------
# xrt2_stage_base.gd
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
class_name XRT2StageBase
extends Node3D

#region Signals
## This signal is used to request the staging transition to the main-menu
## scene. Developers should use [method exit_to_main_menu] rather than
## emitting this signal directly.
signal request_exit_to_main_menu

## This signal is used to request the staging transition to the specified
## scene. Developers should use [method load_scene] rather than emitting
## this signal directly.
##
## The [param user_data] parameter is passed through staging to the new scenes.
signal request_load_scene(p_scene_path, user_data)

## This signal is used to request the staging reload this scene. Developers
## should use [method reset_scene] rather than emitting this signal directly.
##
## The [param user_data] parameter is passed through staging to the new scenes.
signal request_reset_scene(user_data)
#endregion

#region Private variables
# XR Origin related to our scene
var _origin: XROrigin3D

# XR Camera related to our scene
var _camera : XRCamera3D
#endregion

# TODO update documentation for entry points, there are differences with how 
# this worked in XR Tools 2 around centering the player

#region Public functions
## Make our origin and camera the current entries
func make_current():
	# Make our camera current
	if _camera:
		_camera.current = true

	# Make our origin current
	if _origin:
		_origin.current = true


## This is called after the scene is loaded and added to our scene tree
func scene_loaded(user_data = null) -> void:
	make_current()


## This is called once our scene has become fully visible
func scene_visible(user_data = null) -> void:
	# Implement on extended class
	pass


## This is called prior to our scene becoming unloaded
func scene_pre_exiting(user_data = null) -> void:
	# Implement on extended class
	pass


## This is called just before our scene is removed from the scene tree
func scene_exiting(user_data = null) -> void:
	# Implement on extended class
	pass


## Called when user has requested pose recenter
func pose_recentered():
	# Implement on extended class
	pass


## Call this to exit back to main menu
func exit_to_main_menu() -> void:
	request_exit_to_main_menu.emit()


## Call this to queue loading a new scene
func load_scene(p_scene_path : String, user_data = null) -> void:
	request_load_scene.emit(p_scene_path, user_data)


## Call this to reset the current scene
func reset_scene(user_data = null) -> void:
	request_reset_scene.emit(user_data)
#endregion

#region Private functions
# Find our XROrigin3D node
func _find_xr_origin(node : Node3D) -> XROrigin3D:
	for child in node.get_children():
		if child is XROrigin3D:
			# Found it!
			return child
		elif child is Node3D:
			var origin_node = _find_xr_origin(child)
			if origin_node:
				return origin_node

	# Could not find it
	return null


func _find_xr_camera(origin: XROrigin3D) -> XRCamera3D:
	if origin:
		for child in origin.get_children():
			if child is XRCamera3D:
				return child

	# Could not find it
	return null


# Verifies our staging has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Report origin not found
	var origin: XROrigin3D = _find_xr_origin(self)
	if not origin:
		warnings.append("This scene must have an XROrigin3D node")
	else:
		# Report origin not found
		if not _find_xr_camera(origin):
			warnings.append("This scene must have an XRCamera3D node")

	# Return warnings
	return warnings


func _ready() -> void:
	# Do not run if in the editor
	if Engine.is_editor_hint():
		return

	# Find our origi.
	_origin = _find_xr_origin(self)
	if not _origin:
		push_error("Missing XROrigin3D in stage.")
	else:
		_camera = _find_xr_camera(_origin)

	if not _camera:
		push_error("Missing XRCamera3D in stage.")
#endregion
