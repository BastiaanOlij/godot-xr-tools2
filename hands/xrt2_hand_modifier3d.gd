#-------------------------------------------------------------------------------
# xrt2_hand_modifier3d.gd
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
class_name XRT2HandModifier3D
extends SkeletonModifier3D

## XRTools2 Hand modifier Script
##
## This script applies hand/finger positioning
## If hand tracking is available, we'll apply our tracking data.
## If hand tracking is not available we fallback to trigger/grip input.
## Note: you should position your hand mesh using the palm pose.
## Note: do not combine this with the XRHandModifier3D node.

@export_group("Hand tracking")

## If true we don't use hand tracking data directly but attempt
## to keep our hand mesh dimensions and only apply rotations.
##
## This is important if we use the pose system when picking items
## up or if we're using a fixed sized avatar.
@export var keep_bone_length: bool = true

@export_group("Fallback")

## Action to use to animate index finger
@export var trigger_action : String = "trigger"

## Degrees to which to curl our index finger.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var trigger_curl : float = deg_to_rad(45.0)

## Action to use to animate bottom 3 fingers
@export var grip_action : String = "grip"

## Degrees to which to curl our bottom 3 fingers.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var grip_curl : float = deg_to_rad(70.0)


var _bone_names: PackedStringArray = [
	"Palm",
	"Hand",
	"ThumbMetacarpal",
	"ThumbProximal",
	"ThumbDistal",
	"ThumbTip",
	"IndexMetacarpal",
	"IndexProximal",
	"IndexIntermediate",
	"IndexDistal",
	"IndexTip",
	"MiddleMetacarpal",
	"MiddleProximal",
	"MiddleIntermediate",
	"MiddleDistal",
	"MiddleTip",
	"RingMetacarpal",
	"RingProximal",
	"RingIntermediate",
	"RingDistal",
	"RingTip",
	"LittleMetacarpal",
	"LittleProximal",
	"LittleIntermediate",
	"LittleDistal",
	"LittleTip",
]

var _fixed_position_bones: PackedStringArray = [
	"Palm",
	"Hand",
	"IndexMetacarpal",
	"MiddleMetacarpal",
	"RingMetacarpal",
	"LittleMetacarpal",
]

func _update_on_hand_tracker(skeleton: Skeleton3D, hand_tracker: XRHandTracker) -> void:
	var bone_prefix = "Left" if hand_tracker.hand == XRHandTracker.TRACKER_HAND_LEFT else "Right"

	var joint: int = 0
	var middle_metacarpal_id: int = skeleton.find_bone(bone_prefix + "MiddleMetacarpal")
	var inv_root_transform: Transform3D = hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).inverse()
	for bone_suffix in _bone_names:
		var flags = hand_tracker.get_hand_joint_flags(joint)
		if flags == 0:
			# No tracking data for this joint.
			continue

		var bone_name = bone_prefix + bone_suffix
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			var joint_transform: Transform3D
			if keep_bone_length and bone_suffix in _fixed_position_bones and middle_metacarpal_id >= 0:
				# We offset our palm and wrist bones from our MiddleMetacarpal bone
				joint_transform = inv_root_transform * hand_tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL).orthonormalized()

				var bone_transform: Transform3D = skeleton.get_bone_global_rest(bone_idx)
				var metacarpal_transform: Transform3D = skeleton.get_bone_global_rest(middle_metacarpal_id)
				var offset_transform = metacarpal_transform.inverse() * bone_transform

				joint_transform = joint_transform * offset_transform
			else:
				joint_transform = inv_root_transform * hand_tracker.get_hand_joint_transform(joint)
				if keep_bone_length:
					# Make sure we remove any scaling info
					joint_transform = joint_transform.orthonormalized()

			var parent_idx = skeleton.get_bone_parent(bone_idx)
			if parent_idx >= 0:
				var parent_transform: Transform3D = skeleton.get_bone_global_pose(parent_idx)
				joint_transform = parent_transform.inverse() * joint_transform

			if keep_bone_length and not bone_suffix in _fixed_position_bones:
				# Keep positioning so we retain bone length
				skeleton.set_bone_pose_rotation(bone_idx, joint_transform.basis.get_rotation_quaternion())
			else:
				skeleton.set_bone_pose(bone_idx, joint_transform)

		joint += 1


func _update_on_fallback(skeleton: Skeleton3D, tracker : XRControllerTracker) -> void:
	var trigger : float = 0.0
	var grip : float = 0.0

	# Check our tracker for trigger and grip values
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


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if !skeleton:
		return

	# Find our parent controller
	var parent = get_parent()
	while parent and not parent is XRNode3D and not parent is XRT2CollisionHand:
		parent = parent.get_parent()
	if !parent:
		return

	# Check if we have an active hand tracker,
	# if so, we don't need our fallback!
	var tracker: XRControllerTracker
	if parent is XRNode3D:
		var xr_parent: XRNode3D = parent
		if not xr_parent.tracker in [ "left_hand", "right_hand" ]:
			return

		tracker = XRServer.get_tracker(xr_parent.tracker)
	elif parent is XRT2CollisionHand:
		var collision_hand : XRT2CollisionHand = parent

		# See if we're using a hand tracker
		var hand_tracker: XRHandTracker = collision_hand.get_hand_tracker()
		if hand_tracker:
			_update_on_hand_tracker(skeleton, hand_tracker)
			return

		tracker = XRServer.get_tracker("left_hand" if collision_hand.hand == 0 else "right_hand")

	_update_on_fallback(skeleton, tracker)
