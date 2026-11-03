# =============================================================
# FLYER — RETURN STATE
# =============================================================
# Lost the player (or leashed out): flies back to its home point,
# then resumes hovering. Re-aggros only once it's back inside half
# its leash, so it can't ping-pong at the leash edge.
#
# Transitions:
#   -> "Hover" : reached home
#   -> "Alert" : player detected again while well inside the leash
# =============================================================

extends EnemyState

const HOME_TOLERANCE: float = 8.0


func physics_update(delta: float) -> String:
	enemy.steer_toward(enemy.home_position, enemy.run_speed, 240.0, delta)
	enemy.move_and_slide()
	enemy.face_velocity()

	var dist_home: float = enemy.global_position.distance_to(enemy.home_position)
	if enemy.player_in_detection_zone and dist_home < enemy.leash_distance * 0.5:
		return "Alert"
	if dist_home <= HOME_TOLERANCE:
		return "Hover"
	return ""
