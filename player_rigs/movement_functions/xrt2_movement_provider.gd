#-------------------------------------------------------------------------------
# xrt2_movement_provider.gd
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
class_name XRT2MovementProvider
extends Node3D

## If ticked, this movement function is enabled
@export var enabled : bool = true

@onready var _xr_dynamic_rig : XRT2DynamicPlayerRig = \
	XRT2DynamicPlayerRig.get_xr_dynamic_player_rig(self)


# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var dynamic_rig = XRT2DynamicPlayerRig.get_xr_dynamic_player_rig(self)
	if not dynamic_rig:
		warnings.push_back("This node requires an XRT2DynamicPlayerRig as an anchestor.")

	# Return warnings
	return warnings


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		return

	if _xr_dynamic_rig:
		_xr_dynamic_rig.register_movement_provider(self)


## Called by player characters physics process.
func handle_movement(_character_body : CharacterBody3D, _delta : float):
	# Implement on extended class.
	# Note: player character will perform move_and_slide and handle gravity,
	# you should implement code that further adjust velocity for this movement.
	pass
