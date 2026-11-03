# =============================================================
# LEAPER — ALERT STATE
# =============================================================
# The "!" beat: faces the player and does a little hop-squash.
#
# Transitions:
#   -> "Stalk" : alert timer expires
# =============================================================

extends EnemyState

const ALERT_DURATION: float = 0.30

var _timer: float = 0.0
var _anim_tween: Tween = null


func enter() -> void:
	_timer = 0.0
	enemy.velocity.x = 0.0
	enemy.face_player()

	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.scale = Vector2.ONE
	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_property(spr, "scale", Vector2(1.3, 0.75), 0.08)
	_anim_tween.tween_property(spr, "scale", Vector2(0.85, 1.2), 0.08)
	_anim_tween.tween_property(spr, "scale", Vector2.ONE, 0.12)


func exit() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	enemy.get_node("Sprite2D").scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta
	enemy.apply_gravity(delta)
	enemy.velocity.x = 0.0
	enemy.move_and_slide()

	if _timer >= ALERT_DURATION:
		return "Stalk"
	return ""
