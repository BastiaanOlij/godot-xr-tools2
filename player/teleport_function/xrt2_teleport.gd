#-------------------------------------------------------------------------------
# xrt2_teleport.gd
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
class_name XRT2Teleport
extends XRT2HandAttachment

#region Signals
signal teleport_started
signal teleport_cancelled
signal teleport_done
#endregion

#region Export variables
## If true, the user can use the teleport function.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value
		if _teleport_activate_pressed:
			if enabled:
				_teleport_start()
			else:
				_teleport_cancel()

## Duration of fade out and fade in.
@export_range(0.1, 1.0, 0.1, "suffix:s") var fade_duration: float = 0.3

@export_group("Input")

## Action map input for out teleport function.
@export var teleport_action: String = "teleport"

## Do we need to hold our button to teleport,
## or do we toggle it?
@export_enum("Toggle", "Hold") var teleport_action_mode: int = 0

## Action map input for rotating our target
@export var rotate_action: String = "move.x"

## Maximum angle between target surface and player
@export_range(0.0, 1400.0, 1.0, "radians_as_degrees", "suffix:°/s") var max_rotation_speed: float = deg_to_rad(360.0)

@export_group("Target")

## Color of our teleport ribbon and target circle
## when we can teleport.
@export var can_color: Color = Color(0.0, 1.0, 0.0)

## Color of our teleport ribbon and target circle
## when we can't teleport to the given destination.
@export var can_not_color: Color = Color(1.0, 0.0, 0.0)

## Color of our teleport ribbon, if we don't have a target
@export var no_target_color: Color = Color(0.0, 0.0, 1.0)

## Maximum angle between target surface and player
@export_range(0.0, 60.0, 0.5, "radians_as_degrees") var max_target_angle: float = deg_to_rad(15.0)

@export_group("Physics")

## Physics layer(s) for detecting surfaces we can teleport to.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		if _raycast:
			_update_raycast()

## Downwards angle at which we cast our teleport ray.
@export_range(0.0, 60.0, 0.5, "radians_as_degrees") var raycast_angle: float = deg_to_rad(30.0):
	set(value):
		raycast_angle = value
		if _raycast:
			_update_raycast()

## Maximum distance to which we can teleport.
@export_range(0.0, 10.0, 0.1) var raycast_max_distance: float = 4.0:
	set(value):
		raycast_max_distance = value
		if _raycast:
			_update_raycast()
#endregion

#region Private variables
static var _on_teleport: Array[Callable]

var _xr_origin: XROrigin3D
var _xr_controller: XRController3D
var _character_body: CharacterBody3D
var _fade_effect: XRT2EffectFade
var _tween: Tween
var _raycast: RayCast3D
var _target: MeshInstance3D
var _target_material: ShaderMaterial
var _arc: MeshInstance3D
var _arc_material: ShaderMaterial
var _teleport_activate_pressed: bool = false
var _enabled_movement_providers: Array[XRT2MovementProvider]
var _can_teleport: bool = false
var _rotate_angle: float = 0.0
#endregion

#region Public functions
## Register callback on successful teleport
static func register_on_teleport(callback: Callable):
	_on_teleport.push_back(callback)

## Unregister callback on successful teleport
static func unregister_on_teleport(callback: Callable):
	_on_teleport.erase(callback)
#endregion

#region Virtual functions
# These are virtual functions designed to be overridden in an extended class

## Check if we can teleport to this location.
## If implementing, please call [code]super(at)[/code].
func _check_can_teleport(at: Transform3D) -> bool:
	# Check if we can actually teleport here.
	if _xr_origin and at.basis.y.angle_to(_xr_origin.global_basis.y) > max_target_angle:
		return false

	# Do we have enough room to teleport here?
	if _character_body and XRT2.check_body_collision(_character_body, at):
		return false

	# TODO: Check further teleport conditions like:
	# - Are we in an exclusion area?

	return true


## Perform the teleport.
## Note, screen is already blacked out.
func _perform_teleport(to: Transform3D) -> void:
	if _character_body:
		var from: Transform3D = _character_body.global_transform

		# Perform teleport!
		_character_body.global_transform = to

		# Inform other nodes that want to be updated
		for callable in _on_teleport:
			callable.call(from, to)
#endregion

#region Private functions
# Update our raycast configuration based on properties.
func _update_raycast():
	_raycast.collision_mask = collision_mask
	_raycast.target_position = Vector3(0.0, 0.0, -raycast_max_distance).rotated(Vector3(-1.0, 0.0, 0.0), raycast_angle)


# Reanable movement providers we previously disabled.
func _renable_movement_providers():
	for movement_provider: XRT2MovementProvider in _enabled_movement_providers:
		movement_provider.enabled = true

	_enabled_movement_providers.clear()


# Updates fade setting, callback for tweening
func _set_fade(p_value : float) -> void:
	_fade_effect.fade = p_value


