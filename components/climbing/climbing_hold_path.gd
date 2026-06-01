@tool
class_name ClimbingHoldPath
extends Path3D


@export var hand_hold_scene: PackedScene:
	set(value):
		hand_hold_scene = value

		# Clear our nodes, we're using a new scene
		for node in _hand_hold_nodes:
			remove_child(node)
			node.queue_free()
		_hand_hold_nodes.clear()

		if is_inside_tree():
			_update_hand_holds()

## How far ahead do we check to place our curve points?
@export var ray_distance: float = 2.0:
	set(value):
		ray_distance = value
		if is_inside_tree():
			if _align_to_surface():
				_update_hand_holds()

## Distance along the curve at which we place our hand holds
@export var path_spacing: float = 0.5:
	set(value):
		path_spacing = value
		if is_inside_tree():
			_update_hand_holds()

## Offset from center for each hand.
@export var hand_offset: float = 0.25:
	set(value):
		hand_offset = value
		if is_inside_tree():
			_update_hand_holds()

## Collisions to check
@export_flags_3d_physics var collision_mask: int = 0x02:
	set(value):
		collision_mask = value
		if is_inside_tree():
			if _align_to_surface():
				_update_hand_holds()


var _aligning_to_surface: bool = false
var _hand_hold_nodes: Array[Node3D]

func _align_to_surface() -> bool:
	# As we're changing our curve, we could get recursive calls.
	# Ignore those.
	if _aligning_to_surface:
		return false

	# If we don't have a curve, nothing to do...
	if not curve:
		return false

	_aligning_to_surface = true

	var inv_global_transform = global_transform.inverse()
	var state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

	query.collision_mask = collision_mask

	# Update our points based on our raycast.
	var z_offset := ray_distance * -0.5
	var normals: PackedVector3Array
	normals.resize(curve.point_count)
	for point in curve.point_count:
		var v: Vector3 = curve.get_point_position(point)
		v.z = z_offset
		v = global_transform * v

		query.from = v
		query.to = v + global_basis.z * ray_distance

		var result = state.intersect_ray(query)
		if result:
			v = result.position
			normals[point] = result.normal
		else:
			normals[point] = -global_basis.z

		# Localise this.
		v = inv_global_transform * v
		z_offset = v.z - (ray_distance * 0.5)

		# Set our new position
		curve.set_point_position(point, v)

		# Reset in, out and tilt so we can recalculate
		curve.set_point_in(point, Vector3())
		curve.set_point_out(point, Vector3())
		curve.set_point_tilt(point, 0)

	var up_vectors = curve.get_baked_up_vectors()
	for point in curve.point_count:
		var v := curve.get_point_position(point)

		# Set in and out
		if curve.point_count > 1:
			if point == 0:
				var v2 := curve.get_point_position(point + 1)
				curve.set_point_in(point, (v - v2) * 0.25)
				curve.set_point_out(point, (v2 - v) * 0.25)
			elif (point + 1) == curve.point_count:
				var v2 := curve.get_point_position(point - 1)
				curve.set_point_in(point, (v2 - v) * 0.25)
				curve.set_point_out(point, (v - v2) * 0.25)
			else:
				var v2 := curve.get_point_position(point - 1)
				var v3 := curve.get_point_position(point + 1)
				curve.set_point_in(point, (v2 - v3) * 0.25)
				curve.set_point_out(point, (v3 - v2) * 0.25)

		# Update tilt
		if normals[point] != Vector3():
			var up_vector = global_basis * up_vectors[point]

			var axis = v
			if point > 0:
				axis = axis - curve.get_point_position(point - 1)

			var angle = up_vector.signed_angle_to(normals[point], axis.normalized())
			curve.set_point_tilt(point, angle)

	_aligning_to_surface = false
	return true


func _update_hand_holds():
	# If we don't have a curve, nothing to do...
	if not curve:
		return
	if curve.point_count == 0:
		return
	if not hand_hold_scene:
		return

	var inv_global_transform = global_transform.inverse()
	var state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

	query.collision_mask = collision_mask

	var pos: float = 0.0
	var length: float = curve.get_baked_length()
	var new_hand_hold_nodes: Array[Node3D]
	var offset := hand_offset

	while pos < length:
		var node: Node3D
		if _hand_hold_nodes.is_empty():
			node = hand_hold_scene.instantiate()
			add_child(node, false, Node.INTERNAL_MODE_BACK)
		else:
			node = _hand_hold_nodes[0]
			_hand_hold_nodes.remove_at(0)
		new_hand_hold_nodes.push_back(node)

		var t: Transform3D = curve.sample_baked_with_rotation(pos, true, true)

		# Flip left/right
		t.origin += t.basis.x * (offset * randf_range(0.7, 1.3))
		offset = -offset

		# Seeing we're offset, double check distance to wall
		query.from = global_transform * (t.origin + t.basis.y * 0.5)
		query.to = global_transform * (t.origin - t.basis.y * 0.5)

		var result = state.intersect_ray(query)
		if result:
			t.origin = inv_global_transform * result.position

			var forward = (inv_global_transform.basis * result.normal).cross(Vector3.UP)
			t.basis = Basis.looking_at(forward, Vector3.UP, true)
		else:
			# Re-adjust our up is actually our forward.
			var forward = t.basis.y.cross(Vector3.UP)
			t.basis = Basis.looking_at(forward, Vector3.UP, true)

		# And place!
		node.transform = t

		pos += path_spacing * randf_range(0.9, 1.1)

	# Remove what we don't need anymore...
	for node in _hand_hold_nodes:
		remove_child(node)
		node.queue_free()

	_hand_hold_nodes = new_hand_hold_nodes

	# TODO optimise by creating multimeshes for rendering the meshes.
	if not _hand_hold_nodes.is_empty():
		pass


func _notification(what):
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			# Our node was moved, recalculate!
			if _align_to_surface():
				_update_hand_holds()


func _enter_tree():
	curve_changed.connect(_on_curve_changed)


func _ready():
	set_notify_transform(Engine.is_editor_hint())

	if curve:
		curve.bake_interval = 0.1

	# Update our hand holds
	_update_hand_holds()


func _exit_tree():
	curve_changed.disconnect(_on_curve_changed)


func _on_curve_changed():
	if is_inside_tree():
		# First align our changed points to our surface
		if _align_to_surface():
			# Now update our handholds
			_update_hand_holds()
