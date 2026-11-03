# =============================================================
# FLYER — HURT STATE
# =============================================================
# Knocked back on BOTH axes (no gravity to pull it down), short
# stun. A pogo from above knocks it downward.
#
# Entered via EnemyStateMachine.force_transition("Hurt").
#
# Transitions (after stun):
#   -> "Chase"  : player still detected
#   -> "Return" : player lost
# =============================================================

extends EnemyState

@export var stun_duration: float = 0.45

var _timer: float = 0.0


func enter() -> void:
	_timer = 0.0
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.rotation = 0.0
	var t: Tween = enemy.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(spr, "scale", Vector2(0.65, 1.3), 0.06)
	t.tween_property(spr, "scale", Vector2.ONE, 0.20)


func physics_update(delta: float) -> String:
	_timer += delta
	# Knockback (decayed by BaseEnemy every frame) drives all movement
	enemy.velocity = enemy.knockback_velocity
	enemy.move_and_slide()

	if _timer >= stun_duration:
		if enemy.player_in_detection_zone:
			return "Chase"
		return "Return"
	return ""
