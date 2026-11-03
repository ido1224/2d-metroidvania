# =============================================================
# GROUND WALKER — ATTACK STATE
# =============================================================
# Three-phase attack sequence modelled on HK melee enemy behaviour:
#
#   WINDUP  (0.22 s)
#     Enemy freezes. Sprite squashes (wide/short) and tints red.
#     Player has a clear window to dash away or jump.
#     Hitbox is OFF — no chip damage on the telegraph.
#
#   LUNGE   (0.14 s)
#     Enemy surges forward at LUNGE_SPEED. Hitbox activates.
#     Sprite stretches (narrow/tall) — visual "snap" of the strike.
#     The lunge is fast enough to punish a player who doesn't react
#     to the telegraph but short enough to dodge cleanly.
#
#   RECOVERY  (0.35 s)
#     Hitbox deactivates immediately. Enemy slows to a stop.
#     Sprite springs back to rest scale.
#     THIS IS THE PUNISH WINDOW — the player should nail a hit here.
#
# Total = 0.71 s per swing cycle. The enemy can chain into another
# Attack if the player stays in melee range, mimicking the
# "aggressive but readable" pattern of HK's Wandering Husk.
#
# Transitions (after Recovery ends):
#   -> "Attack"  : player still within melee range  (chain)
#   -> "Chase"   : player within detection range
#   -> "Patrol"  : player has left detection range
# =============================================================

extends EnemyState

# ── Tuning ────────────────────────────────────────────────────────────────────

## Windup freeze duration (seconds)
const WINDUP_DURATION: float  = 0.22

## How fast the enemy surges during the lunge (px/s)
const LUNGE_SPEED: float      = 210.0

## How long the lunge lasts (seconds) — covers ~21 px at LUNGE_SPEED
const LUNGE_DURATION: float   = 0.10

## Recovery pause duration — the punish window (seconds)
const RECOVERY_DURATION: float = 0.70

## Melee trigger distance — must match chase.gd's ATTACK_DIST
const ATTACK_DIST: float      = 60.0

## Detection zone radius — must match DetectionZone shape in .tscn
const DETECT_DIST: float      = 120.0

## Hitbox centre offset from enemy origin (px)
const HITBOX_OFFSET: float    = 16.0

# ── State ─────────────────────────────────────────────────────────────────────

enum Phase { WINDUP, LUNGE, RECOVERY }

var _phase: Phase    = Phase.WINDUP
var _timer: float    = 0.0
var _anim_tween: Tween = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func enter() -> void:
	_phase = Phase.WINDUP
	_timer = 0.0
	enemy.velocity.x = 0.0
	_begin_windup()


func exit() -> void:
	# Guaranteed cleanup — runs even on force_transition (hurt mid-windup, etc.)
	enemy.get_node("Hitbox").deactivate()
	enemy.get_node("Sprite2D").modulate = Color.WHITE

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	enemy.get_node("Sprite2D").scale = Vector2.ONE


func physics_update(delta: float) -> String:
	_timer += delta
	enemy.apply_gravity(delta)

	match _phase:

		Phase.WINDUP:
			enemy.velocity.x = 0.0
			enemy.move_and_slide()
			if _timer >= WINDUP_DURATION:
				_begin_lunge()

		Phase.LUNGE:
			# Surge forward — hitbox is already live
			enemy.velocity.x = float(enemy.facing_direction) * LUNGE_SPEED
			enemy.move_and_slide()
			if _timer >= LUNGE_DURATION:
				_begin_recovery()

		Phase.RECOVERY:
			enemy.velocity.x = 0.0
			enemy.move_and_slide()
			if _timer >= RECOVERY_DURATION:
				return _pick_exit_state()

	return ""


# ── Phase transitions ─────────────────────────────────────────────────────────

func _begin_windup() -> void:
	_timer = 0.0
	_phase = Phase.WINDUP
	enemy.velocity.x = 0.0

	# Red telegraph tint
	enemy.get_node("Sprite2D").modulate = Color(1.0, 0.35, 0.35)

	# Squash: wide and short (enemy "coiling" for the strike)
	_play_scale_tween(Vector2(1.4, 0.7), 0.14, Tween.EASE_OUT, Tween.TRANS_QUAD)


func _begin_lunge() -> void:
	_timer = 0.0
	_phase = Phase.LUNGE

	# Yellow tint on lunge
	enemy.get_node("Sprite2D").modulate = Color(1.0, 0.9, 0.0)

	# Position and activate hitbox
	var hb = enemy.get_node("Hitbox")
	hb.position = Vector2(HITBOX_OFFSET * float(enemy.facing_direction), 0.0)
	hb.activate(Vector2(float(enemy.facing_direction), 0.0))

	# Stretch: narrow and tall (snap of the strike extending forward)
	_play_scale_tween(Vector2(0.7, 1.4), 0.06, Tween.EASE_OUT, Tween.TRANS_QUAD)


func _begin_recovery() -> void:
	_timer = 0.0
	_phase = Phase.RECOVERY

	# Hitbox off — punish window opens now
	enemy.get_node("Hitbox").deactivate()
	enemy.velocity.x = 0.0

	# Spring back to rest with a slight overshoot (TRANS_BACK gives bounce)
	_play_scale_tween(Vector2.ONE, 0.25, Tween.EASE_OUT, Tween.TRANS_BACK)


func _pick_exit_state() -> String:
	if not is_instance_valid(enemy.player):
		return "Patrol"

	var dist: float = enemy.global_position.distance_to(enemy.player.global_position)

	# NEVER return "Attack" here.
	# EnemyStateMachine.transition_to() skips exit()/enter() when the target
	# state is the same as the current state. Returning "Attack" while already
	# in Attack would leave _timer unreset, locking the enemy in the RECOVERY
	# branch forever — appearing completely frozen until the player leaves range.
	#
	# Returning "Chase" forces a genuine state change: Chase calls set_facing(),
	# then re-evaluates distance. If the player is still within ATTACK_DIST it
	# returns "Attack" on that very first frame — a real Attack→Chase→Attack
	# transition that properly calls enter() and resets _timer and _phase.
	if dist <= DETECT_DIST:
		return "Chase"
	return "Patrol"


# ── Animation helpers ─────────────────────────────────────────────────────────

func _play_scale_tween(
		target: Vector2,
		duration: float,
		ease_type: int,
		trans_type: int) -> void:
	var spr: Sprite2D = enemy.get_node("Sprite2D")

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = enemy.create_tween()
	_anim_tween.set_ease(ease_type)
	_anim_tween.set_trans(trans_type)
	_anim_tween.tween_property(spr, "scale", target, duration)
