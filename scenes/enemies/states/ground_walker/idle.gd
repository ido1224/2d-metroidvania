# =============================================================
# GROUND WALKER — IDLE STATE
# =============================================================
# Enemy stands still for a short random pause, then resumes
# Patrol. Used as a brief rest between patrol legs rather than a
# long loiter — HK enemies feel active, not lethargic.
#
# Transitions:
#   -> "Patrol" : idle timer expires
#   -> "Alert"  : player enters DetectionZone  (routes through the
#                 aggro-beat before committing to Chase)
# =============================================================

extends EnemyState

var _idle_timer: float    = 0.0
var _idle_duration: float = 1.0


func enter() -> void:
	enemy.velocity.x = 0.0
	_idle_timer    = 0.0
	# Short random pause — 0.4–0.9 s keeps the enemy feeling alive
	# without making it stand around doing nothing.
	_idle_duration = randf_range(0.4, 0.9)


func physics_update(delta: float) -> String:
	enemy.apply_gravity(delta)
	enemy.velocity.x = 0.0
	enemy.move_and_slide()

	_idle_timer += delta

	if enemy.player_in_detection_zone:
		return "Alert"

	if _idle_timer >= _idle_duration:
		return "Patrol"

	return ""
