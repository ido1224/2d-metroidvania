# =============================================================
# LEAPER — LEAP STATE
# =============================================================
#   CROUCH (0.40 s)
#     Stops, red tint, squashes low. Aim is taken at the END of
#     the crouch, so moving during it is the dodge. If the arc is
#     no longer safe at that moment, it calls the jump off.
#     Hitbox OFF.
#
#   AIR
#     Flies the computed arc. Hitbox ON (its whole body), sprite
#     stretched. A wall stops its sideways motion; it still falls.
#
#   LAND (0.75 s)
#     Flattened and grey — dazed. Hitbox off. The punish window.
#
# Transitions:
#   -> "Stalk" : after landing, or the jump was called off
# Never returns "Leap" (same-state transitions are skipped by
# EnemyStateMachine — see ground_walker/attack.gd).
# =============================================================

extends EnemyState

const CROUCH_DURATION: float = 0.40
const LAND_DURATION: float = 0.75

## Give up on the airborne phase after this long (safety net: it
## should always land well before this)
const MAX_AIR_TIME: float = 2.5

enum Phase { CROUCH, AIR, LAND }

var _phase: Phase = Phase.CROUCH
var _timer: float = 0.0
var _left_floor: bool = false
var _anim_tween: Tween = null


func enter() -> void:
	_phase = Phase.CROUCH
	_timer = 0.0
	enemy.velocity.x = 0.0
	enemy.face_player()
	enemy.get_node("Sprite2D").modulate = Color(1.0, 0.35, 0.35)
	_play_scale_tween(Vector2(1.4, 0.6), CROUCH_DURATION * 0.8, Tween.TRANS_QUAD)


func exit() -> void:
	enemy.get_node("Hitbox").deactivate()
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color.WHITE
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	spr.scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta

	match _phase:
		Phase.CROUCH:
			enemy.apply_gravity(delta)
			enemy.velocity.x = 0.0
			enemy.face_player()
			enemy.move_and_slide()
			if _timer >= CROUCH_DURATION:
				var v: Vector2 = enemy.plan_leap()
				if v == Vector2.ZERO:
					return "Stalk"
				_launch(v)

		Phase.AIR:
			var vx: float = enemy.velocity.x
			enemy.apply_gravity(delta)
			enemy.move_and_slide()
			if enemy.is_on_wall():
				vx = 0.0
			enemy.velocity.x = vx   # keep the arc's sideways speed (no friction in the air)
			if not enemy.is_on_floor():
				_left_floor = true
			if (_left_floor and enemy.is_on_floor()) or _timer >= MAX_AIR_TIME:
				_land()

		Phase.LAND:
			enemy.apply_gravity(delta)
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1200.0 * delta)
			enemy.move_and_slide()
			if _timer >= LAND_DURATION:
				return "Stalk"

	return ""


func _launch(v: Vector2) -> void:
	_phase = Phase.AIR
	_timer = 0.0
	_left_floor = false
	enemy.velocity = v
	if absf(v.x) > 1.0:
		enemy.set_facing(1 if v.x > 0.0 else -1)
	enemy.get_node("Sprite2D").modulate = Color(1.0, 0.9, 0.0)
	_play_scale_tween(Vector2(0.75, 1.35), 0.08, Tween.TRANS_QUAD)
	# Its body is the weapon; knock the player straight sideways, the way it's flying
	var side: float = signf(v.x) if absf(v.x) > 1.0 else float(enemy.facing_direction)
	enemy.get_node("Hitbox").activate(Vector2(side, 0.0))


func _land() -> void:
	_phase = Phase.LAND
	_timer = 0.0
	enemy.get_node("Hitbox").deactivate()
	enemy.mark_landed()
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color(0.65, 0.65, 0.65)
	_play_scale_tween(Vector2(1.5, 0.6), 0.06, Tween.TRANS_QUAD)
	_anim_tween.tween_interval(LAND_DURATION * 0.5)
	_anim_tween.tween_property(spr, "scale", Vector2.ONE, LAND_DURATION * 0.4)


func _play_scale_tween(target: Vector2, duration: float, trans_type: int) -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(trans_type)
	_anim_tween.tween_property(spr, "scale", target, duration)