# Start our teleport function.
func _teleport_start():
	_raycast.enabled = true
	_arc.visible = true
	_rotate_angle = 0.0

	_renable_movement_providers() # JIC

	# Disable movement providers
	var movement_providers = get_parent().find_children("*", "XRT2MovementProvider")
	for movement_provider: XRT2MovementProvider in movement_providers:
		if movement_provider.enabled:
			_enabled_movement_providers.push_back(movement_provider)
			movement_provider.enabled = false

	teleport_started.emit()


# Cancel our teleport function.
func _teleport_cancel():
	_raycast.enabled = false
	_target.visible = false
	_arc.visible = false

	# Reable movement providers
	_renable_movement_providers()

	teleport_cancelled.emit()


# Perform our teleport.
func _do_teleport():
	_raycast.enabled = false
	_target.visible = false
	_arc.visible = false

	# Fade to black
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_fade, 0.0, 1.0, fade_duration)
	await _tween.finished

	_perform_teleport(_target.global_transform)

	# Fade to visible
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_fade, 1.0, 0.0, fade_duration)
	await _tween.finished

	# Reable movement providers
	_renable_movement_providers()

	teleport_done.emit()

# Add collision exceptions to our raycast.
func _add_collision_exception():
	if not _raycast:
		return

	_raycast.clear_exceptions()

	var parent: Node = get_parent()
	while parent:
		if parent is CollisionObject3D:
			_raycast.add_exception(parent)

		parent = parent.get_parent()


# Makes our arc target our target.
func _update_arc():
	if not _arc or not _target or not _arc_material or not _target_material or not _xr_origin:
		return

	# Arc not visible? no need to update
	if not _arc.visible:
		return

	if _target.visible:
		var arc_length: float = (_target.global_position - global_position).length()
		_arc.look_at(_target.global_position, _xr_origin.global_basis.y, false)
		_arc_material.set_shader_parameter("arc_length", arc_length)
		if _can_teleport:
			_target_material.set_shader_parameter("albedo", can_color)
			_arc_material.set_shader_parameter("albedo_color", can_color)
		else:
			_target_material.set_shader_parameter("albedo", can_not_color)
			_arc_material.set_shader_parameter("albedo_color", can_not_color)
	else:
		basis = Basis(Vector3(-1.0, 0.0, 0.0), raycast_angle)
		_arc_material.set_shader_parameter("arc_length", raycast_max_distance)
		_arc_material.set_shader_parameter("albedo_color", no_target_color)


# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _xr_controller and not _xr_collision_hand:
		warnings.push_back("This node requires an XRController3D or XRT2CollisionHand as an anchestor.")

	if not _character_body:
		warnings.push_back("This node doesn't have a CharacterBody3D as an anchestor and will not run default teleport logic.")

	# Return warnings
	return warnings


# Update our properties
func _validate_property(property):
	super(property)
	if property.name in [ "bone_name", "position_offset", "rotation_offset" ]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# Called when we enter the scene tree.
func _enter_tree():
	super()

	_add_collision_exception()

	_xr_origin = XRT2.get_xr_origin(self)
	_character_body = XRT2.get_character_body(_xr_origin)

	# TODO: position offset is correct for our default hand mesh,
	# may need to do something more here if we allow alternative hand meshes.
	if _xr_collision_hand:
		bone_name = "LeftMiddleMetacarpal" if _xr_collision_hand.hand == 0 else "RightMiddleMetacarpal"
		position_offset = Vector3(0.03 if _xr_collision_hand.hand == 0 else -0.03, 0.0, -0.06)

		_xr_collision_hand.button_pressed.connect(_on_button_pressed)
		_xr_collision_hand.button_released.connect(_on_button_released)
	else:
		_xr_controller = XRT2.get_xr_controller(self)

		if _xr_controller:
			_xr_controller.button_pressed.connect(_on_button_pressed)
			_xr_controller.button_released.connect(_on_button_released)

		# We should position our node based on the pose used for the controller.
		# We can use our position offset and rotation offset for this
		position_offset = Vector3(0.0, 0.0, 0.0)


