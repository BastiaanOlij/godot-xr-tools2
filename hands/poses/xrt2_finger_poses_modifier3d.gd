#-------------------------------------------------------------------------------
# xrt2_finger_poses_modifier3d.gd
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
class_name XRT2FingerPosesModifier3D
extends SkeletonModifier3D

## XRTools2 Finger pose modifier Script
##
## This script applies finger positioning based on an XRT2FingerPoses resource.
## This should be placed behind our XRHandModifier3D and/or XRT2HandModifier3D node.

## Base pose data for our fingers
@export var finger_poses: XRT2FingerPoses:
	set(value):
		finger_poses = value

## Open pose data for our fingers,
## Set these for adjusting finger position
## based on trigger input (index finger only)
## and/or grip input (little, ring and middle fingers)
@export var open_finger_poses: XRT2FingerPoses:
	set(value):
		open_finger_poses = value

## Action to use to animate index finger[br]
## [b]Note[/b]: This requires [member finger_poses] and [member open_finger_poses] to be set with an index finger pose!
@export var trigger_action: String = "trigger"

## Action to use to animate bottom 3 fingers[br]
## [b]Note[/b]: This requires [member finger_poses] and [member open_finger_poses] to be set with little, ring, and/or middle finger poses!
@export var grip_action: String = "grip"

## Editor only, test trigger value
@export_range(0.0, 1.0, 0.01) var test_trigger: float = 1.0

## Editor only, test grip value
@export_range(0.0, 1.0, 0.01) var test_grip: float = 1.0


# Adjust properties as needed
func _validate_property(property):
	if property.name in [ "test_trigger", "test_grip" ]:
		if not finger_poses or not open_finger_poses:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage = PROPERTY_USAGE_EDITOR


