# xrt2_hold_button.gd
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
class_name XRT2HoldButton
extends Node3D

signal pressed

## Enable our button
@export var enabled : bool = false:
	set(value):
		if enabled == value:
			return

		enabled = value
		if is_inside_tree():
			_update_enabled()

## Action in action map and/or input map that triggers
@export var activate_action : String = "trigger_click"

## Duration action must be pressed
@export var hold_time : float = 2.0

## Color our our visualisation
@export var color : Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		color = value
		if is_inside_tree():
			_update_color()

## Size
@export var size : Vector2 = Vector2(1.0, 1.0):
	set(value):
		size = value
		if is_inside_tree():
			_update_size()


var time_held = 0.0
var pressed_trigger = true

var material : ShaderMaterial


func _update_enabled() -> void:
	if !Engine.is_editor_hint():
		_set_time_held(0.0)
		set_process(enabled)


func _set_time_held(p_time_held) -> void:
	time_held = p_time_held
	if material:
		$Visualise.visible = time_held > 0.0
		material.set_shader_parameter("value", time_held/hold_time)


func _update_color() -> void:
	if material:
		material.set_shader_parameter("albedo", color)

func _update_size() -> void:
	if material: # Note, material won't be set until after we setup our scene
		var mesh : QuadMesh = $Visualise.mesh
		if mesh.size != size:
			mesh.size = size

			# updating the size will unset our material, so reset it
			$Visualise.material_override = material

func _ready() -> void:
	material = $Visualise.material_override

	if !Engine.is_editor_hint():
		_set_time_held(0.0)

	_update_enabled()
	_update_color()
	_update_size()


func _process(delta) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	if !enabled:
		set_process(false)
		return

	var button_pressed = false
	
	if InputMap.has_action(activate_action) and Input.is_action_pressed(activate_action):
		button_pressed = true

	if !button_pressed:
		# We check all trackers
		var controllers = XRServer.get_trackers(XRServer.TRACKER_CONTROLLER)
		for tracker_name in controllers:
			var tracker : XRPositionalTracker = controllers[tracker_name]
			if tracker.get_input(activate_action):
				button_pressed = true

	if button_pressed:
		_set_time_held(time_held + delta)
		if !pressed_trigger and time_held > hold_time:
			# Prevent multiple emits
			pressed_trigger = true
			pressed.emit()
	else:
		pressed_trigger = false
		_set_time_held(max(0.0, time_held - delta))
