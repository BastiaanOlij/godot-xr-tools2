extends PhysicalBone3D

func get_highlight_meshes() -> Array[MeshInstance3D]:
	var ret : Array[MeshInstance3D]

	ret.push_back(get_node("../../body_001"))

	return ret

func picked_up(by):
	var parent = get_parent()
	if parent.has_method("picked_up"):
		parent.picked_up(by)
