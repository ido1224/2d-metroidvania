# =============================================================
# SHOOTER — REPOSITION STATE
# =============================================================
# Keeps a comfortable firing distance while always facing the
# player:
#   closer than MIN_DIST (horizontally)  -> back away (a bit faster)
#   further than MAX_DIST, or no line of sight -> walk closer
#   otherwise                            -> hold position
# It never steps off a ledge or into a wall (Shooter.can_move);
# if it's cornered it just stands its ground and keeps shooting.
#
# Transitions:
#   -> "Shoot" : clear line of sight, cooldown ready, in range
#   -> "Idle"  : player left DetectionZone
# =============================================================

extends EnemyState

const MIN_DIST: float = 90.0
const MAX_DIST: float = 170.0

## Straight-line range it's willing to fire from
const SHOOT_MIN: float = 30.0
const SHOOT_MAX: float = 230.0

const BACKOFF_SPEED_MULT: float = 1.2


func physics_update(delta: float) -> String:
	if not is_instance_valid(enemy.player) or not enemy.player_in_detection_zone:
		return "Idle"

	enemy.apply_gravity(delta)
	enemy.face_player()

	var dx: float = enemy.player.global_position.x - enemy.global_position.x
	var toward: float = signf(dx) if absf(dx) > 0.5 else float(enemy.facing_direction)
	var los: bool = enemy.has_line_of_sight()

	var move_dir: float = 0.0
	var speed: float = enemy.run_speed
	if absf(dx) < MIN_DIST:
		move_dir = -toward
		speed *= BACKOFF_SPEED_MULT
	elif absf(dx) > MAX_DIST or not los:
		move_dir = toward
	if move_dir != 0.0 and not enemy.can_move(move_dir):
		move_dir = 0.0

	enemy.velocity.x = move_toward(enemy.velocity.x, move_dir * speed, 900.0 * delta)
	enemy.move_and_slide()

	var dist: float = enemy.global_position.distance_to(enemy.player.global_position)
	if los and enemy.shot_ready() and dist >= SHOOT_MIN and dist <= SHOOT_MAX:
		return "Shoot"
	return ""
