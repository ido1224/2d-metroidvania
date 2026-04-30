# =============================================================
# GROUND WALKER — CHASE STATE
# =============================================================
# Enemy charges toward the player at 1.3× run_speed.
# Does NOT use FloorCheck — it will walk off ledges in pursuit.
#
# Unreachability bail-outs (→ Patrol):
#   • Player is more than 64 px above the enemy (on a higher
#     platform the enemy can't reach by walking).
#   • A wall is blocking the path and the enemy has been stuck
#     pressing against it for WALL_STUCK_TIME seconds.
#
# Transitions:
#   -> "Attack"  : player enters melee range
#   -> "Patrol"  : player leaves DetectionZone
#   -> "Patrol"  : player is unreachable (too high or wall-stuck)
# =============================================================

extends EnemyState

## Must match ATTACK_DIST in attack.gd
const ATTACK_DIST: float = 60.0

## If the player is this many pixels above the enemy, give up chasing.
## Prevents the enemy from vibrating against a ledge wall forever.
const UNREACHABLE_HEIGHT: float = 64.0

## Seconds the enemy must be wall-blocked before giving up.
## A small buffer so a momentary wall clip doesn't abort the chase.
const WALL_STUCK_TIME: float = 0.4

var _wall_stuck_timer: float = 0.0


func enter() -> void:
	_wall_stuck_timer = 0.0


func physics_update(delta: float) -> String:
	# Player may have been freed during a scene transition
	if not is_instance_valid(enemy.player):
		return "Patrol"

	enemy.apply_gravity(delta)

	# Always face the player
	var diff: float = enemy.player.global_position.x - enemy.global_position.x
	if diff != 0.0:
		enemy.set_facing(signi(int(diff)))

	# ── Unreachability: player is on a higher platform ──────────────────
	# Positive Y = down in Godot, so enemy.y > player.y means player is above.
	var height_diff: float = enemy.global_position.y - enemy.player.global_position.y
	if height_diff > UNREACHABLE_HEIGHT:
		return "Patrol"

	# ── Melee range → hand off to Attack ────────────────────────────────
	var dist: float = enemy.global_position.distance_to(enemy.player.global_position)
	if dist <= ATTACK_DIST:
		return "Attack"

	# ── Wall-stuck detection ─────────────────────────────────────────────
	# If a wall is blocking the path to the player, accumulate stuck time.
	# Abort chase once the threshold is reached.
	var wall_blocked: bool = enemy.get_node("WallCheck").is_colliding()
	if wall_blocked:
		_wall_stuck_timer += delta
		if _wall_stuck_timer >= WALL_STUCK_TIME:
			return "Patrol"
	else:
		_wall_stuck_timer = 0.0

	# ── Move toward player ───────────────────────────────────────────────
	enemy.velocity.x = enemy.facing_direction * enemy.run_speed * 1.3
	enemy.move_and_slide()

	# ── Lost the player ──────────────────────────────────────────────────
	if not enemy.player_in_detection_zone:
		return "Patrol"

	return ""
