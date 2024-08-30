@tool
extends Node
class_name XRT2Helper

static func get_xr_controller(p_node : Node3D) -> XRController3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRController3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


static func get_xr_origin(p_node : Node3D) -> XROrigin3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XROrigin3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


static func get_xr_player_character(p_node : Node3D) -> XRT2PlayerCharacter:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRT2PlayerCharacter:
			return parent

		parent = parent.get_parent()

	# Not found
	return null
