# =============================================================
# SHOOTER — HURT STATE
# =============================================================
# Stagger with horizontal knockback (same feel as the walker's).
#
# Entered via EnemyStateMachine.force_transition("Hurt").
#
# Transitions (after stun):
#   -> "Reposition" : player still detected
#   -> "Idle"       : player lost
# =============================================================

extends EnemyState

@export var stun_duration: float = 0.45

var _timer: float = 0.0


func enter() -> void:
	_timer = 0.0
	enemy.velocity.x = 0.0
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	var t: Tween = enemy.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(spr, "scale", Vector2(0.6, 1.35), 0.06)
	t.tween_property(spr, "scale", Vector2.ONE, 0.20)


func physics_update(delta: float) -> String:
	_timer += delta
	enemy.apply_gravity(delta)
	enemy.velocity.x = enemy.knockback_velocity.x
	enemy.move_and_slide()

	if _timer >= stun_duration:
		if enemy.player_in_detection_zone:
			return "Reposition"
		return "Idle"
	return ""
