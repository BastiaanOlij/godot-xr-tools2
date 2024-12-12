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

## If [code]true[/code] the player wearing the headset can see the camera.
## Disabling this doesn't effect the desktop view!
@export var show_camera_in_hmd = true:
	set(value):
		show_camera_in_hmd = value
		if is_inside_tree():
			$SpectatorCamera3D/Camera.visible = show_camera_in_hmd


# Material used to show viewport image
var _material : ShaderMaterial

# Viewport texture used to show viewport image
var _viewport_texture : ViewportTexture

# Display on which we show our viewport image
@onready var _display : MeshInstance3D = $SpectatorCamera3D/Camera/CameraDisplay/Display


# Called when the node enters the scene tree for the first time.
func _ready():
	# Only do our layer checks, if in the editor
	if Engine.is_editor_hint():
		if ProjectSettings.get_setting("layer_names/3d_render/layer_2").is_empty():
			ProjectSettings.set_setting("layer_names/3d_render/layer_2", "HMD only")

		if ProjectSettings.get_setting("layer_names/3d_render/layer_3").is_empty():
			ProjectSettings.set_setting("layer_names/3d_render/layer_3", "Spectator only")

		return

	$SpectatorCamera3D/Camera.visible = show_camera_in_hmd

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
