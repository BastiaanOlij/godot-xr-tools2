#-------------------------------------------------------------------------------
# xrt2_collision_hand_offset.gd
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


class_name XRT2CollisionHandOffset
extends Node3D

## XRTools2 Collision Hand Offset Script
##
## This script applies the movement offset of a [XR2CollisionHand] object
## to another node tree. This is currently important due to the split in
## hand action poses and hand tracking, or between hand action poses.
## We may fix this in Godot itself some day so we can share a root node.

@export var follow_node : XRT2CollisionHand

# Called when the node enters the scene tree for the first time.
func _ready():
	# Run early, but after XRT2CollisionHand
	process_physics_priority = -89

# Handle physics processing
func _physics_process(_delta):
	if follow_node:
		var follow_parent = follow_node.get_parent()
		if follow_parent:
			# XRT2CollisionHand has top level enabled,
			# so this transform is in global space.
			var t : Transform3D = follow_node.transform

			# We want our local transform.
			t = follow_parent.global_transform.inverse() * t

			# And now adjust our position to our new orientation.
			t.origin = get_parent().global_basis.inverse() * follow_parent.global_basis * t.origin

			# And use this.
			transform = t
