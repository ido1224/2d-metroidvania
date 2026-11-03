# =============================================================
# SHOOTER — IDLE STATE (initial)
# =============================================================
# Stands still (a sentry) until the player is detected.
#
# Transitions:
#   -> "Alert" : player enters DetectionZone
# =============================================================

extends EnemyState


func physics_update(delta: float) -> String:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 600.0 * delta)
	enemy.move_and_slide()

	if enemy.player_in_detection_zone:
		return "Alert"
	return ""
