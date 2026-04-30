# =============================================================
# DASH STATE
# =============================================================
# Player performs a fast horizontal burst in the current
# facing direction.
#
# Two modes depending on player.dash_level and pierce_cooldown:
#   Regular dash  : hurtbox stays active — taking a hit during
#                   the dash immediately cancels it and damage
#                   is processed normally.
#   Pierce dash   : hurtbox is disabled for the duration —
#                   player passes through enemy attacks entirely.
#                   Only available when dash_level == 2 AND
#                   pierce_cooldown <= 0.
#
# Cooldowns (ticked in player._physics_process):
#   dash_cooldown   : prevents spamming any dash
#   pierce_cooldown : gates the pierce upgrade specifically
#
# Transitions:
#   -> "Fall"  : dash finishes while airborne
#   -> "Idle"  : dash finishes while grounded, no input
#   -> "Run"   : dash finishes while grounded, input held
#   -> "Idle"  : non-pierce dash, player was hit (damage
#                already applied through hurtbox pipeline)
#   -> "Fall"  : non-pierce dash, player was hit while airborne
# =============================================================

extends State

## Horizontal speed during the dash (pixels/second)
@export var dash_speed: float = 350.0

## How long the dash lasts (seconds).
## Distance = dash_speed × dash_duration. At 350×0.15 ≈ 52 px.
@export var dash_duration: float = 0.15

# --- Internal state ---

## Elapsed time in current dash
var dash_timer: float = 0.0

# Countdown until the next afterimage ghost is spawned.
# Reset to _GHOST_INTERVAL each time a ghost is emitted.
var _ghost_timer: float = 0.0
const _GHOST_INTERVAL: float = 0.04  # ~25 ghosts/second = 4–5 per dash

## Normalised direction vector locked in at dash start
var dash_dir: Vector2 = Vector2.RIGHT

## True when this dash was resolved as a pierce dash on enter
var is_pierce_dash: bool = false

## Set to true by _on_hit_during_dash signal listener
var _was_hit: bool = false


func enter() -> void:
	dash_timer = 0.0
	_ghost_timer = 0.0
	_was_hit = false

	# HK-style: the Mothwing Cloak is always horizontal.
	# Read the held horizontal input; fall back to the current facing direction
	# if no horizontal key is pressed (avoids accidentally dashing backward
	# when only up/down is held).
	var raw_x: float = Input.get_axis("move_left", "move_right")
	var dir_x: float = raw_x if absf(raw_x) > 0.3 else float(player.facing_direction)
	dash_dir = Vector2(signf(dir_x), 0.0)

	# Update facing so the sprite matches the horizontal component
	if dash_dir.x != 0.0:
		player.facing_direction = signi(int(dash_dir.x))
		player.update_sprite()

	# Every dash (pierce or not) consumes the regular cooldown
	player.dash_cooldown = player.dash_cooldown_max

	# Mark that an aerial dash was used — blocks another dash until landing
	if not player.is_on_floor():
		player.used_aerial_dash = true

	# Decide if this is a pierce dash
	is_pierce_dash = (player.dash_level == 2 and player.pierce_cooldown <= 0.0)

	if is_pierce_dash:
		# Consume the pierce charge
		player.pierce_cooldown = player.pierce_cooldown_max
		# Disable hurtbox so enemy hits pass through completely
		player.hurtbox.monitorable = false
		# Visual: cyan tint to distinguish pierce from regular dash
		player.sprite.modulate = Color(0.3, 0.8, 1.0)
	else:
		# Regular dash: hurtbox stays live — listen for a hit so we
		# can exit the dash state the moment damage is taken
		player.hurtbox.hurt.connect(_on_hit_during_dash)


func exit() -> void:
	if is_pierce_dash:
		# Re-enable hurtbox now that the dash is over
		player.hurtbox.monitorable = true
		# Restore normal sprite colour (only we changed it)
		player.sprite.modulate = Color.WHITE
	else:
		# Clean up the one-shot signal connection
		if player.hurtbox.hurt.is_connected(_on_hit_during_dash):
			player.hurtbox.hurt.disconnect(_on_hit_during_dash)


func physics_update(delta: float) -> String:
	# Hold the exact dash velocity every frame — no gravity, no friction
	player.velocity = dash_dir * dash_speed

	dash_timer += delta

	# Afterimage trail — spawn a faded ghost sprite on a fixed interval
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = _GHOST_INTERVAL
		_spawn_afterimage()

	# Buffer attack presses during the dash so the player can queue
	# "dash → immediately attack" without needing frame-perfect timing.
	if Input.is_action_just_pressed("attack"):
		player._attack_buffer = player.attack_buffer_duration

	# Always call move_and_slide exactly once before any early returns
	player.move_and_slide()

	# --- Non-pierce: bail out immediately if we took a hit ---
	# (damage has already been applied through hurtbox → health_component)
	if not is_pierce_dash and _was_hit:
		if player.is_on_floor():
			return "Idle"
		else:
			return "Fall"

	# --- Dash finished ---
	if dash_timer >= dash_duration:
		# Buffered attack fires first — "dash → attack" with no dead frames.
		if player._attack_buffer > 0.0:
			player._attack_buffer = 0.0
			return "Attack"
		if not player.is_on_floor():
			return "Fall"
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			return "Run"
		return "Idle"

	return ""


# Duplicates the player's Sprite2D at its current world-space transform,
# parents it to the room so it stays behind as the player moves forward,
# then tweens its alpha to 0 and frees itself.
# Pierce ghosts inherit the cyan modulate automatically (duplicate copies it).
func _spawn_afterimage() -> void:
	var ghost: Sprite2D = player.sprite.duplicate() as Sprite2D
	# Add to the room (player's parent) so the ghost lives in world space
	var room: Node = player.get_parent()
	room.add_child(ghost)
	# Copy the world-space transform so the ghost renders exactly where the
	# sprite currently is, independent of the player node's movement.
	ghost.global_transform = player.sprite.global_transform
	ghost.modulate.a = 0.5

	var t: Tween = ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.12)
	t.finished.connect(ghost.queue_free)


# Called by the hurtbox.hurt signal during a regular (non-pierce) dash.
# We just set a flag — the transition happens in physics_update so
# move_and_slide is still called exactly once this frame.
func _on_hit_during_dash(_damage: int, _knockback: Vector2) -> void:
	_was_hit = true
