extends CharacterBody3D
class_name XRT2PlayerCharacter

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Helper variables to keep our code readable
@onready var _player_rig_node : XRT2DynamicPlayerRig = $DynamicPlayerRig
@onready var _camera_node : XRCamera3D = $DynamicPlayerRig/XRCamera3D

@onready var _reset_basis : Basis = $DynamicPlayerRig.global_basis

var _movement_providers : Array[XRT2MovementProvider]


## Register a movement provider that will provide movement for this player character
func register_movement_provider(p_movement_provider : XRT2MovementProvider):
	if not _movement_providers.has(p_movement_provider):
		_movement_providers.push_back(p_movement_provider)

## `recenter` is called when the user has requested their view to be recentered.
func recenter():
	# Make sure our player faces forward
	global_basis = _reset_basis

	# Center our XRCamera on our XROrigin node
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

	# Reset our XROrigin3D node
	_player_rig_node.transform = Transform3D()

	# Center our XRCamera3D node
	_camera_node.position.x = 0.0
	_camera_node.position.z = 0.0


# _physics_process handles our virtual player movement.
# Note that physical movement is handled in our Dynamic Player Rig
func _physics_process(delta):
	# Only allow player movement if they haven't stuck their head where it doesn't belong ;)
	if !_player_rig_node.get_player_is_colliding():
		# TODO handle order of movement providers
		for provider : XRT2MovementProvider in _movement_providers:
			if provider.enabled:
				# TODO handle a way for a movement provider to inform us that
				# other movement providers should be ignore and whether it has
				# handled the movement completely and we should exit here
				provider.handle_movement(self, delta)

	# Always handle gravity
	velocity.y -= gravity * delta

	# Now move and slide
	move_and_slide()

	# TODO handle any collision with rigidbodies and transfer momentum
