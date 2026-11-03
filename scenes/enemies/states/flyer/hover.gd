# =============================================================
# FLYER — HOVER STATE (initial)
# =============================================================
# Drifts in a slow, wide loop around its home point with a small
# vertical bob, so it reads as alive while idle.
#
# Transitions:
#   -> "Alert" : player enters DetectionZone
# =============================================================

extends EnemyState

## Horizontal drift around home (pixels either side)
const DRIFT_X: float = 24.0

## Drift speed (radians/second) — much slower than the bob
const DRIFT_SPEED: float = 0.6


func physics_update(delta: float) -> String:
	var target: Vector2 = enemy.home_position + Vector2(
			sin(enemy.hover_time * DRIFT_SPEED) * DRIFT_X,
			enemy.bob_offset())
	enemy.steer_toward(target, enemy.run_speed * 0.5, 200.0, delta)
	enemy.move_and_slide()
	enemy.face_velocity()

	if enemy.player_in_detection_zone:
		return "Alert"
	return ""
