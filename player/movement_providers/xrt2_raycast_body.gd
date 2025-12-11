#-------------------------------------------------------------------------------
# xrt2_raycast_body.gd
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
class_name XRT2RaycastBody
extends XRT2MovementProvider

## XRT2RaycastBody is a movement provider that handles the player body collision
## in combination with a raycast to controll the players correct distance
## from the ground.
##
## Note: This node will add a collision shape to your character body!

#region Export variables
@export_group("Player body")

## Height of person head.
## Our eye level is assumed to be halfway.
@export_range(0.1, 1.0, 0.01) var head_height = 0.25:
	set(value):
		head_height = value
		if is_inside_tree():
			if _capsule_shape:
				_capsule_shape.height = head_height + torso_height

			if _debug_mesh:
				_debug_mesh.height = head_height + torso_height

## Height of our torso.
@export_range(0.1, 1.0, 0.01) var torso_height = 0.8:
	set(value):
		torso_height = value
		if is_inside_tree():
			if _capsule_shape:
				_capsule_shape.height = head_height + torso_height

			if _debug_mesh:
				_debug_mesh.height = head_height + torso_height

			if Engine.is_editor_hint():
				if _collision_shape:
					_collision_shape.position.y = _default_eye_level - torso_height * 0.5

## Radius of our torso
@export_range(0.1, 1.0, 0.01) var torso_radius = 0.3:
	set(value):
		torso_radius = value
		if is_inside_tree():
			if _capsule_shape:
				_capsule_shape.radius = torso_radius

			if _debug_mesh:
				_debug_mesh.radius = torso_radius

@export_group("Physics")

## How much deeper do we check?
@export var raycast_over_extent : float = 0.1

## PID controller that manages our height from ground.
@export var pid_controller : XRT2LinearPIDController = \
	preload("res://addons/godot-xr-tools2/player/movement_providers/default_raycast_pid_controller.tres")

@export_group("Debug")

## Show our debug shape.
## (Godot doesn't show internal collision shapes by default)
@export var show_debug_shape : bool = true:
	set(value):
		show_debug_shape = value
		if _debug_mesh_instance:
			_debug_mesh_instance.visible = show_debug_shape

## Show some debug information in headset
@export var debug_show_info : bool = false

#endregion

#region Private variables
# Default eye level we use, should be nice to source this from XRT2PhysicalMovementHandler
# but this is for editor purposes only...
var _default_eye_level : float = 1.6

# Our collision and capsule objects.
var _collision_shape : CollisionShape3D
var _capsule_shape : CapsuleShape3D

# Debug objects to visualise our capsule
var _debug_mesh_instance : MeshInstance3D
var _debug_mesh : CapsuleMesh
var _debug_info : Label3D

# Are we currently on the floor?
var _is_on_floor : bool = true

# Get the fiction value for our current floor
var _floor_friction : float = 1.0
#endregion

#region Public functions
## Are we currently on the floor according to our logic here?
func is_on_floor() -> bool:
	return _is_on_floor


## Get the friction factor of the surface we're standing on
func get_floor_friction() -> float:
	return _floor_friction
#endregion

#region Private functions
# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if not pid_controller:
		warnings.push_back("You need to setup a PID controller for height control.")

	# Return warnings
	return warnings


# Node was added to our scene tree
func _enter_tree():
	super._enter_tree()

	if _character_body:
		_capsule_shape = CapsuleShape3D.new()
		_capsule_shape.radius = torso_radius
		_capsule_shape.height = head_height + torso_height

		_collision_shape = CollisionShape3D.new()
		_collision_shape.shape = _capsule_shape
		_collision_shape.position.y = _default_eye_level - torso_height * 0.5
		_character_body.add_child.call_deferred(_collision_shape, false, Node.INTERNAL_MODE_BACK)

		if Engine.is_editor_hint():
			var debug_material : ShaderMaterial = ShaderMaterial.new()
			debug_material.shader = load("res://addons/godot-xr-tools2/shaders/unshaded_with_alpha.gdshader")
			debug_material.set_shader_parameter("albedo", Color("#00b6b71b"))
			
			_debug_mesh = CapsuleMesh.new()
			_debug_mesh.radius = torso_radius
			_debug_mesh.height = head_height + torso_height
			_debug_mesh.material = debug_material

			_debug_mesh_instance = MeshInstance3D.new()
			_debug_mesh_instance.mesh = _debug_mesh
			_debug_mesh_instance.visible = show_debug_shape
			_collision_shape.add_child(_debug_mesh_instance, false, Node.INTERNAL_MODE_BACK)

	if _locomotion_handler:
		_locomotion_handler.register_on_floor_callback(is_on_floor)
		_locomotion_handler.register_floor_friction_callback(get_floor_friction)


