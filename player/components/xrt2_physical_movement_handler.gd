#-------------------------------------------------------------------------------
# xrt2_physical_movement_handler.gd
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
class_name XRT2PhysicalMovementHandler
extends Node3D

## XRTools2 Physical Movement Handler Script
##
## This script implements logic that applies physical movement to a
## [CharacterBody3D] node and applies the needed changes to the [XROrigin3D]
## node.
## It also handles fading out the screen if the player attempts to move
## though an obstacle.
##
## Add this as a child to your [XROrigin3D] node to enable the logic.

#region Export variables
@export_group("Player", "player_")

## Auto calibrate the users eye height to this on recenter (set to 0.0 to disable)
@export_range(1.5, 2.5, 0.1, "suffix:m") var player_target_eye_height : float = 1.6:
	set(value):
		player_target_eye_height = value
		if player_target_eye_height <= 0.0:
			_height_adjust = 0.0
		elif _xr_camera and is_inside_tree():
			_calibrate_height()

## Neck offset 
@export var player_neck_offset : Vector3 = Vector3(0.0, -0.1, 0.1)

## Head collision radius
@export_range(0.05, 0.5, 0.01, "suffix:m") var player_head_collision_radius : float = 0.15

@export_group("Fade", "fade_")

## Distance from target destination we start fading
@export_range(0.2, 1.0, 0.1, "suffix:m") var fade_distance : float = 0.5

## Distance over which we fade in
@export_range(0.1, 1.0, 0.1, "suffix:m") var fade_in : float = 0.1

## Our fade message
@export var fade_message : String = "Move back to allowed position."

## Visible layer for our fade message
@export_flags_3d_render var fade_layers = 2:
	set(value):
		fade_layers = value
		if _xr_fade_effect and is_inside_tree():
			_xr_fade_effect.layers = fade_layers

@export_group("Debug", "debug_")

## Show some debug information in headset
@export var debug_show_info : bool = false
#endregion

#region Private variables
# Height adjustment
var _height_adjust : float = 0.0

# Did we run our height calibration?
var _height_calibrated : bool = false

# Shape query for detecting head collisions
var _shape_query : PhysicsShapeQueryParameters3D

# Starting transform for our CharacterBody3D
var _starting_transform : Transform3D = Transform3D()

# Fade effect we'll add on our camera node
var _xr_fade_effect : XRT2EffectFade

# Helper variables
var _xr_origin : XROrigin3D
var _xr_camera : XRCamera3D
var _character_body : CharacterBody3D
var _debug_info : Label3D
#endregion

#region Private functions
# Calibrate our players height by checking the current head position.
func _calibrate_height() -> void:
	if not _xr_origin:
		return

	# XRCamera3D node may not be updated yet, so go straight to the source!
	var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if not head_tracker:
		push_error("Couldn't locate head tracker!")
		return

	var pose : XRPose = head_tracker.get_pose("default")
	if pose and pose.has_tracking_data:
		var t : Transform3D = pose.get_adjusted_transform()

		var camera_height = t.origin.y
		_height_adjust = player_target_eye_height - camera_height

		_xr_origin.transform.origin.y = _height_adjust
		_height_calibrated = true


# Verifies our physical movement handler has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Check if parent is of the correct type
	var parent = get_parent()
	if not parent or not parent is XROrigin3D:
		warnings.append("Parent node must be an XROrigin3D node")

	# Check for our character body
	if parent:
		var character_body = parent.get_parent()
		if not character_body or not character_body is CharacterBody3D:
			warnings.append("Parent of our XROrigin3D node must be a CharacterBody3D node")

		# Check if we have a camera as a child
		var camera : XRCamera3D
		for child in parent.get_children():
			if child is XRCamera3D:
				camera = child
				break
		if not camera:
			warnings.append("XROrigin3D node must have an XRCamera3D node")

	# Return warnings
	return warnings


# Run once
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_physics_priority = -93

	# Check for our origin 3d node
	_xr_origin = get_parent()
	if _xr_origin:
		# Check for our character body
		_character_body = _xr_origin.get_parent()
		if _character_body:
			_starting_transform = _character_body.transform

			# Setup our shape query for head collisions
			var shape : SphereShape3D = SphereShape3D.new()
			shape.radius = player_head_collision_radius

			_shape_query = PhysicsShapeQueryParameters3D.new()
			_shape_query.collision_mask = _character_body.collision_mask
			_shape_query.shape = shape

		for child in _xr_origin.get_children():
			if child is XRCamera3D:
				_xr_camera = child
				break

		if _xr_camera:
			_xr_fade_effect = XRT2EffectFade.new()
			_xr_fade_effect.message = fade_message
			_xr_fade_effect.layers = fade_layers
			_xr_camera.add_child(_xr_fade_effect, false, Node.INTERNAL_MODE_BACK)

	# Recalibrate our height
	if player_target_eye_height > 0.0 and _xr_camera:
		_calibrate_height()

	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface:
		openxr_interface.session_visible.connect(_on_session_visible)
		openxr_interface.pose_recentered.connect(_on_pose_recentered)
		_on_pose_recentered()


# Run when we exit our tree.
func _exit_tree():
	if Engine.is_editor_hint():
		return

	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface:
		openxr_interface.session_visible.disconnect(_on_session_visible)
		openxr_interface.pose_recentered.disconnect(_on_pose_recentered)


