extends RigidBody3D

## Speed at which our bullet leaves our gun
@export_range(10.0, 1000.0, 10.0, "suffix:m/s") var initial_speed = 600.0

## Object to place at impact
@export var bullet_impact : PackedScene

var _is_alive = true

func _ready():
	linear_velocity = global_basis.z * initial_speed

func _on_lifetime_timer_timeout():
	_is_alive = false
	queue_free()


func _on_body_entered(body):
	var state : PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(get_rid())
	if state and bullet_impact and _is_alive and state.get_contact_count() > 0:
		var collider = state.get_contact_collider_object(0)
		var impact_point = state.get_contact_local_position(0)
		var impact_normal = state.get_contact_local_normal(0)

		var t : Transform3D
		t.origin = impact_point
		t = t.looking_at(impact_point - impact_normal)

		var impact : Node3D = bullet_impact.instantiate()
		collider.add_child(impact)
		impact.global_transform = t

		# TODO inform the object that we hit (if applicable)
		# that we hit it and how much damage we're doing

		_is_alive = false
		queue_free()
