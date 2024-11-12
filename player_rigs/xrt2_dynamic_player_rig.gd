#-------------------------------------------------------------------------------
# xrt2_dynamic_player_rig.gd
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
class_name XRT2DynamicPlayerRig
extends XROrigin3D

## This player rig is meant for games where the player can move around
const EYE_TO_TOP = 0.08

## Enable move on input, if true we handle our movement providers
@export var enable_move_on_input : bool = true

## Auto calibrate the user to this height on recenter (set to 0.0 to disable)
@export_range(1.5, 2.5, 0.1) var target_player_height : float = 1.8:
	set(value):
		target_player_height = value
		if target_player_height <= 0.0:
			_height_adjust = 0.0
		elif _xr_camera and is_inside_tree():
			_calibrate_height()

# Reference to our start XR global script
var _start_xr : XRT2StartXR

# Height adjust calculated by our height calibration
var _height_adjust : float = 0.0

# Set to true if the player has moved somewhere physically so they are colliding,
# NOT influenced by virtual movement!
var _player_is_colliding : bool = false

# Registered movement providers
var _movement_providers : Array[XRT2MovementProvider]

# Get the gravity from the project settings to be synced with RigidBody nodes.
var _gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Starting transform for our CharacterBody3D
var _starting_transform : Transform3D = Transform3D()

# Node helpers
@onready var _xr_camera : XRCamera3D = $XRCamera3D
@onready var _neck_position : Node3D = $XRCamera3D/Neck
@onready var _fade : Node3D = $XRCamera3D/Xrt2Fade


## Return a XR dynamic player ancestor
static func get_xr_dynamic_player_rig(p_node : Node3D) -> XRT2DynamicPlayerRig:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRT2DynamicPlayerRig:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Register a movement provider that will provide movement for this player character
func register_movement_provider(p_movement_provider : XRT2MovementProvider):
	if not _movement_providers.has(p_movement_provider):
		_movement_providers.push_back(p_movement_provider)


# User triggered pose recenter.
func _on_xr_pose_recenter() -> void:
	if not _start_xr:
		# Huh? how did we even get the signal?
		return

	var play_area_mode : XRInterface.PlayAreaMode = _start_xr.get_play_area_mode()
	if play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		# Using center on HMD could mess things up here
		push_warning("Dynamic player rig does not work with sitting setting")
	elif play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
		# This is already handled by the headset, no need to do more!
		pass
	else:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

	# XRCamera3D node may not be updated yet, so go straight to the source!
	var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if not head_tracker:
		push_error("Couldn't locate head tracker!")
		return

	var pose : XRPose = head_tracker.get_pose("default")
	var head_transform : Transform3D = pose.get_adjusted_transform()

	# Get neck transform in XROrigin3D space
	var neck_transform = _neck_position.transform * head_transform

	# Reset our XROrigin transform and apply the inverse of the neck position.
	var new_origin_transform : Transform3D = Transform3D()
	new_origin_transform.origin.x = -neck_transform.origin.x
	new_origin_transform.origin.y = 0.0
	new_origin_transform.origin.z = -neck_transform.origin.z
	transform = new_origin_transform

	# Reset our parent to our original direction.
	var parent : CharacterBody3D = get_parent()
	if parent:
		parent.transform.basis = _starting_transform.basis

	# Recalibrate our height
	if target_player_height > 0.0 and _xr_camera:
		_calibrate_height()


func _calibrate_height() -> void:
	# XRCamera3D node may not be updated yet, so go straight to the source!
	var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if not head_tracker:
		push_error("Couldn't locate head tracker!")
		return

	var pose : XRPose = head_tracker.get_pose("default")
	var t : Transform3D = pose.get_adjusted_transform()

	var camera_height = t.origin.y
	_height_adjust = target_player_height - EYE_TO_TOP - camera_height
	transform.origin.y = _height_adjust


# Verifies our staging has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Check if parent is of the correct type
	var parent = get_parent()
	if parent and not parent is CharacterBody3D:
		warnings.append("Parent node must be a CharacterBody3D")

	# Return warnings
	return warnings


# Called when the node enters the scene tree for the first time.
func _ready():
	# Do not run if in the editor
	if Engine.is_editor_hint():
		return

	process_physics_priority = -92

	var parent : CharacterBody3D = get_parent()
	if parent:
		_starting_transform = parent.transform
	else:
		push_warning("Parent node isn't a CharacterBody3D node, dynamic player rig is disabled!")

	_start_xr = XRT2StartXR.get_singleton()
	if _start_xr:
		_start_xr.xr_pose_recenter.connect(_on_xr_pose_recenter)

		# And recenter for the first time, this assumes tracking is already active
		# which should be true if we use our staging system.
		# TODO possibly improve by delaying this until head tracker reports
		# tracking data?
		_on_xr_pose_recenter()


func _exit_tree():
	if _start_xr:
		_start_xr.xr_pose_recenter.disconnect(_on_xr_pose_recenter)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Do not run if in the editor
	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	# Process our physical movement, input movement is handled on the parent node.
	var parent : CharacterBody3D = get_parent()
	if not parent:
		set_physics_process(false)
		return

	# Remember our current velocity, we'll apply that later
	var current_velocity = parent.velocity

	# Start by rotating the player to face the same way our real player is
	var camera_basis: Basis = transform.basis * _xr_camera.transform.basis
	var forward: Vector2 = Vector2(camera_basis.z.x, camera_basis.z.z)
	var angle: float = forward.angle_to(Vector2(0.0, 1.0))

	# Rotate our character body
	parent.transform.basis = parent.transform.basis.rotated(Vector3.UP, angle)

	# Reverse this rotation our origin node
	transform = Transform3D().rotated(Vector3.UP, -angle) * transform

	# Now apply movement, first move our player body to the right location
	var org_player_body: Vector3 = parent.global_transform.origin
	var player_body_location: Vector3 = transform * _xr_camera.transform * \
		_neck_position.transform.origin
	player_body_location.y = 0.0
	player_body_location = parent.global_transform * player_body_location

	parent.velocity = (player_body_location - org_player_body) / delta
	parent.move_and_slide()

	# TODO handle any collision with rigidbodies and transfer momentum

	# Now move our XROrigin back
	var delta_movement = parent.global_transform.origin - org_player_body
	global_transform.origin -= delta_movement

	# Negate any height change in local space due to player hitting ramps etc.
	transform.origin.y = _height_adjust

	# Return our value
	parent.velocity = current_velocity

	# Check if we managed to move where we wanted to
	var location_offset = (player_body_location - parent.global_transform.origin).length()
	if location_offset > 0.1:
		# We couldn't go where we wanted to, black out our screen
		_fade.fade = clamp((location_offset - 0.1) / 0.1, 0.0, 1.0)

		_player_is_colliding = true
	else:
		_fade.fade = 0.0
		_player_is_colliding = false

	# Handle our virtual movement
	if not _player_is_colliding and enable_move_on_input:
		# TODO handle order of movement providers
		for provider : XRT2MovementProvider in _movement_providers:
			if provider.enabled:
				# TODO handle a way for a movement provider to inform us that
				# other movement providers should be ignore and whether it has
				# handled the movement completely and we should exit here
				provider.handle_movement(parent, delta)

		# Always handle gravity
		parent.velocity.y -= _gravity * delta

		# Now move and slide
		parent.move_and_slide()

		# TODO handle any collision with rigidbodies and transfer momentum
