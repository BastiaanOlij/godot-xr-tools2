# xrt2_2d_ui.gd
#
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

@tool
extends Node3D

@export var screen_size : Vector2 = Vector2(1.0, 1.0):
	set(value):
		screen_size = value
		if is_inside_tree():
			_update_screen_size()

# Node helpers
@onready var _origin : Node3D = $FollowXROrigin3D
@onready var _composition_layer : OpenXRCompositionLayerQuad = $FollowXROrigin3D/OpenXRCompositionLayerQuad


# Called when our screen size was changed
func _update_screen_size() -> void:
	_composition_layer.quad_size = screen_size


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_screen_size()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	# Need to reposition our quad so its local transform matches our world origin
	# as it is rendered on our compositor
	_origin.global_transform = XRServer.world_origin
	_composition_layer.global_transform = global_transform
