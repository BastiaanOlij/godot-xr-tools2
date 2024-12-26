extends PhysicalBoneSimulator3D


func _ready():
		physical_bones_start_simulation()


func picked_up(by):
	if not is_simulating_physics():
		physical_bones_start_simulation()
