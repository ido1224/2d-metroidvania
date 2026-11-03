# =============================================================
# SHOOTER — SHOOT STATE
# =============================================================
#   WINDUP   (0.45 s) — stops, glows orange and swells. The cue
#                       to get ready to dodge / swat. Aim is taken
#                       at the END of the windup.
#   FIRE              — one orb toward the player's position
#   RECOVERY (0.35 s) — recoil squash, then back to Reposition
#
# If line of sight is lost during the windup it holds fire and
# goes back to Reposition (cooldown not spent).
#
# Transitions:
#   -> "Reposition" : after recovery, or line of sight lost
# =============================================================

extends EnemyState

const WINDUP_DURATION: float = 0.45
const RECOVERY_DURATION: float = 0.35

enum Phase { WINDUP, RECOVERY }

var _phase: Phase = Phase.WINDUP
var _timer: float = 0.0
var _anim_tween: Tween = null


func enter() -> void:
	_phase = Phase.WINDUP
	_timer = 0.0
	enemy.velocity.x = 0.0
	enemy.get_node("Sprite2D").modulate = Color(1.6, 0.8, 0.3)
	_play_scale_tween(Vector2(1.25, 1.25), WINDUP_DURATION, Tween.TRANS_SINE)


func exit() -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color.WHITE
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	spr.scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
	enemy.move_and_slide()

	match _phase:
		Phase.WINDUP:
			enemy.face_player()
			if not enemy.has_line_of_sight():
				return "Reposition"
			if _timer >= WINDUP_DURATION:
				enemy.fire_at(enemy.player.global_position)
				_phase = Phase.RECOVERY
				_timer = 0.0
				enemy.get_node("Sprite2D").modulate = Color.WHITE
				# Recoil: squash back from the shot
				enemy.velocity.x = -float(enemy.facing_direction) * 40.0
				_play_scale_tween(Vector2(0.8, 1.15), 0.06, Tween.TRANS_QUAD)
				_anim_tween.tween_property(enemy.get_node("Sprite2D"), "scale", Vector2.ONE, 0.2)
		Phase.RECOVERY:
			if _timer >= RECOVERY_DURATION:
				return "Reposition"

	return ""


func _play_scale_tween(target: Vector2, duration: float, trans_type: int) -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(trans_type)
	_anim_tween.tween_property(spr, "scale", target, duration)
