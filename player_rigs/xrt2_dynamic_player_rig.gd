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

## This player rig is meant for games where the player can move around

@tool
class_name XRT2DynamicPlayerRig
extends XROrigin3D

#region Signals

## Our player has moved through virtual means.
signal player_moved(from_transform : Transform3D, to_transform : Transform3D, is_teleport : bool)

#endregion

const EYE_TO_TOP = 0.08

#region Export variables
## Enable move on input, if true we handle our movement providers
@export var enable_move_on_input : bool = true

## Auto calibrate the user to this height on recenter (set to 0.0 to disable)
@export_range(1.5, 2.5, 0.1) var target_player_height : float = 1.8:
	set(value):
		target_player_height = value
		if is_inside_tree():
			_physical_move_handler.player_target_eye_height = target_player_height - EYE_TO_TOP

# Registered movement providers
var _movement_providers : Array[XRT2MovementProvider]

# Node helpers
@onready var _physical_move_handler : XRT2PhysicalMovementHandler = $XRT2PhysicalMovementHandler

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
#endregion


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
	if not parent:
		push_warning("Parent node isn't a CharacterBody3D node, dynamic player rig is disabled!")


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

	# Handle our virtual movement
	if enable_move_on_input:
		var current_transform = parent.global_transform

		# TODO handle order of movement providers
		for provider : XRT2MovementProvider in _movement_providers:
			if provider.enabled:
				# TODO handle a way for a movement provider to inform us that
				# other movement providers should be ignore and whether it has
				# handled the movement completely and we should exit here
				provider.handle_movement(parent, delta)

		# Always handle gravity
		var gravity_state := PhysicsServer3D.body_get_direct_state(parent.get_rid())
		parent.velocity += gravity_state.total_gravity * delta

		# Now move and slide
		parent.move_and_slide()

		# TODO handle any collision with rigidbodies and transfer momentum

		# Check if we've moved and let anyone who wants to know, know.
		var delta_transform : Transform3D = parent.global_transform * current_transform.inverse()
		if delta_transform.origin.length() > 0.001:
			# TODO also check rotation!
			player_moved.emit(current_transform, parent.global_transform, false)
#endregion
