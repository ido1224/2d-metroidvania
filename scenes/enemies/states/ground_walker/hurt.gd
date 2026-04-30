# =============================================================
# GROUND WALKER — HURT STATE
# =============================================================
# Enemy staggers after taking a hit. Knockback drives horizontal
# movement while the stun is active; no voluntary movement.
#
# The stun is long enough to feel like a real stagger (not a
# single-frame flinch) while still letting the enemy recover and
# re-engage. It also gives the player a clear punish window on a
# successful hit — matching the HK design philosophy where
# hitting enemies feels impactful.
#
# Entered via EnemyStateMachine.force_transition("Hurt").
#
# Transitions (after stun expires):
#   -> "Chase"  : player is still in DetectionZone
#   -> "Patrol" : player has left DetectionZone
# =============================================================

extends EnemyState

## How long the stagger lasts (seconds).
## 0.55 s = ~33 frames — enemy is clearly stunned, player has time
## to land a follow-up hit or safely reposition.
@export var stun_duration: float = 0.55

var _stun_timer: float = 0.0


func enter() -> void:
	_stun_timer  = 0.0
	enemy.velocity.x = 0.0

	# Small scale squash on impact — visual snap of the hit landing
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	var t: Tween = enemy.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	# Hit squash: compress on the X axis (absorbing the blow)
	t.tween_property(spr, "scale", Vector2(0.6, 1.35), 0.06)
	t.tween_property(spr, "scale", Vector2.ONE,         0.20)


func physics_update(delta: float) -> String:
	_stun_timer += delta

	enemy.apply_gravity(delta)

	# Knockback drives horizontal movement; decayed by base_enemy each frame
	enemy.velocity.x = enemy.knockback_velocity.x
	enemy.move_and_slide()

	if _stun_timer >= stun_duration:
		if enemy.player_in_detection_zone:
			return "Chase"
		return "Patrol"

	return ""
