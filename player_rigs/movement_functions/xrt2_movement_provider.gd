@tool
extends Node3D
class_name XRT2MovementProvider

## If ticked, this movement function is enabled
@export var enabled : bool = true

@onready var _xr_player_character : XRT2PlayerCharacter = XRT2Helper.get_xr_player_character(self)


# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var player_character = XRT2Helper.get_xr_player_character(self)
	if not player_character:
		warnings.push_back("This node requires an XRT2PlayerCharacter as an anchestor.")

	# Return warnings
	return warnings


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		return

	if _xr_player_character:
		_xr_player_character.register_movement_provider(self)


## Called by player characters physics process.
func handle_movement(player_character : XRT2PlayerCharacter, delta : float):
	# Implement on extended class.
	# Note: player character will perform move_and_slide and handle gravity,
	# you should implement 
	pass
