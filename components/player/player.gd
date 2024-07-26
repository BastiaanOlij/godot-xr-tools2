extends CharacterBody3D


# NOTE: this player setup likely needs to move into XR Tools so that it
# can interact properly with our movement functions (unless we make our movement
# function purely interact with velocity).
#
# But it should remain separate from our dynamic player rig.


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


@onready var _dynamic_player_rig : XRT2DynamicPlayerRig = $DynamicPlayerRig

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Player can't move if colliding.
	if not _dynamic_player_rig.get_player_is_colliding():
		# TODO: Change this to getting our inputs from our movement functions
		# so we get XR controller input

		# Handle jump.
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