func _process(delta) -> void:
	# Do not run if in the editor
	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	if debug_show_info:
		var text = ""
		var head_height : float = 0.0

		if not _debug_info:
			_debug_info = Label3D.new()
			_debug_info.pixel_size = 0.002
			add_child(_debug_info, false, Node.INTERNAL_MODE_BACK)

		var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
		if not head_tracker:
			push_error("Couldn't locate head tracker!")
			return

		var pose : XRPose = head_tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			var t : Transform3D = pose.get_adjusted_transform()

			_debug_info.position = t.origin - t.basis.z * Vector3(0.75, 0.0, 0.75)
			_debug_info.transform = _debug_info.transform.looking_at(t.origin, Vector3.UP, true)

			head_height = t.origin.y

		text += "Head height: %0.2fm
Height adjust: %0.2fm
Eye height: %0.2fm
" % [ head_height, _height_adjust, head_height + _height_adjust ]

		_debug_info.text = text
		_debug_info.visible = true
	elif _debug_info:
		_debug_info.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta) -> void:
	# Do not run if in the editor
	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	# Check for our origin 3d node
	if not _xr_origin:
		set_physics_process(false)
		return

	# Check for our character body
	if not _character_body:
		set_physics_process(false)
		return

	if not _xr_camera:
		set_physics_process(false)
		return

	# Start by rotating the player to face the same way our real player is
	var camera_basis: Basis = _xr_origin.transform.basis * _xr_camera.transform.basis
	var forward: Vector2 = Vector2(camera_basis.z.x, camera_basis.z.z)
	var angle: float = forward.angle_to(Vector2(0.0, 1.0))

	# Rotate our character body
	_character_body.transform.basis = _character_body.transform.basis.rotated(Vector3.UP, angle)

	# Reverse this rotation our origin node
	_xr_origin.transform = Transform3D().rotated(Vector3.UP, -angle) * _xr_origin.transform

	# Now apply movement, first move our player body to the right location
	var org_player_body: Vector3 = _character_body.global_position
	var player_body_location: Vector3 = _xr_origin.transform * _xr_camera.transform * player_neck_offset
	player_body_location.y = 0.0
	player_body_location = _character_body.global_transform * player_body_location

	var move_collision : KinematicCollision3D = _character_body.move_and_collide(player_body_location - org_player_body)
	if move_collision:
		# For now we do nothing with these collisions.
		# Possibly some time in the future we may wish to apply momentum
		# to rigid bodies we hit.
		pass

	# Now move our XROrigin back
	var delta_movement = _character_body.global_position - org_player_body
	_xr_origin.global_position -= delta_movement

	# Negate any height change in local space due to player hitting ramps etc.
	_xr_origin.transform.origin.y = _height_adjust

	# Check fade if we can't move where we're going,
	# Note that fade if head is moved into a collider
	if _xr_fade_effect:
		# Check if our head collides if moved to the camera position
		var space = PhysicsServer3D.body_get_space(_character_body.get_rid())
		var state = PhysicsServer3D.space_get_direct_state(space)

		var exclude : Array[RID] = [ _character_body.get_rid() ]
		var exceptions : Array[PhysicsBody3D] = _character_body.get_collision_exceptions()
		for exception in exceptions:
			exclude.push_back(exception.get_rid())

		var t : Transform3D = Transform3D()
		t.origin = _character_body.global_transform * Vector3(0.0, _xr_camera.position.y + _height_adjust, 0.0)
		_shape_query.transform = t
		_shape_query.motion = _xr_camera.global_position - t.origin
		_shape_query.exclude = exclude

		var collision = state.cast_motion(_shape_query)
		var is_colliding : bool = not collision.is_empty() and collision[0] < 1.0

		if is_colliding:
			_xr_fade_effect.fade = 1.0
		else:
			var distance = (player_body_location - _character_body.global_position).length()
			if distance < fade_distance:
				_xr_fade_effect.fade = 0.0
			else:
				_xr_fade_effect.fade = clamp((distance - fade_distance) / fade_in, 0.0, 1.0)
#endregion

#region Signal handling
func _on_session_visible() -> void:
	# Recalibrate our height
	if not _height_calibrated and player_target_eye_height > 0.0 and _xr_camera:
		_calibrate_height()


func _on_pose_recentered() -> void:
	if not _xr_origin:
		return

	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if not openxr_interface:
		# Huh? really? How can our signal be setup?
		return

	if openxr_interface.xr_play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		# Using center on HMD could mess things up here
		push_warning("Physical movement pose reset doesn't work with sitting setting")
		return
	elif openxr_interface.xr_play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
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
	if not pose or not pose.has_tracking_data:
		# No tracking data yet, no point in doing this.
		return

	var head_transform : Transform3D = pose.get_adjusted_transform()

	# Get neck transform in XROrigin3D space
	var neck_transform : Transform3D
	neck_transform.origin = player_neck_offset
	neck_transform = head_transform * neck_transform

	# Reset our XROrigin transform and apply the inverse of the neck position.
	var new_origin_transform : Transform3D = Transform3D()
	new_origin_transform.origin.x = -neck_transform.origin.x
	new_origin_transform.origin.y = _height_adjust
	new_origin_transform.origin.z = -neck_transform.origin.z
	_xr_origin.transform = new_origin_transform

	# Reset our parent to our original direction.
	if _character_body:
		_character_body.transform.basis = _starting_transform.basis

	# Recalibrate our height
	if player_target_eye_height > 0.0 and _xr_camera:
		_calibrate_height()
#endregion
