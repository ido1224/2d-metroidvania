# =============================================================
# FLYER — ALERT STATE
# =============================================================
# Spotted the player: brakes to a stop in the air, snaps to face
# them, and does a quick "puff up" squash — the "!" beat before
# it commits to chasing.
#
# Transitions:
#   -> "Chase" : alert timer expires
# =============================================================

extends EnemyState

const ALERT_DURATION: float = 0.35

var _timer: float = 0.0
var _anim_tween: Tween = null


func enter() -> void:
	_timer = 0.0
	enemy.face_player()

	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.scale = Vector2.ONE
	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_property(spr, "scale", Vector2(1.3, 1.3), 0.10)
	_anim_tween.tween_property(spr, "scale", Vector2.ONE, 0.18)


func exit() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	enemy.get_node("Sprite2D").scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta
	# Brake in the air rather than stopping dead
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	enemy.move_and_slide()

	if _timer >= ALERT_DURATION:
		return "Chase"
	return ""
