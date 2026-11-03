# =============================================================
# FLYER — DIVE STATE
# =============================================================
# Three phases, same readable shape as the Ground Walker's lunge:
#
#   WINDUP   (0.40 s)
#     Pulls back away from the player, red tint, squashes.
#     The dive direction is locked at the END of the windup, so
#     moving during the telegraph is what makes it miss.
#     Hitbox OFF.
#
#   DIVE     (up to 0.45 s)
#     Straight line at DIVE_SPEED along the locked direction.
#     Hitbox ON, sprite stretched along the dive. Hitting a wall
#     or the floor ends it early with a "bonk".
#
#   RECOVERY (0.60 s, or 1.0 s after a bonk)
#     Hitbox off, drifts to a stop. The punish window.
#
# Transitions (after Recovery):
#   -> "Chase"  : player still detected (Chase enforces the gap
#                 before the next dive)
#   -> "Return" : player lost
#
# Never returns "Dive" itself — same-state transitions are skipped
# by EnemyStateMachine, which would leave the phase timer unreset
# (see the note in ground_walker/attack.gd).
# =============================================================

extends EnemyState

const WINDUP_DURATION: float = 0.40
const PULLBACK_SPEED: float = 45.0

const DIVE_SPEED: float = 270.0
const DIVE_MAX_DURATION: float = 0.45

const RECOVERY_DURATION: float = 0.60
const BONK_RECOVERY_DURATION: float = 1.0

enum Phase { WINDUP, DIVE, RECOVERY }

var _phase: Phase = Phase.WINDUP
var _timer: float = 0.0
var _recovery_time: float = RECOVERY_DURATION
var _dive_dir: Vector2 = Vector2.DOWN
var _anim_tween: Tween = null


func enter() -> void:
	_begin_windup()


func exit() -> void:
	enemy.get_node("Hitbox").deactivate()
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color.WHITE
	spr.rotation = 0.0
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	spr.scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta

	match _phase:
		Phase.WINDUP:
			# Back away from the player while coiling
			var away := Vector2.UP
			if is_instance_valid(enemy.player):
				away = (enemy.global_position - enemy.player.global_position).normalized()
			enemy.velocity = enemy.velocity.move_toward(away * PULLBACK_SPEED, 300.0 * delta)
			enemy.move_and_slide()
			enemy.face_player()
			if _timer >= WINDUP_DURATION:
				_begin_dive()

		Phase.DIVE:
			enemy.velocity = _dive_dir * DIVE_SPEED
			enemy.move_and_slide()
			if enemy.get_slide_collision_count() > 0:
				_begin_recovery(true)
			elif _timer >= DIVE_MAX_DURATION:
				_begin_recovery(false)

		Phase.RECOVERY:
			enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			enemy.move_and_slide()
			if _timer >= _recovery_time:
				if enemy.player_in_detection_zone and is_instance_valid(enemy.player):
					return "Chase"
				return "Return"

	return ""


# ── Phases ───────────────────────────────────────────────────────────────────

func _begin_windup() -> void:
	_phase = Phase.WINDUP
	_timer = 0.0
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color(1.0, 0.35, 0.35)
	_play_scale_tween(Vector2(1.35, 0.75), 0.18, Tween.TRANS_QUAD)


func _begin_dive() -> void:
	_phase = Phase.DIVE
	_timer = 0.0

	# Lock the aim now — the player's position at the end of the telegraph
	if is_instance_valid(enemy.player):
		var to_player: Vector2 = enemy.player.global_position - enemy.global_position
		if not to_player.is_zero_approx():
			_dive_dir = to_player.normalized()
	if absf(_dive_dir.x) > 0.05:
		enemy.set_facing(1 if _dive_dir.x > 0.0 else -1)

	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color(1.0, 0.9, 0.0)
	# Point the stretch along the dive. Sprite rotation only — the body and
	# its hitbox are a square, so rotating them would change nothing.
	spr.rotation = _dive_dir.angle() - (PI if enemy.facing_direction == -1 else 0.0)
	_play_scale_tween(Vector2(1.5, 0.7), 0.06, Tween.TRANS_QUAD)

	# Knock the player straight sideways (the way the dive is travelling), not along the
	# dive itself: a dive from above pointed the knockback into the floor, so
	# the player barely moved. Straight-down dives use the facing direction.
	# player.gd adds its own upward lift for hits taken on the ground.
	var side: float = signf(_dive_dir.x) if absf(_dive_dir.x) > 0.15 else float(enemy.facing_direction)
	enemy.get_node("Hitbox").activate(Vector2(side, 0.0))


func _begin_recovery(bonked: bool) -> void:
	_phase = Phase.RECOVERY
	_timer = 0.0
	_recovery_time = BONK_RECOVERY_DURATION if bonked else RECOVERY_DURATION
	enemy.get_node("Hitbox").deactivate()

	var spr: Sprite2D = enemy.get_node("Sprite2D")
	spr.modulate = Color.WHITE
	spr.rotation = 0.0

	if bonked:
		# Small bounce off whatever it hit, and a dazed squash
		enemy.velocity = -_dive_dir * 90.0
		enemy.get_node("Sprite2D").modulate = Color(0.7, 0.7, 0.7)
		_play_scale_tween(Vector2(0.75, 1.3), 0.08, Tween.TRANS_QUAD)
		_anim_tween.tween_property(spr, "scale", Vector2.ONE, 0.3)
	else:
		_play_scale_tween(Vector2.ONE, 0.25, Tween.TRANS_BACK)


func _play_scale_tween(target: Vector2, duration: float, trans_type: int) -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.set_trans(trans_type)
	_anim_tween.tween_property(spr, "scale", target, duration)
