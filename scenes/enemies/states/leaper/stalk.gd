# =============================================================
# LEAPER — STALK STATE
# =============================================================
# Creeps toward the player (slowly — the leap is the threat) and
# stops at ledges and walls instead of walking off or into them.
# If the player is right on top of it (e.g. it just landed on
# them) it backs off to get room to leap again — or, if it's
# cornered and can't, pounces at them from where it stands.
# Once the player is in leap range, the cooldown is over and the
# full arc is clear (Leaper.plan_leap), it commits to a Leap.
#
# Transitions:
#   -> "Leap"   : in range, cooldown ready, arc is safe
#   -> "Patrol" : player left DetectionZone
# =============================================================

extends EnemyState

## Horizontal leap range (pixels)
const LEAP_MIN: float = 24.0
const LEAP_MAX: float = 150.0

## Stops creeping closer once within this distance — it prefers to
## jump from mid range rather than walk right up to the player
const CREEP_STOP: float = 70.0

## Closer than this, it backs away to make room for the next leap
const BACKOFF_DIST: float = 40.0

## Creep speed as a fraction of run_speed
const CREEP_MULT: float = 0.6


func physics_update(delta: float) -> String:
	if not is_instance_valid(enemy.player) or not enemy.player_in_detection_zone:
		return "Patrol"

	enemy.apply_gravity(delta)
	enemy.face_player()

	var dx: float = enemy.player.global_position.x - enemy.global_position.x
	var adx: float = absf(dx)

	# Too close to leap normally but nowhere to back off to (e.g. a block
	# right behind it): allow a short pounce straight at the player instead
	# of standing there doing nothing.
	var cornered: bool = adx < BACKOFF_DIST and not enemy.can_step(-float(enemy.facing_direction))
	if (enemy.is_on_floor() and enemy.leap_ready()
			and (adx >= LEAP_MIN or cornered) and adx <= LEAP_MAX):
		if enemy.plan_leap() != Vector2.ZERO:
			return "Leap"

	var blocked: bool = (enemy.get_node("WallCheck").is_colliding()
			or not enemy.get_node("FloorCheck").is_colliding())
	var target_speed: float = 0.0
	var creep: float = enemy.run_speed * CREEP_MULT
	if adx > CREEP_STOP and not blocked:
		target_speed = float(enemy.facing_direction) * creep
	elif adx < BACKOFF_DIST and enemy.can_step(-float(enemy.facing_direction)):
		target_speed = -float(enemy.facing_direction) * creep
	enemy.velocity.x = move_toward(enemy.velocity.x, target_speed, 600.0 * delta)
	enemy.move_and_slide()
	return ""
