#-------------------------------------------------------------------------------
# xrt2_spectator_camera.gd
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
extends Node3D

#region Export variables
## If [code]true[/code] the player wearing the headset can see the camera.
## Disabling this doesn't effect the desktop view!
@export var show_camera_in_hmd = true:
	set(value):
		show_camera_in_hmd = value
		if is_inside_tree():
			_update_show_camera_in_hmd()


## 3D layers to render to our spectator view
@export_flags_3d_render var cull_mask = 5:
	set(new_value):
		cull_mask = new_value
		if is_inside_tree():
			_spectator_camera.cull_mask = cull_mask
#endregion

#region Private variables
# Material used to show viewport image
var _material : ShaderMaterial

# Viewport texture used to show viewport image
var _viewport_texture : ViewportTexture

# Helper variables
@onready var _spectator_camera : Camera3D = $SpectatorCamera3D
@onready var _camera_model : Node3D = $SpectatorCamera3D/Camera
@onready var _display : MeshInstance3D = $SpectatorCamera3D/Camera/CameraDisplay/Display
#endregion

#region Public functions
## Make this camera current
func make_current():
	_spectator_camera.current = true
	_update_show_camera_in_hmd()
#endregion

#region Private functions
func _update_show_camera_in_hmd():
	if _spectator_camera.current or Engine.is_editor_hint():
		_camera_model.visible = show_camera_in_hmd
	else:
		_camera_model.visible = false


# Called when the node enters the scene tree for the first time.
func _ready():
	# Do not run if in the editor
	if Engine.is_editor_hint():
		return

	_spectator_camera.cull_mask = cull_mask
	_update_show_camera_in_hmd()

	var vp : Viewport = get_viewport()
	_material = _display.material_override
	if vp and _material:
		_viewport_texture = vp.get_texture()
		_material.set_shader_parameter("texture_albedo", _viewport_texture)


# Called each frame
func _process(_delta):
	# Do not run if in the editor
	if Engine.is_editor_hint():
		return

	# If not the current camera, no need to do this.
	if not _spectator_camera.current:
		_camera_model.visible = false
		return

	# Adjust our viewport
	if _viewport_texture and _display:
		var size = _viewport_texture.get_size()

		# Note: adjusting scale instead of mesh size
		# prevents rebuilding a new mesh
		var height : float = 0.18
		var width : float = height * size.x / size.y
		if width > 0.38:
			width = 0.38
			height = width * size.y / size.x
		_display.scale = Vector3(width, height, 1.0)

	# Look towards our player
	var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if head_tracker:
		var pose = head_tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			var camera_pos = pose.get_adjusted_transform().origin
			look_at(XRServer.world_origin * camera_pos)
#endregion