# Update our finger poses.
func _process_modification() -> void:
	if not finger_poses:
		return

	var skeleton: Skeleton3D = get_skeleton()
	if not skeleton:
		return

	# Find our parent controller
	var parent = get_parent()
	while parent and not parent is XRNode3D and not parent is XRT2CollisionHand and not parent is XRT2GrabPoint:
		parent = parent.get_parent()

	# Check if we have an active hand tracker,
	# if so, we don't need our fallback!
	var tracker: XRControllerTracker
	var hand: int = 0
	if not parent:
		# For debugging only
		hand = 0 if (skeleton.find_bone("LeftHand") >= 0) else 1
	elif parent is XRNode3D:
		var xr_parent: XRNode3D = parent
		if not xr_parent.tracker in [ "left_hand", "right_hand" ]:
			return

		hand = 1 if xr_parent.tracker == "right_hand" else 0
		tracker = XRServer.get_tracker(xr_parent.tracker)
	elif parent is XRT2CollisionHand:
		var xr_parent: XRT2CollisionHand = parent
		hand = xr_parent.hand
		tracker = XRServer.get_tracker("left_hand" if xr_parent.hand == 0 else "right_hand")
	elif parent is XRT2GrabPoint:
		## Prioritise left hand
		hand = 0 if parent.left_hand else 1

	var trigger: float = 1.0
	var grip: float = 1.0

	# Check our tracker for trigger and grip values
	if tracker:
		var trigger_value : Variant = tracker.get_input(trigger_action)
		if trigger_value:
			trigger = trigger_value
		else:
			trigger = 0.0

		var grip_value : Variant = tracker.get_input(grip_action)
		if grip_value:
			grip = grip_value
		else:
			grip = 0.0
	elif Engine.is_editor_hint():
		trigger = test_trigger
		grip = test_grip

	# Now position bones
	var bone_count = skeleton.get_bone_count()
	for i in bone_count:
		var t : Transform3D = skeleton.get_bone_rest(i)

		# We animate based on bone_name.
		var bone_name = skeleton.get_bone_name(i)
		if finger_poses.thumb_enabled and (bone_name == "LeftThumbMetacarpal" or bone_name == "RightThumbMetacarpal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.thumb_spread)
			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), finger_poses.thumb_metacarpal_curl * (1.0 if hand == 1 else -1.0))
		elif finger_poses.thumb_enabled and (bone_name == "LeftThumbProximal" or bone_name == "RightThumbProximal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.thumb_proximal_curl)
		elif finger_poses.thumb_enabled and (bone_name == "LeftThumbDistal" or bone_name == "RightThumbDistal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.thumb_distal_curl)

		elif finger_poses.index_enabled and (bone_name == "LeftIndexProximal" or bone_name == "RightIndexProximal"):
			var spread: float = finger_poses.index_spread
			var curl: float = finger_poses.index_proximal_curl
			if open_finger_poses and open_finger_poses.index_enabled:
				spread = lerp(open_finger_poses.index_spread, spread, trigger)
				curl = lerp(open_finger_poses.index_proximal_curl, curl, trigger)

			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.index_enabled and (bone_name == "LeftIndexIntermediate" or bone_name == "RightIndexIntermediate"):
			var curl: float = finger_poses.index_intermediate_curl
			if open_finger_poses and open_finger_poses.index_enabled:
				curl = lerp(open_finger_poses.index_intermediate_curl, curl, trigger)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.index_enabled and (bone_name == "LeftIndexDistal" or bone_name == "RightIndexDistal"):
			var curl: float = finger_poses.index_distal_curl
			if open_finger_poses and finger_poses.index_enabled:
				curl = lerp(open_finger_poses.index_distal_curl, curl, trigger)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)

		elif finger_poses.middle_enabled and (bone_name == "LeftMiddleProximal" or bone_name == "RightMiddleProximal"):
			var spread: float = finger_poses.middle_spread
			var curl: float = finger_poses.middle_proximal_curl
			if open_finger_poses and finger_poses.middle_enabled:
				spread = lerp(open_finger_poses.middle_spread, spread, grip)
				curl = lerp(open_finger_poses.middle_proximal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.middle_enabled and (bone_name == "LeftMiddleIntermediate" or bone_name == "RightMiddleIntermediate"):
			var curl: float = finger_poses.middle_intermediate_curl
			if open_finger_poses and finger_poses.middle_enabled:
				curl = lerp(open_finger_poses.middle_intermediate_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.middle_enabled and (bone_name == "LeftMiddleDistal" or bone_name == "RightMiddleDistal"):
			var curl: float = finger_poses.middle_distal_curl
			if open_finger_poses and finger_poses.middle_enabled:
				curl = lerp(open_finger_poses.middle_distal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)

		elif finger_poses.ring_enabled and (bone_name == "LeftRingProximal" or bone_name == "RightRingProximal"):
			var spread: float = finger_poses.ring_spread
			var curl: float = finger_poses.ring_proximal_curl
			if open_finger_poses and finger_poses.ring_enabled:
				spread = lerp(open_finger_poses.ring_spread, spread, grip)
				curl = lerp(open_finger_poses.ring_proximal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.ring_enabled and (bone_name == "LeftRingIntermediate" or bone_name == "RightRingIntermediate"):
			var curl: float = finger_poses.ring_intermediate_curl
			if open_finger_poses and finger_poses.ring_enabled:
				curl = lerp(open_finger_poses.ring_intermediate_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.ring_enabled and (bone_name == "LeftRingDistal" or bone_name == "RightRingDistal"):
			var curl: float = finger_poses.ring_distal_curl
			if open_finger_poses and finger_poses.ring_enabled:
				curl = lerp(open_finger_poses.ring_distal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)

		elif finger_poses.little_enabled and (bone_name == "LeftLittleProximal" or bone_name == "RightLittleProximal"):
			var spread: float = finger_poses.little_spread
			var curl: float = finger_poses.little_proximal_curl
			if open_finger_poses and finger_poses.little_enabled:
				spread = lerp(open_finger_poses.little_spread, spread, grip)
				curl = lerp(open_finger_poses.little_proximal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.little_enabled and (bone_name == "LeftLittleIntermediate" or bone_name == "RightLittleIntermediate"):
			var curl: float = finger_poses.little_intermediate_curl
			if open_finger_poses and finger_poses.little_enabled:
				curl = lerp(open_finger_poses.little_intermediate_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)
		elif finger_poses.little_enabled and (bone_name == "LeftLittleDistal" or bone_name == "RightLittleDistal"):
			var curl: float = finger_poses.little_distal_curl
			if open_finger_poses and finger_poses.little_enabled:
				curl = lerp(open_finger_poses.little_distal_curl, curl, grip)

			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), curl)

		else:
			# Don't update our pose
			continue

		skeleton.set_bone_pose(i, t)
