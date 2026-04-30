# =============================================================
# GROUND SLAM STATE
# =============================================================
# Triggered from any airborne state (Jump, Fall, Attack) with
# the ground_slam input (Q key by default).
#
# Player plunges straight down at high speed, dealing heavy
# damage to any enemy hit during the descent or on landing.
# Player is fully invincible for the entire duration.
#
# Transitions:
#   -> "Run"   : slam lands, horizontal input held
#   -> "Idle"  : slam lands, no input
# =============================================================

extends State

## Downward speed during the plunge (pixels/second)
@export var slam_speed: float = 600.0

## Damage dealt to any enemy hit during the slam
@export var slam_damage: int = 4

## How long the landing impact hitbox stays active (seconds)
const _IMPACT_DURATION: float = 0.08

var _landed: bool = false
var _impact_timer: float = 0.0

var _original_damage: int = 1
var _original_knockback: float = 200.0


func enter() -> void:
	_landed = false
	_impact_timer = 0.0

	# Store and override hitbox stats
	_original_damage   = player.hitbox.damage
	_original_knockback = player.hitbox.knockback_force
	player.hitbox.damage          = slam_damage
	player.hitbox.knockback_force = 350.0

	# Hitbox positioned at feet to detect enemies on the way down
	player.hitbox.position = Vector2(0.0, 10.0)
	player.hitbox.activate()

	# Lock velocity to straight-down plunge
	player.velocity = Vector2(0.0, slam_speed)

	# Fully invincible for the entire slam
	player.hurtbox.monitorable = false

	# Warm orange tint so the slam reads visually
	player.sprite.modulate = Color(1.0, 0.55, 0.1)


func exit() -> void:
	player.hitbox.deactivate()
	player.hitbox.damage          = _original_damage
	player.hitbox.knockback_force = _original_knockback
	player.hitbox.position        = Vector2(16.0, 0.0)

	player.hurtbox.monitorable = true
	player.sprite.modulate     = Color.WHITE


func physics_update(delta: float) -> String:
	if not _landed:
		# Lock to straight down — no air steering during the plunge
		player.velocity.x = 0.0
		player.velocity.y = slam_speed
		player.move_and_slide()

		if player.is_on_floor():
			_landed = true
			_impact_timer = _IMPACT_DURATION

			# Strong screen shake on impact
			player.get_node("PlayerCamera").shake(7.0)

			# Re-activate with cleared hit list so enemies at the
			# landing spot can be hit even if already grazed on the way down
			player.hitbox.deactivate()
			player.hitbox.activate()
	else:
		# Brief freeze at ground level so the impact hitbox fires
		_impact_timer -= delta
		player.velocity = Vector2.ZERO
		player.move_and_slide()

		if _impact_timer <= 0.0:
			var input_dir: float = Input.get_axis("move_left", "move_right")
			if input_dir != 0.0:
				return "Run"
			return "Idle"

	return ""