# Called the first time we enter the scene tree.
func _ready():
	# Create our target
	_target_material = ShaderMaterial.new()
	_target_material.shader = load("res://addons/godot-xr-tools2/shaders/unshaded_texture_with_alpha.gdshader")
	_target_material.set_shader_parameter("albedo", can_color)
	_target_material.set_shader_parameter("texture_albedo", load("res://addons/godot-xr-tools2/images/teleport_target.png"))
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = _target_material
	_target = MeshInstance3D.new()
	_target.mesh = mesh
	add_child(_target, false, Node.INTERNAL_MODE_BACK)

	# Create our arc
	_arc_material = ShaderMaterial.new()
	_arc_material.shader = load("res://addons/godot-xr-tools2/shaders/teleport_arc.gdshader")
	_arc_material.set_shader_parameter("albedo_color", can_color)
	_arc_material.set_shader_parameter("albedo_texture", load("res://addons/godot-xr-tools2/images/teleport_arrow.png"))
	mesh = PlaneMesh.new()
	mesh.size = Vector2(0.05, 1.0)
	mesh.subdivide_depth = 40.0
	mesh.material = _arc_material
	_arc = MeshInstance3D.new()
	_arc.mesh = mesh
	add_child(_arc, false, Node.INTERNAL_MODE_BACK)

	if Engine.is_editor_hint():
		# Just place our target somewhere usable
		_target.position = Vector3(0.0, -0.5, -0.5)

		# Update our arc
		_update_arc()

		# No need to run the rest in the editor!
		return

	# Create our raycast
	if _xr_origin:
		_raycast = RayCast3D.new()
		_raycast.enabled = false
		add_child(_raycast, false, Node.INTERNAL_MODE_BACK)
		_raycast.top_level = true
		_update_raycast()
		_add_collision_exception()

	# Create our fade effect
	_fade_effect = XRT2EffectFade.new()
	add_child(_fade_effect, false, Node.INTERNAL_MODE_BACK)

	_target.top_level = true
	_target.visible = false
	_arc.visible = false


# Called when we exit the scene tree.
func _exit_tree():
	if _xr_collision_hand:
		_xr_collision_hand.button_pressed.disconnect(_on_button_pressed)
		_xr_collision_hand.button_released.disconnect(_on_button_released)
		# Our inherited code has more to do, don't set to null!

	if _xr_controller:
		_xr_controller.button_pressed.disconnect(_on_button_pressed)
		_xr_controller.button_released.disconnect(_on_button_released)
		_xr_controller = null

	_character_body = null
	_xr_origin = null

	super()


func _physics_process(delta):
	# Match origination of our raycast to our origin
	if _xr_origin and _raycast:
		var inv_origin_basis: Basis = _xr_origin.global_basis.inverse()
		var forward = inv_origin_basis * global_basis.z
		if abs(forward.dot(Vector3.UP)) > 0.99:
			forward = inv_origin_basis * global_basis.y
		var target_basis = _xr_origin.global_basis * Basis.looking_at(forward, Vector3.UP, true)

		_raycast.basis = _raycast.basis.slerp(target_basis.orthonormalized(), 0.25)
		_raycast.position = lerp(_raycast.position, global_position, 0.25)

	if not enabled or not _raycast:
		return

	var target_visible = false
	_can_teleport = false

	if _raycast.is_colliding():
		# We are colliding with something

		var normal: Vector3 = _raycast.get_collision_normal().normalized()
		var position: Vector3 = _raycast.get_collision_point()

		# Determine our forward direction
		var forward: Vector3
		var can_turn: bool = true

		# TODO: Check if we've got a direction overrule (to be implemented).
		forward = -global_basis.z
		if abs(forward.dot(normal)) > 0.99:
			forward = global_basis.y

		# Orient our destination according to our forward direction
		_target.global_basis.y = normal
		_target.global_basis.x = forward.cross(_target.global_basis.y).normalized()
		_target.global_basis.z = _target.global_basis.x.cross(_target.global_basis.y).normalized()

		if can_turn:
			_rotate_angle -= _get_rotate_input() * delta * max_rotation_speed
			_target.global_basis = _target.global_basis * Basis(Vector3.UP, _rotate_angle)

		# Position our target
		_target.global_position = position + _target.global_basis.y * 0.01

		target_visible = true
		_can_teleport = _check_can_teleport(_target.global_transform)

	_target.visible = target_visible
	_update_arc()


func _get_rotate_input() -> float:
	var inputs: PackedStringArray = rotate_action.split(".")
	if inputs.is_empty():
		return 0.0

	var input: Variant
	if _xr_collision_hand:
		input = _xr_collision_hand.get_input(inputs[0])
	elif _xr_controller:
		input = _xr_controller.get_input(inputs[0])

	if input and typeof(input) == TYPE_FLOAT:
		return input
	elif input and typeof(input) == TYPE_VECTOR2:
		if inputs.size() == 1 or inputs[1].to_lower() != "y":
			return input.x
		else:
			return input.y

	return 0.0


func _on_button_pressed(action_name):
	if action_name == teleport_action and teleport_action_mode == 1:
		_teleport_activate_pressed = true
		if enabled:
			_teleport_start()


func _on_button_released(action_name):
	if action_name == teleport_action:
		if teleport_action_mode == 0:
			_teleport_activate_pressed = not _teleport_activate_pressed
		else:
			_teleport_activate_pressed = false

		if enabled and _teleport_activate_pressed:
			_teleport_start()
		elif enabled and not _teleport_activate_pressed:
			# If we have target, teleport
			if _can_teleport:
				_do_teleport()
			else:
				# Else cancel teleport
				_teleport_cancel()
#endregion
