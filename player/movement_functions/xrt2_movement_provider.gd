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

## XRT2MovementProvider is a base class for nodes that provide movement
## functionality.
##
## These nodes are designed to work together with a XRT2LocomotionHandler node.

#region Export variables
## If ticked, this movement function is enabled
@export var enabled : bool = true
#endregion

#region Private functions
# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var character_body : CharacterBody3D
	var locomotion_handler : XRT2LocomotionHandler
	var parent = get_parent()
	while parent and not character_body:
		if parent is CharacterBody3D:
			character_body = parent
			for child in parent.get_children():
				if child is XRT2LocomotionHandler:
					locomotion_handler = child
		else:
			parent = parent.get_parent()

	if not character_body:
		warnings.append("This node must have an CharacterBody3D ancestor")
	elif not locomotion_handler:
		warnings.append("Our ancestor CharacterBody3D node must have a XRT2LocomotionHandler node")

	# Return warnings
	return warnings


## Called by our locomotion handler.
func _process_locomotion(locomotion_handler : XRT2LocomotionHandler, character_body : CharacterBody3D, delta : float) -> void:
	# TODO: mark as virtual once supported in Godot (4.6 I think)

	# Implement on extended class.
	# Note: locomotion handler will perform move_and_slide and handle gravity,
	# you should implement code that further adjust velocity for this movement.
	pass
#endregion
