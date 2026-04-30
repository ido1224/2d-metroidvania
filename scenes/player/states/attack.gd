# =============================================================
# ATTACK STATE
# =============================================================
# Directional melee attack. Direction is sampled once on enter.
# Horizontal input is never used — attacks always travel in the
# current facing direction unless vertical input overrides:
#   Grounded : up input → UP attack. Everything else → facing.
#   Airborne : down input → DOWN (pogo). Up input → UP. Else → facing.
#   Down attack is air-only — you cannot slam the floor.
#
# Hitbox positioning:
#   RIGHT / LEFT  →  offset horizontally by hitbox_offset
#   UP            →  offset upward
#   DOWN          →  offset downward (also enables pogo bounce)
#
# Pogo bounce:
#   A downward attack that connects with anything triggers an
#   upward velocity impulse (player.pogo_force). The attack
#   duration still plays out normally; the player is simply
#   moving upward. On attack end the standard airborne check
#   returns "Fall", letting pogo chains work naturally.
#
# Transitions:
#   -> "Fall"  : attack ends while airborne (including after pogo)
#   -> "Run"   : attack ends on ground with horizontal input
#   -> "Idle"  : attack ends on ground with no input
# =============================================================

extends State

## Total attack state duration (seconds).
## HK nail is ~0.35–0.40 s total, with the hitbox active for only part of it.
@export var attack_duration: float = 0.35

# Distance from player origin to hitbox center, in pixels.
# Applied on all four axes depending on attack direction.
var hitbox_offset: float = 20.0

# --- Timed hitbox window ---
# The hitbox is NOT active for the full attack duration.
# Activate at 0.05 s (brief windup), deactivate at 0.20 s (start of recovery).
# The remaining 0.15 s is committed recovery — you're locked in but not dealing damage.
# This mirrors HK's nail structure and prevents mash-spam from being optimal.
const _HITBOX_ACTIVATE_TIME:   float = 0.05
const _HITBOX_DEACTIVATE_TIME: float = 0.20

var attack_timer: float = 0.0

# Tracked so the activate/deactivate each fire exactly once per swing.
var _hitbox_activated:   bool = false
var _hitbox_deactivated: bool = false

# Set to true once a pogo bounce has fired this attack.
# Prevents multiple bounces from one swing if the hitbox
# overlaps several hurtboxes in the same frame.
var _pogo_triggered: bool = false

# Set true the frame a hit lands — allows the attack to be cancelled
# immediately so the player isn't locked into recovery after connecting.
var _hit_connected: bool = false

# Active squash/lunge tween — killed and reset in exit() so a
# forced transition (e.g. taking damage) never leaves the sprite deformed.
var _anim_tween: Tween = null

# Sprite rest values captured at enter() — restored exactly on exit().
var _sprite_rest_pos: Vector2
var _sprite_rest_scale: Vector2


func enter() -> void:
	attack_timer     = 0.0
	_pogo_triggered  = false
	_hitbox_activated   = false
	_hitbox_deactivated = false
	_hit_connected      = false

	# Capture rest transform so exit() can restore it exactly
	_sprite_rest_pos   = player.sprite.position
	_sprite_rest_scale = player.sprite.scale

	# --- Sample direction ---
	# Horizontal input is never checked — the attack always goes in the
	# current facing direction unless vertical input overrides it.
	#
	# GROUNDED : up works (input_y < 0). Down is blocked — you can't
	#            slam the floor. Everything else → facing direction.
	# AIRBORNE : vertical wins. Down (input_y > 0) triggers the pogo.
	#            Up (input_y < 0) is still available. No vertical input
	#            → facing direction.
	#
	# get_axis("move_up","move_down"): negative = up held, positive = down held.
	#
	# IMPORTANT: We use player.grounded_at_frame_start instead of
	# player.is_on_floor() here. is_on_floor() reflects the result of the
	# most recent move_and_slide() call — if the player was falling and
	# pressed attack on the same frame they landed, is_on_floor() would be
	# true even though the attack was clearly intended as an airborne pogo.
	# grounded_at_frame_start is captured in player._physics_process BEFORE
	# any state runs its move_and_slide(), so it represents what the player
	# intended at button-press time, not where movement resolved them to.
	var input_y: float = Input.get_axis("move_up", "move_down")
	var dir: Vector2

	if player.grounded_at_frame_start:
		if input_y < 0.0:
			dir = Vector2.UP
		else:
			dir = Vector2.RIGHT * player.facing_direction
	else:
		if input_y > 0.0:
			dir = Vector2.DOWN
		elif input_y < 0.0:
			dir = Vector2.UP
		else:
			dir = Vector2.RIGHT * player.facing_direction

	player.attack_direction = dir

	# --- Position hitbox based on direction ---
	match dir:
		Vector2.RIGHT:
			player.hitbox.position = Vector2(hitbox_offset, 0.0)
		Vector2.LEFT:
			player.hitbox.position = Vector2(-hitbox_offset, 0.0)
		Vector2.UP:
			player.hitbox.position = Vector2(0.0, -hitbox_offset)
		Vector2.DOWN:
			player.hitbox.position = Vector2(0.0, hitbox_offset)

	# Update facing for horizontal attacks so the sprite matches
	if dir.x != 0.0:
		player.facing_direction = signi(int(dir.x))

	# Connect the hit signal now — hitbox activation happens in physics_update
	# at _HITBOX_ACTIVATE_TIME, not immediately on enter.
	player.hitbox.hit_landed.connect(_on_hit_landed)

	_play_attack_anim()


