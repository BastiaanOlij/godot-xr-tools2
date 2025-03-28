#-------------------------------------------------------------------------------
# xrt2_hand_pose.gd
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
class_name XRT2HandPose
extends Node3D

## XRTools2 Hand Pose Script
##
## This script properly offsets this node to the given action pose
## related to the collision hand.
## This has to be a child of a [XRT2CollisionHand] node.

## Pose action for our pose. Must be a pose that exists in our OpenXR action map.
## Note, use "aim" and "grip" for your "aim_pose" or "grip_pose" respectively. 
@export var pose_action : String:
	set(value):
		pose_action = value

# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var parent = get_parent()
	if not parent or not parent is XRT2CollisionHand:
		warnings.push_back("This node must be a child of an XRT2CollisionHand node.")

	# Return warnings
	return warnings

func _process(_delta):
	if Engine.is_editor_hint():
		# Can't set this in editor
		return

	if not pose_action:
		return

	var parent = get_parent()
	if parent and parent is XRT2CollisionHand:
		var collision_hand : XRT2CollisionHand = parent
		transform = collision_hand.get_pose_transform(pose_action)
	else:
		transform = Transform3D()