# Node was removed from our scene tree
func _exit_tree():
	if _collision_shape:
		_collision_shape.queue_free()
		_collision_shape = null

	# capsule and debug mesh will automatically be freed
	_capsule_shape = null
	_debug_mesh_instance = null
	_debug_mesh = null

	if _locomotion_handler:
		_locomotion_handler.unregister_on_floor_callback.call_deferred(is_on_floor)
		_locomotion_handler.unregister_floor_friction_callback(get_floor_friction)

	super._exit_tree()


## Called by our locomotion handler.
func _process_locomotion(delta : float) -> void:
	# If not enabled, ignore it.
	if not enabled or not _character_body or not _locomotion_handler:
		return

	var character_transform_inverse = _character_body.global_transform.inverse()

	# First get our eye level.
	var head_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if not head_tracker:
		# Don't update if we don't have a head tracker.
		return
	var head_pose : XRPose = head_tracker.get_pose("default")
	if not head_pose or not head_pose.has_tracking_data:
		# Don't update if there is no tracking data.
		return
	var head_position = XRServer.world_origin * head_pose.get_adjusted_transform().origin
	var eye_level = (character_transform_inverse * head_position).y

	# TODO: Need to react to eye_level being smaller than (torso_height + eye_level * 0.5)

	# Position our collision.
	if _collision_shape:
		_collision_shape.position.y = eye_level - torso_height * 0.5

	# We need a PID controller, or this next bit will not work.
	if not pid_controller:
		return

	# Perform a raycast to find out how far above the ground we are.
	var rid = _character_body.get_rid()
	var space = PhysicsServer3D.body_get_space(rid)
	var state : PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(space)
	if not state:
		return

	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.collision_mask = _character_body.collision_mask
	query.exclude = [ rid ]
	query.from = _character_body.global_transform * Vector3(0.0, eye_level - torso_height - head_height * 0.5, 0.0)
	query.to = _character_body.global_transform * Vector3(0.0, -raycast_over_extent, 0.0)
	var collision = state.intersect_ray(query)
	var collision_height : float = -99.0
	if collision.is_empty():
		_is_on_floor = false
	else:
		# Note: in this setup our move_and_slide won't understand whether we are on the floor or not.
		# We thus need to mimic the behaviour normally handled by CharacterBody3D

		var collision_object : CollisionObject3D = collision.collider
		collision_height = (character_transform_inverse * collision.position).y
		var collision_normal : Vector3 = character_transform_inverse.basis * collision.normal
		if collision_height < 0.0:
			_is_on_floor = false
		else:
			var collision_angle = collision_normal.angle_to(_character_body.global_basis.y)
			if _character_body.floor_stop_on_slope and collision_angle <= _character_body.wall_min_slide_angle:
				# We're on the floor, but don't slide
				_is_on_floor = true
			else:
				# We're only on floor if our collision angle is smaller than our max floor angle
				_is_on_floor = (collision_angle <= _character_body.floor_max_angle)

				# Also make gravity push us away from the floor
				_character_body.velocity += _character_body.get_gravity().bounce(collision_normal) * Vector3(delta, 0.0, delta)

			# Use a PID controller to control our height.
			var pid_factor : float = pid_controller.calculate(delta, collision_height, 0.0)
			_character_body.velocity -= _character_body.global_basis.y * pid_factor * delta

		_floor_friction = 0.0
		if _is_on_floor:
			# TODO: If what we are standing on is a moving platform,
			# we should apply that movement to our character.

			var physics_material : PhysicsMaterial = null
			if collision_object is StaticBody3D:
				physics_material = collision_object.physics_material_override
			elif collision_object is RigidBody3D:
				physics_material = collision_object.physics_material_override

			if physics_material:
				# Get our floor friction
				_floor_friction = physics_material.friction
			else:
				_floor_friction = 1.0

	if debug_show_info:
		if not _debug_info:
			_debug_info = Label3D.new()
			_debug_info.pixel_size = 0.002
			add_child.call_deferred(_debug_info, false, Node.INTERNAL_MODE_BACK)

		_debug_info.position = Vector3(0.0, eye_level, -0.75)

		_debug_info.text = "Eye level: %0.2fm
Current level: %0.2fm
" % [ eye_level, eye_level - collision_height ]
		_debug_info.visible = true
	elif _debug_info:
		_debug_info.visible = false
#endregion
