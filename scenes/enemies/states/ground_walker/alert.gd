# =============================================================
# GROUND WALKER — ALERT STATE
# =============================================================
# The enemy has just spotted the player. It pauses briefly,
# snaps to face them, and plays a short "lean forward" squash
# before launching into Chase.
#
# This is the classic "!" beat from HK / classic action games:
# the enemy telegraphs awareness before committing to aggro.
# It also prevents Chase from starting on the very same frame
# the detection zone is entered, which can feel instant and cheap.
#
# Duration: ALERT_DURATION seconds (non-interruptible by distance;
# only force_transition from Hurt/Death can cut it short).
#
# Transitions:
#   -> "Chase" : alert timer expires
# =============================================================

extends EnemyState

## How long the enemy pauses after spotting the player.
## 0.3 s feels like a natural reaction beat without being annoying.
const ALERT_DURATION: float = 0.30

var _timer: float = 0.0
var _anim_tween: Tween = null


func enter() -> void:
	_timer = 0.0
	enemy.velocity.x = 0.0

	# Snap to face the player immediately
	if is_instance_valid(enemy.player):
		var diff: float = enemy.player.global_position.x - enemy.global_position.x
		if diff != 0.0:
			enemy.set_facing(signi(int(diff)))

	# Quick "lean forward" squash — compress on X, stretch on Y, spring back.
	# This reads as "oh!" / "!" in body language.
	_play_alert_anim()


func exit() -> void:
	# Kill any in-flight tween so it doesn't fight subsequent state animations
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	# Restore scale in case tween was cut short
	enemy.get_node("Sprite2D").scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta

	# Stay frozen in place — this is a pure reaction beat
	enemy.apply_gravity(delta)
	enemy.velocity.x = 0.0
	enemy.move_and_slide()

	if _timer >= ALERT_DURATION:
		return "Chase"

	return ""


# ── Private ──────────────────────────────────────────────────────────────────

func _play_alert_anim() -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.scale = Vector2.ONE

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(Tween.TRANS_BACK)

	# Lean: compress wide, stretch tall (a "crouch" / attention pose)
	_anim_tween.tween_property(spr, "scale", Vector2(1.25, 0.80), 0.10)
	# Spring back to rest
	_anim_tween.tween_property(spr, "scale", Vector2.ONE, 0.18)
