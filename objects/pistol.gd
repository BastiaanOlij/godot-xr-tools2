extends RigidBody3D

@export var recoil_force = 10.0
@export var slider_force = 40.0

@export var bullet_scene : PackedScene

@onready var slider = $SliderJoint3D/Slide

var _can_shoot = true
var _slider_extended = false

# This should be moved to our magazine
var _bullets_left = 10

func do_action():
	# Can't shoot on cooldown or if our slider is partially open
	if not _can_shoot or slider.position.length() > 0.01:
		return

	# We're shooting, can't shoot again until cooldown
	_can_shoot = false

	if $BulletInChamber.visible:
		# No more bullet in chamber
		$BulletInChamber.visible = false

		# Spawn our bullet
		if bullet_scene:
			var new_bullet : RigidBody3D = bullet_scene.instantiate()
			$BulletSpawnPoint.add_child(new_bullet)
			new_bullet.top_level = true

		# TODO show ShellInChamber

		# Play shoot animation
		$AnimationPlayer.play("Shoot")

		# Recoil
		apply_impulse(-global_basis.z * recoil_force, $BulletSpawnPoint.global_position - global_position)

		# The recoil can be enough to slide back our slide, but we're going to force a reload here.
		# TODO
	else:
		# Play no shoot sound
		$NoShootSound.play()
		pass

	# Cooldown!
	$CooldownTimer.start()


func _physics_process(_delta):
	# Factor of slider being open
	var factor = slider.position.length() / 0.05

	# Simulate spring on slider
	# var force = slider.global_basis.z * (factor + 0.5) * slider_force
	var force = slider.global_basis.z * slider_force

	# Apply a force to our slider so it springs closed.
	slider.apply_central_force(force)

	# Apply a counter force on our gun so that our gun doesn't start spinning.
	apply_force(-force, $SliderJoint3D.global_position - global_position)

	# Trigger bullet reload on slider
	if not _slider_extended and factor > 0.8:
		_slider_extended = true

		# Don't upset the user and eject unfired bullets (though it would be more accurate)
		if not $BulletInChamber.visible:
			$SliderJoint3D/Slide/SlideSound.play()

			# TODO handle bullet reload
			# - eject current bullet/shell
			# - slide in new bullet
			# - cock hammer

			# TODO bullet left should be sourced from loaded mag
			if _bullets_left > 0:
				$BulletInChamber.visible = true
				_bullets_left = _bullets_left - 1

			# TODO this should also move into the mag
			$"Pistol2/Pistol/magazine (loaded)/9mm".visible = _bullets_left > 0
			$"Pistol2/Pistol/magazine (loaded)/9mm_001".visible = _bullets_left > 1

	if _slider_extended and factor < 0.2:
		_slider_extended = false

func _on_cooldown_timer_timeout():
	_can_shoot = true
