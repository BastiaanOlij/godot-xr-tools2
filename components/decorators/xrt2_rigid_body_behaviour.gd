#-------------------------------------------------------------------------------
# xrt2_rigid_body_behaviour.gd
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
class_name XRT2RigidBodyBehaviour
extends Node

## XRT2RigidBodyBehaviour is a decorator node for RigidBody3D
## and allows us to define additional behaviour characteristics
## when this object is being held by the player.

## If [code]true[/code] and this object is picked up,
## the object is centered on the first hand that picks
## the object up.
## If [code]false[/code] both hands equally effect
## the positioning.
@export var pivot_on_primary: bool = false

static func get_behaviour_node(p_for: Node3D) -> XRT2RigidBodyBehaviour:
	if p_for is RigidBody3D or p_for is PhysicalBone3D:
		for child in p_for.get_children():
			if child is XRT2RigidBodyBehaviour:
				return child

	return null

## Return any warnings on this node
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray

	var parent = get_parent()
	if not parent or not (parent is RigidBody3D or parent is PhysicalBone3D):
		warnings.push_back("This node must be a child of a RigidBody3D or PhysicalBone3D node!")

	return warnings
