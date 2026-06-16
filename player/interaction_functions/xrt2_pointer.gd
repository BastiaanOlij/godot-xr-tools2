#-------------------------------------------------------------------------------
# xrt2_pointer.gd
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
class_name XRT2Pointer
extends XRT2HandAttachment

#region Event classes
class PointerEvent:
	var pointer: XRT2Pointer
	var pointing_at: Vector3
	var pressed: bool

class GainedFocusEvent extends PointerEvent:
	pass

class LostFocusEvent extends PointerEvent:
	pass

class PressedEvent extends PointerEvent:
	pass

class ReleasedEvent extends PointerEvent:
	pass

class MovedEvent extends PointerEvent:
	var was_pointing_at: Vector3
#endregion


#region Export variables
## Is our pointer enabled?
@export var enabled: bool = true:
	set(value):
		enabled = value

		if _laser:
			_laser.visible = show_laser and enabled
		if _raycast:
			_raycast.enabled = enabled
		if _interacting_pressed and not enabled:
			_released()
		if _focus_on and not enabled:
			_loose_focus()

		set_process(enabled and not Engine.is_editor_hint())

## Action in our action map that triggers our pressed state.
@export var press_action: String = "trigger"

## Color of our laser and target.
@export var color: Color = Color(1.0, 0.0, 0.0):
	set(value):
		color = value
		if is_inside_tree():
			_update_color()

## To what distance do we perform our raycast?
@export var cast_distance: float = 3.0:
	set(value):
		cast_distance = value
		if _laser:
			_update_laser()
		if _raycast:
			_update_raycast()

## What collision layers do we interact with?
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		if _raycast:
			_update_raycast()

## Does our ray collide with areas? Note that our UI components use areas so this is on by default.
@export var collide_with_areas: bool = true:
	set(value):
		collide_with_areas = value
		if _raycast:
			_raycast.collide_with_areas = collide_with_areas

## Does our ray collide with bodies? 
@export var collide_with_bodies: bool = false:
	set(value):
		collide_with_bodies = value
		if _raycast:
			_raycast.collide_with_bodies = collide_with_bodies

## Show our laser?
@export var show_laser: bool = true:
	set(value):
		show_laser = value
		if _laser:
			_laser.visible = show_laser and enabled

## Show our target? We only show this when we are colliding
@export var show_target: bool = false
#endregion


#region Private variables
var _raycast: RayCast3D
var _laser: MeshInstance3D
var _target: MeshInstance3D
var _override_laser_distance: float = 0.0
var _xr_controller: XRController3D

# Controlling our focus and interactions
var _focus_on: CollisionObject3D
var _interacting_point: Vector3 = Vector3()
var _interacting_pressed: bool = false
#endregion


#region Private functions
func _update_laser() -> void:
	var length = _override_laser_distance if _override_laser_distance > 0.0 else cast_distance
	_laser.position = Vector3(0.0, 0.0, -length * 0.5)
	# We scale instead of changing our mesh size, this prevents having to update the mesh on the GPU.
	_laser.scale = Vector3(1.0, length, 1.0)


func _update_raycast() -> void:
	_raycast.target_position = Vector3(0.0, 0.0, -cast_distance)
	_raycast.collision_mask = collision_mask


func _update_color() -> void:
	if _laser:
		var material: ShaderMaterial = _laser.mesh.surface_get_material(0)
		if material:
			material.set_shader_parameter("albedo", color)

	if _target:
		var material: ShaderMaterial = _target.mesh.surface_get_material(0)
		if material:
			material.set_shader_parameter("albedo", color)


# Is our action pressed?
func _is_action_pressed() -> bool:
	var input: Variant
	if _xr_collision_hand:
		input = _xr_collision_hand.get_input(press_action)
	elif _xr_controller:
		input = _xr_controller.get_input(press_action)

	if typeof(input) == TYPE_BOOL:
		return input
	elif typeof(input) == TYPE_FLOAT:
		# Should make this settable
		var threshold: float = 0.3 if _interacting_pressed else 0.7
		return input > threshold

	return false


# Update our properties
func _validate_property(property) -> void:
	super(property)

	# We manage these so hide them.
	if property.name in [ "bone_name", "position_offset", "rotation_offset" ]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# Called when we enter the scene tree.
