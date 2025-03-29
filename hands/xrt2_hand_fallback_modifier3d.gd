#-------------------------------------------------------------------------------
# xrt2_hand_fallback_modifier3d.gd
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

class_name XRT2HandFallbackModifier3D
extends SkeletonModifier3D

## XRTools2 Hand Fallback modifier Script
##
## This script applies hand position fallback code if hand tracking
## is not available.
## Note: you should position your hand mesh using the palm pose.
## Note: this modifier should come after the XRHandModifier3D node.

## If enabled, we apply the modifier
@export var enabled : bool = true

## Hand for which to get our tracking data
@export_enum("Left","Right") var hand : int = 0

## Action to use to animate index finger
@export var trigger_action : String = "trigger"

## Degrees to which to curl our index finger.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var trigger_curl : float = deg_to_rad(45.0)

## Action to use to animate bottom 3 fingers
@export var grip_action : String = "grip"

## Degrees to which to curl our bottom 3 fingers.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var grip_curl : float = deg_to_rad(70.0)

func _process_modification() -> void:
	# If disabled, ignore our logic.
	if !enabled:
		return

	var skeleton: Skeleton3D = get_skeleton()
	if !skeleton:
		return

	# First check if we have an active hand tracker,
	# if so, we don't need our fallback!
	var hand_tracker : XRHandTracker = XRServer.get_tracker("/user/hand_tracker/left" if hand == 0 \
		else "/user/hand_tracker/right")
	if hand_tracker:
		var pose : XRPose = hand_tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			return

	var trigger : float = 0.0
	var grip : float = 0.0

	# Check our tracker for trigger and grip values
	var tracker : XRControllerTracker = XRServer.get_tracker("left_hand" if hand == 0 \
		else "right_hand")
	if tracker:
		var trigger_value : Variant = tracker.get_input(trigger_action)
		if trigger_value:
			trigger = trigger_value

		var grip_value : Variant = tracker.get_input(grip_action)
		if grip_value:
			grip = grip_value

	# Now position bones
	var bone_count = skeleton.get_bone_count()
	for i in bone_count:
		var t : Transform3D = skeleton.get_bone_rest(i)

		# We animate based on bone_name.
		# For now just hardcoded values but we should
		# replace this with an open/closed pose system.
		var bone_name = skeleton.get_bone_name(i)
		if bone_name == "LeftHand":
			# Offset to center our palm
			t.origin += Vector3(-0.015, 0.0, 0.04)
		elif bone_name == "RightHand":
			# Offset to center our palm
			t.origin += Vector3(0.015, 0.0, 0.04)
		elif bone_name == "LeftIndexDistal" or bone_name == "LeftIndexIntermediate" \
			or bone_name == "RightIndexDistal" or bone_name == "RightIndexIntermediate":
			var r : Transform3D
			t = t * r.rotated(Vector3(1.0, 0.0, 0.0), trigger_curl * trigger)
		elif bone_name == "LeftIndexProximal" or bone_name == "RightIndexProximal":
			var r : Transform3D
			t = t * r.rotated(Vector3(1.0, 0.0, 0.0), deg_to_rad(20.0) * trigger)
		elif bone_name == "LeftMiddleDistal" or bone_name == "LeftMiddleIntermediate" or bone_name == "LeftMiddleProximal" \
			or bone_name == "RightMiddleDistal" or bone_name == "RightMiddleIntermediate" or bone_name == "RightMiddleProximal" \
			or bone_name == "LeftRingDistal" or bone_name == "LeftRingIntermediate" or bone_name == "LeftRingProximal" \
			or bone_name == "RightRingDistal" or bone_name == "RightRingIntermediate" or bone_name == "RightRingProximal" \
			or bone_name == "LeftLittleDistal" or bone_name == "LeftLittleIntermediate" or bone_name == "LeftLittleProximal" \
			or bone_name == "RightLittleDistal" or bone_name == "RightLittleIntermediate" or bone_name == "RightLittleProximal":
			var r : Transform3D
			t = t * r.rotated(Vector3(1.0, 0.0, 0.0), grip_curl * grip)

		skeleton.set_bone_pose(i, t)
