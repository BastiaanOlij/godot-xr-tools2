extends PhysicalBoneSimulator3D

func picked_up(by):
	if not is_simulating_physics():
		physical_bones_start_simulation()
