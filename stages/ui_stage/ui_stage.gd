@tool
extends XRT2StageBase

## UI demo showing 2D UI interaction.
## This is a fun little demo showing a simple 2D mini game presented on a virtual game cabinet.

# Ideas for improvements in the future:
# - Have the player hold some light guns, these do not need to use pickable but can just be placed 
#   as child objects of the hands (probably with a XRT2HandAttachment node)
# - Obviously replace the cabinet with something properly modeled and textured
# - Maybe add a start button to the cabinet so we can also show how 2D and 3D interactions can
#   be mixed.
# - Possibly have some extra things around and show using another 2D interface.
# - Add sound effects!

# We only want the pointer on one hand to be active.
# The last controller on which a button was pressed will become the active controller
var _left_or_right: int = 1

@onready var _left_pointer = $XRT2CharacterBody3D/XROrigin3D/LeftCollisionHand/XRT2Pointer
@onready var _right_pointer = $XRT2CharacterBody3D/XROrigin3D/RightCollisionHand/XRT2Pointer

func _update_active_pointers() -> void:
	_left_pointer.enabled = _left_or_right == 0
	_right_pointer.enabled = _left_or_right == 1


func _ready() -> void:
	super()

	if Engine.is_editor_hint():
		return

	_update_active_pointers()


func _on_left_collision_hand_button_pressed(_action_name) -> void:
	if _left_or_right == 1:
		_left_or_right = 0
		_update_active_pointers()


func _on_left_collision_hand_input_float_changed(_action_name, _value) -> void:
	if _left_or_right == 1:
		_left_or_right = 0
		_update_active_pointers()


func _on_right_collision_hand_button_pressed(_action_name) -> void:
	if _left_or_right == 0:
		_left_or_right = 1
		_update_active_pointers()


func _on_right_collision_hand_input_float_changed(_action_name, _value) -> void:
	if _left_or_right == 0:
		_left_or_right = 1
		_update_active_pointers()
