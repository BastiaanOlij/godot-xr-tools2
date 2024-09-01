# xrt2_dynamic_player_rig.gd
#
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

@tool
extends XROrigin3D
class_name XRT2DynamicPlayerRig

## This player rig is meant for games where the player can move around

## Adjust the height of the XROrigin3D node above the player rig.
@export var height_adjust : float = 0.0

var _start_xr : XRT2StartXR
var _player_is_colliding :bool = false

# Node helpers
@onready var _xr_camera : XRCamera3D = $XRCamera3D
@onready var _neck_position : Node3D = $XRCamera3D/Neck
@onready var _fade : Node3D = $XRCamera3D/Fade


## Returns true if the player has physically moved into a place where they
## are colliding with the environment.
## (e.g. we can't move our character body where the player is standing)
##
## You should check this before enabling user input movement.
func get_player_is_colliding() -> bool:
	return _player_is_colliding


# User triggered pose recenter.
func _on_xr_pose_recenter() -> void:
	if not _start_xr:
		# Huh? how did we even get the signal?
		return

	var play_area_mode : XRInterface.PlayAreaMode = _start_xr.get_play_area_mode()
	if play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		# Using center on HMD could mess things up here
		push_warning("Dynamic  player rig does not work with sitting setting")
	elif play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
		# This is already handled by the headset, no need to do more!
		pass
	else:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

	# Reset our XROrigin transform
	# TODO: adjust this ever so slightly based on neck position 
	transform = Transform3D()

	# TODO: we may want to trigger re-orienting our parent in a fixed direction.


# Verifies our staging has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Check if parent is of the correct type
	var parent = get_parent()
	if parent and not parent is CharacterBody3D:
		warnings.append("Parent node must be a CharacterBody3D")

	# TODO: add config warning if we're set to Local Floor

	# Return warnings
	return warnings


# Called when the node enters the scene tree for the first time.
func _ready():
	# Do not run if in the editor
	if Engine.is_editor_hint():
		return

	_start_xr = XRT2StartXR.get_singleton()
	if _start_xr:
		_start_xr.xr_pose_recenter.connect(_on_xr_pose_recenter)


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
		push_warning("Parent node isn't a CharacterBody3D node, dynamic player rig is disabled!")
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
	var player_body_location: Vector3 = transform * _xr_camera.transform * _neck_position.transform.origin
	player_body_location.y = 0.0
	player_body_location = parent.global_transform * player_body_location

	parent.velocity = (player_body_location - org_player_body) / delta
	parent.move_and_slide()

	# TODO handle any collision with rigidbodies and transfer momentum

	# Now move our XROrigin back
	var delta_movement = parent.global_transform.origin - org_player_body
	global_transform.origin -= delta_movement

	# Negate any height change in local space due to player hitting ramps etc.
	transform.origin.y = height_adjust

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
