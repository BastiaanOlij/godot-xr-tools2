extends Node3D


func _on_lifetime_timer_timeout():
	queue_free()