func exit() -> void:
	player.hitbox.deactivate()

	# Always disconnect the hit listener to avoid stale connections
	if player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.disconnect(_on_hit_landed)

	# Reset to default horizontal-right offset so other systems
	# (future combo states, etc.) start from a known position
	player.hitbox.position = Vector2(hitbox_offset, 0.0)

	# Kill any running tween and restore the sprite to its rest transform.
	# Without this, a forced transition (knockback, death) would leave the
	# sprite stuck mid-squash.
	if _anim_tween:
		_anim_tween.kill()
		_anim_tween = null
	player.sprite.position = _sprite_rest_pos
	player.sprite.scale    = _sprite_rest_scale


func physics_update(delta: float) -> String:
	attack_timer += delta

	# --- Timed hitbox window ---
	# Windup: hitbox is off for the first 0.05 s.
	# Active: 0.05 s → 0.20 s (0.15 s damage window).
	# Recovery: 0.20 s → 0.35 s — committed but not dealing damage.
	if not _hitbox_activated and attack_timer >= _HITBOX_ACTIVATE_TIME:
		_hitbox_activated = true
		player.hitbox.activate()
	elif _hitbox_activated and not _hitbox_deactivated and attack_timer >= _HITBOX_DEACTIVATE_TIME:
		_hitbox_deactivated = true
		player.hitbox.deactivate()

	# Gravity still applies — no floating during air attacks
	player.apply_gravity(delta)

	# Buffer dash presses during the attack so the player can queue
	# "attack → immediately dash out" without frame-perfect timing.
	# Only buffer if dash is actually unlocked — no point queuing otherwise.
	if Input.is_action_just_pressed("dash") and player.has_dash:
		player._dash_buffer = player.dash_buffer_duration

	# Allow limited horizontal drift during the attack window
	var input_dir: float = Input.get_axis("move_left", "move_right")
	if input_dir != 0.0:
		player.velocity.x = move_toward(
			player.velocity.x,
			input_dir * player.run_speed * 0.5,
			player.air_acceleration * delta
		)

	player.update_sprite()
	player.move_and_slide()

	# --- Hit cancel ---
	# A successful hit gives the player immediate control back —
	# no sitting through the recovery animation after connecting.
	# Treat _hit_connected the same as the timer expiring so the
	# buffered-dash / grounded-state logic runs exactly once.
	if _hit_connected:
		attack_timer = attack_duration

	# --- Attack window over ---
	if attack_timer >= attack_duration:
		# Buffered dash fires first — "attack → dash" with no dead frames.
		# Still gate on cooldown and aerial-dash limit so the buffer doesn't
		# bypass the rules — it just removes the timing requirement.
		if player._dash_buffer > 0.0 and player.dash_cooldown <= 0.0 and not player.used_aerial_dash:
			player._dash_buffer = 0.0
			return "Dash"

		if not player.is_on_floor():
			return "Fall"

		var move_input: float = Input.get_axis("move_left", "move_right")
		if move_input != 0.0:
			return "Run"
		return "Idle"

	return ""


# Placeholder attack animation: snap the sprite into a directional
# squash+lunge, then tween back to rest with a slight overshoot bounce.
#
# Horizontal attacks: flatten vertically, stretch horizontally, lunge sideways.
# Vertical attacks:   flatten horizontally, stretch vertically, lunge up/down.
#
# The tween writes only position and scale — never modulate — so it doesn't
# conflict with the damage flash or the hitstop hit-flash.
func _play_attack_anim() -> void:
	if _anim_tween:
		_anim_tween.kill()

	var dir: Vector2 = player.attack_direction
	var spr: Sprite2D = player.sprite

	# --- Squash/stretch and lunge direction ---
	var squash_scale: Vector2
	var lunge_offset: Vector2

	if dir.y == 0.0:
		# Horizontal: wide and flat, lunge sideways
		squash_scale = Vector2(_sprite_rest_scale.x * 1.35, _sprite_rest_scale.y * 0.65)
		lunge_offset = Vector2(dir.x * 7.0, 0.0)
	elif dir.y < 0.0:
		# Up: narrow and tall, lunge upward
		squash_scale = Vector2(_sprite_rest_scale.x * 0.65, _sprite_rest_scale.y * 1.35)
		lunge_offset = Vector2(0.0, -7.0)
	else:
		# Down: wide and flat, lunge downward
		squash_scale = Vector2(_sprite_rest_scale.x * 1.35, _sprite_rest_scale.y * 0.65)
		lunge_offset = Vector2(0.0, 7.0)

	# Snap into the squashed/lunged pose immediately (instant, no tween)
	spr.scale    = squash_scale
	spr.position = _sprite_rest_pos + lunge_offset

	# Tween back to rest with an EASE_OUT / TRANS_BACK overshoot — the slight
	# rebound makes the snap feel punchy rather than just snapping back.
	_anim_tween = player.create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(spr, "scale", _sprite_rest_scale, attack_duration * 0.85) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_property(spr, "position", _sprite_rest_pos, attack_duration * 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# Called by hitbox.hit_landed whenever this attack deals damage.
func _on_hit_landed() -> void:
	if player.attack_direction == Vector2.DOWN:
		# Pogo bounce — upward launch on a successful downward strike.
		# Guard prevents stacking if multiple hurtboxes are hit the same frame.
		if not _pogo_triggered:
			player.velocity.y = -player.pogo_force
			_pogo_triggered = true
			player.dash_cooldown    = 0.0
			player.used_aerial_dash = false
		_hit_connected = true
		# Down attacks never apply recoil — pogo IS the directional response.
		return

	# Signal hit cancel — exits recovery on the next physics_update check.
	_hit_connected = true

	# All other directions: push the player back opposite to the attack.
	# RIGHT attack → pushed left; LEFT → right; UP → slight downward nudge.
	player.velocity -= player.attack_direction * player.hit_recoil_force