func _enter_tree() -> void:
	super()

	if _xr_collision_hand:
		bone_name = "LeftMiddleMetacarpal" if _xr_collision_hand.hand == 0 else "RightMiddleMetacarpal"
		position_offset = Vector3(0.03 if _xr_collision_hand.hand == 0 else -0.03, 0.0, -0.06)
	else:
		_xr_controller = XRT2.get_xr_controller(self)

		# We should position our node based on the pose used for the controller.
		# We can use our position offset and rotation offset for this
		position_offset = Vector3(0.0, 0.0, 0.0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_laser = MeshInstance3D.new()
	_laser.mesh = load("res://addons/godot-xr-tools2/player/interaction_functions/laser_mesh.tres").duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	add_child(_laser, false, Node.INTERNAL_MODE_BACK)
	_laser.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_laser.visible = show_laser and enabled
	_update_laser()

	_target = MeshInstance3D.new()
	_target.mesh = load("res://addons/godot-xr-tools2/player/interaction_functions/target_mesh.tres").duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	add_child(_target, false, Node.INTERNAL_MODE_BACK)
	_target.top_level = true
	_target.visible = false

	_update_color()

	# In editor we don't need the rest.
	if Engine.is_editor_hint():
		set_process(false)
		return

	_raycast = RayCast3D.new()
	_raycast.collide_with_areas = collide_with_areas
	_raycast.collide_with_bodies = collide_with_bodies
	add_child(_raycast, false, Node.INTERNAL_MODE_BACK)
	_update_raycast()

	set_process(enabled)


func _exit_tree():
	_xr_controller = null
	super()


func _process(_delta: float) -> void:
	# In editor we don't do this
	if Engine.is_editor_hint():
		return

	# If not enabled, do nothing
	if not enabled:
		_target.visible = false
		return

	var pressed: bool = _is_action_pressed()

	if _interacting_pressed and _interacting_pressed != pressed:
		_released()

	if _raycast.is_colliding():
		var point = _raycast.get_collision_point()
		var obj = _raycast.get_collider()
		_override_laser_distance = (point - global_position).length()
		_update_laser()

		_target.visible = show_target
		_target.global_position = point

		# Ensure focus on this object, if it already is, nothing changes.
		_focus(obj, point)

		if _interacting_point != point:
			_moved(point)

		if pressed and _interacting_pressed != pressed:
			_pressed()
	else:
		_target.visible = false

		_loose_focus()

		_interacting_point = Vector3()

		if _override_laser_distance > 0.0:
			_override_laser_distance = 0.0
			_update_laser()


func _focus(on: CollisionObject3D, at: Vector3) -> void:
	if _focus_on == on:
		return
	if _focus_on:
		_loose_focus()

	_focus_on = on
	_interacting_point = at

	var event = GainedFocusEvent.new()
	event.pointer = self
	event.pointing_at = _interacting_point
	event.pressed = _interacting_pressed

	# As we don't have traits yet, good old fashioned duck typing
	if _focus_on.has_method("_xr_pointer_input"):
		_focus_on._xr_pointer_input(event)


func _loose_focus() -> void:
	if not _focus_on:
		return

	var event = LostFocusEvent.new()
	event.pointer = self
	event.pointing_at = _interacting_point
	event.pressed = _interacting_pressed

	# As we don't have traits yet, good old fashioned duck typing
	if _focus_on.has_method("_xr_pointer_input"):
		_focus_on._xr_pointer_input(event)

	_focus_on = null


func _pressed():
	if _interacting_pressed:
		return

	_interacting_pressed = true

	if not _focus_on:
		return

	var event = PressedEvent.new()
	event.pointer = self
	event.pointing_at = _interacting_point
	event.pressed = _interacting_pressed

	# As we don't have traits yet, good old fashioned duck typing
	if _focus_on.has_method("_xr_pointer_input"):
		_focus_on._xr_pointer_input(event)

	# Q: Possibly recording this so we always sent our release here?
	# Or do we add some sort of capture state for this?


func _released() -> void:
	if not _interacting_pressed:
		return

	_interacting_pressed = false

	if not _focus_on:
		return

	var event = ReleasedEvent.new()
	event.pointer = self
	event.pointing_at = _interacting_point
	event.pressed = _interacting_pressed

	# As we don't have traits yet, good old fashioned duck typing
	if _focus_on.has_method("_xr_pointer_input"):
		_focus_on._xr_pointer_input(event)


func _moved(to: Vector3):
	if not _focus_on:
		_interacting_point = to
		return

	var event = MovedEvent.new()
	event.pointer = self
	event.was_pointing_at = _interacting_point
	event.pointing_at = to
	event.pressed = _interacting_pressed
	_interacting_point = to

	# As we don't have traits yet, good old fashioned duck typing
	if _focus_on.has_method("_xr_pointer_input"):
		_focus_on._xr_pointer_input(event)

#endregion
