#-------------------------------------------------------------------------------
# xrt2_fade.gd
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
class_name XRT2EffectFade
extends Node3D

## XRTools2 Fade effect
##
## The fade effect can be used to black out the screen and show a message
## to the player.
## This can be used for transitions or to block the view of the user.

#region Export variables
## Fade to black, 0.0 is visible, 1.0 is black.
@export_range(0.0, 1.0, 0.05) var fade : float = 0.0:
	set(value):
		fade = value
		if is_inside_tree():
			_update_fade()

## Message to show when we've faded to black.
@export_multiline var message : String = "":
	set(value):
		message = value
		if is_inside_tree():
			_update_message()
			_update_fade()

## Distance to player to position the message.
@export_range(0.1, 10.0, 0.1) var message_distance = 1.0:
	set(value):
		message_distance = value
		if is_inside_tree():
			_update_message_distance()
#endregion

## Render layers for the fade effect.
@export_flags_3d_render var layers = 2:
	set(value):
		layers = value
		if is_inside_tree():
			_update_layers()
#endregion

#region Private variables
var _screen_quad : MeshInstance3D
var _screen_material : ShaderMaterial
var _message : Label3D
#endregion

#region Private functions
# Update our fade
func _update_fade():
	if not _screen_quad or not _message:
		return

	if fade == 0.0:
		_screen_quad.visible = false
		_message.visible = false
	else:
		_screen_quad.visible = true
		_message.visible = not message.is_empty()
		if _message.visible:
			_message.modulate = Color(1.0, 1.0, 1.0, fade)
			_message.outline_modulate = Color(0.0, 0.0, 0.0, fade)

		if _screen_material:
			_screen_material.set_shader_parameter("alpha", fade)



# Set our fade message.
func _update_message():
	if _message:
		_message.text = message


# Update the distance at which we display our fade message.
func _update_message_distance():
	if _message:
		_message.transform.origin.z = -message_distance


func _update_layers():
	if _screen_quad:
		_screen_quad.layers = layers
	if _message:
		_message.layers = layers


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create our full screen mesh
	var mesh = QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = load("res://addons/godot-xr-tools2/effects/fade/xrt2_fade.gdshader")
	_screen_material.render_priority = 50
	_screen_quad = MeshInstance3D.new()
	_screen_quad.mesh = mesh
	_screen_quad.material_override = _screen_material
	_screen_quad.transform.origin = Vector3(0.0, 0.0, -0.5)
	_screen_quad.visible = false
	add_child(_screen_quad, false, Node.INTERNAL_MODE_BACK)

	# Create our message label
	_message = Label3D.new()
	_message.pixel_size = 0.0015
	_message.no_depth_test = true
	_message.render_priority = 52
	_message.outline_render_priority = 51
	_message.visible = false
	add_child(_message, false, Node.INTERNAL_MODE_BACK)

	_update_message()
	_update_message_distance()
	_update_fade()
	_update_layers()

	if not Engine.is_editor_hint():
		var t : Transform3D = _message.global_transform
		_message.top_level = true
		_message.transform = t



func _process(delta):
	# Don't run this in the editor
	if Engine.is_editor_hint():
		set_process(false)
		return

	if _message.visible:
		var t : Transform3D = global_transform
		var forward : Vector3 = -t.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		t.origin += forward * message_distance
		t = t.looking_at(t.origin + forward)

		_message.transform.basis = _message.transform.basis.slerp(t.basis, delta)
		_message.transform.origin = _message.transform.origin.lerp(t.origin, delta)
#endregion
