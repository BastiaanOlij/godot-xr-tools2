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

class_name XRT2FingerPosesModifier3D
extends SkeletonModifier3D

## XRTools2 Finger pose modifier Script
##
## This script applies finger positioning based on an XRT2FingerPoses resource.
## This should be placed behind our XRHandModifier3D and/or XRT2HandFallbackModifier3D node.

@export var finger_poses: XRT2FingerPoses:
	set(value):
		finger_poses = value

## Action to use to animate index finger
@export var trigger_action : String = "trigger"

## Action to use to animate bottom 3 fingers
@export var grip_action : String = "grip"

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
	if not parent:
		return

	# Check if we have an active hand tracker,
	# if so, we don't need our fallback!
	var tracker: XRControllerTracker
	var hand: int = 0
	if parent is XRNode3D:
		var xr_parent: XRNode3D = parent
		if not xr_parent.tracker in [ "left_hand", "right_hand" ]:
			return

		hand = 1 if xr_parent.tracker == "right_hand" else 0
		tracker = XRServer.get_tracker(xr_parent.tracker)
	elif parent is XRT2CollisionHand:
		var xr_parent: XRT2CollisionHand = parent
		if xr_parent.get_is_hand_tracking():
			return
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

		var grip_value : Variant = tracker.get_input(grip_action)
		if grip_value:
			grip = grip_value

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

		elif finger_poses.index_mode > 0 and (bone_name == "LeftIndexProximal" or bone_name == "RightIndexProximal"):
			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), finger_poses.index_spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.index_proximal_curl * (trigger if finger_poses.index_mode == 2 else 1.0))
		elif finger_poses.index_mode > 0 and (bone_name == "LeftIndexIntermediate" or bone_name == "RightIndexIntermediate"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.index_intermediate_curl * (trigger if finger_poses.index_mode == 2 else 1.0))
		elif finger_poses.index_mode > 0 and (bone_name == "LeftIndexDistal" or bone_name == "RightIndexDistal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.index_distal_curl * (trigger if finger_poses.index_mode == 2 else 1.0))

		elif finger_poses.middle_mode > 0 and (bone_name == "LeftMiddleProximal" or bone_name == "RightMiddleProximal"):
			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), finger_poses.middle_spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.middle_proximal_curl * (grip if finger_poses.middle_mode == 2 else 1.0))
		elif finger_poses.middle_mode > 0 and (bone_name == "LeftMiddleIntermediate" or bone_name == "RightMiddleIntermediate"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.middle_intermediate_curl * (grip if finger_poses.middle_mode == 2 else 1.0))
		elif finger_poses.middle_mode > 0 and (bone_name == "LeftMiddleDistal" or bone_name == "RightMiddleDistal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.middle_distal_curl * (grip if finger_poses.middle_mode == 2 else 1.0))

		elif finger_poses.ring_mode > 0 and (bone_name == "LeftRingProximal" or bone_name == "RightRingProximal"):
			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), finger_poses.ring_spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.ring_proximal_curl * (grip if finger_poses.ring_mode == 2 else 1.0))
		elif finger_poses.ring_mode > 0 and (bone_name == "LeftRingIntermediate" or bone_name == "RightRingIntermediate"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.ring_intermediate_curl * (grip if finger_poses.ring_mode == 2 else 1.0))
		elif finger_poses.ring_mode > 0 and (bone_name == "LeftRingDistal" or bone_name == "RightRingDistal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.ring_distal_curl * (grip if finger_poses.ring_mode == 2 else 1.0))

		elif finger_poses.pinky_mode > 0 and (bone_name == "LeftLittleProximal" or bone_name == "RightLittleProximal"):
			t.basis = t.basis.rotated(Vector3(0.0, 0.0, 1.0), finger_poses.pinky_spread * (1.0 if hand == 1 else -1.0))
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.pinky_proximal_curl * (grip if finger_poses.pinky_mode == 2 else 1.0))
		elif finger_poses.pinky_mode > 0 and (bone_name == "LeftLittleIntermediate" or bone_name == "RightLittleIntermediate"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.pinky_intermediate_curl * (grip if finger_poses.pinky_mode == 2 else 1.0))
		elif finger_poses.pinky_mode > 0 and (bone_name == "LeftLittleDistal" or bone_name == "RightLittleDistal"):
			t.basis = t.basis.rotated(Vector3(1.0, 0.0, 0.0), finger_poses.pinky_distal_curl * (grip if finger_poses.pinky_mode == 2 else 1.0))

		else:
			# Don't update our pose
			continue

		skeleton.set_bone_pose(i, t)
