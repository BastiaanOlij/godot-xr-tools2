extends RigidBody3D

## Speed at which our bullet leaves our gun
@export var initial_speed = 600.0

## Decal to place on impact
@export var bullet_impact_decal : PackedScene

func _ready():
	linear_velocity = global_basis.z * initial_speed

func _on_lifetime_timer_timeout():
	queue_free()


func _on_body_entered(body):
	$HitSound.play()

	# Not working atm, we're not getting accurate positioning
	if bullet_impact_decal and false:
		var impact : Node3D = bullet_impact_decal.instantiate()
		body.add_child(impact)
		impact.global_position = global_position + (linear_velocity.normalized() * 0.005)
		impact.look_at(global_position + linear_velocity)
