# =============================================================
# GROUND WALKER — PATROL STATE
# =============================================================
# Enemy walks back and forth at run_speed.
# Turns around immediately on wall or ledge — no Idle pause.
# A short cooldown after each turn prevents the wall/ledge check
# from firing again on the very next frame before the enemy has
# had a chance to move away.
#
# Transitions:
#   -> "Chase" : player enters DetectionZone
# =============================================================

extends EnemyState

# Seconds to suppress the wall/ledge check after a direction flip.
# Gives the enemy time to physically move away from the trigger.
const TURN_COOLDOWN: float = 0.2

var _turn_cooldown: float = 0.0


func enter() -> void:
	_turn_cooldown = 0.0


func physics_update(delta: float) -> String:
	_turn_cooldown = maxf(_turn_cooldown - delta, 0.0)

	enemy.apply_gravity(delta)

	if enemy.player_in_detection_zone:
		return "Alert"

	var hit_wall:     bool = enemy.get_node("WallCheck").is_colliding()
	var floor_ahead:  bool = enemy.get_node("FloorCheck").is_colliding()

	if _turn_cooldown <= 0.0 and (hit_wall or not floor_ahead):
		# Flip direction and apply a brief cooldown — stay in Patrol
		enemy.set_facing(-enemy.facing_direction)
		_turn_cooldown  = TURN_COOLDOWN
		enemy.velocity.x = 0.0
		enemy.move_and_slide()
		return ""

	enemy.velocity.x = enemy.facing_direction * enemy.run_speed
	enemy.move_and_slide()
	return ""
