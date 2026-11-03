extends CharacterBody2D

# =============================================================
# PLAYER
# =============================================================
# Holds tuning variables, helper functions, and references to
# all components. The state machine drives the logic.
# =============================================================

# --- Horizontal Movement ---

## Max horizontal speed in pixels/second
@export var run_speed: float = 130.0

## How fast you reach full speed on ground (higher = snappier).
## HK reaches full speed in ~3 frames (0.05 s) → 175 / 0.05 ≈ 3500.
@export var ground_acceleration: float = 3000.0

## How fast you stop on ground when no input.
## Matched to ground_acceleration so stopping feels as snappy as starting.
@export var ground_friction: float = 3000.0

## How fast you change speed in air (lower = floatier)
@export var air_acceleration: float = 800.0

## How fast you slow down in air with no input
@export var air_friction: float = 400.0

# --- Jumping ---

## Upward velocity when jumping
@export var jump_force: float = 320.0

## Gravity in pixels/second squared (applied while rising)
@export var gravity: float = 1300.0

## Gravity multiplier while the player is falling (velocity.y > 0).
## 2.2 makes the descent ~1.5× faster than the ascent, matching HK's
## weighted feel without the fall becoming uncomfortably instant.
@export var fall_gravity_multiplier: float = 2.2

## Terminal velocity — max fall speed.
## HK caps fall speed at ~400 px/s — keeps aerials controllable.
@export var max_fall_speed: float = 400.0

## Multiplier for cutting jump short on early release (lower = bigger difference)
@export var jump_cut_multiplier: float = 0.4

# --- Dash ---

## Unlock the dash ability (false = dash input does nothing)
@export var has_dash: bool = false

## 0 = no dash, 1 = basic dash, 2 = upgraded (adds pierce on long cooldown)
@export var dash_level: int = 0

## Time between any dash (seconds)
@export var dash_cooldown_max: float = 0.6

## Time between pierce dashes — only used when dash_level == 2 (seconds)
@export var pierce_cooldown_max: float = 0.9

# --- Attack ---

## Direction of the current/most recent attack — set by Attack state on enter
var attack_direction: Vector2 = Vector2.RIGHT

## Upward velocity applied on a successful downward pogo strike.
## Slightly below jump_force — enough to chain reliably without being trivial.
@export var pogo_force: float = 300.0

## Velocity push applied to the player opposite to the attack direction
## when a hit connects — gives a tactile recoil on every successful strike.
## Down attacks are excluded (pogo handles that direction instead).
## HK recoil is hard and immediate; 200 makes it clearly readable.
@export var hit_recoil_force: float = 200.0

# --- Knockback ---

## How long input is suppressed after being hit (seconds).
## During this window handle_horizontal_movement does nothing, so the hit's
## velocity carries (no friction, no walking); jump/dash/attack still work.
## HK recovers control in ~9 frames = 0.15 s.
@export var knockback_duration: float = 0.15

# --- Input Buffers ---

## How long a pressed attack input is remembered when the current state
## can't act on it (e.g. mid-dash). 0.12 s ≈ 7 frames.
@export var attack_buffer_duration: float = 0.12

## How long a pressed dash input is remembered when the current state
## can't act on it (e.g. attack recovery). 0.15 s = the full dash window.
@export var dash_buffer_duration: float = 0.15

## Extra upward velocity added when the player is on the floor and takes a hit,
## so horizontal-only knockback is still visually readable on flat ground.
@export var knockback_lift: float = 220.0

# Counts down to 0; positive means knockback window is active
var _knockback_timer: float = 0.0

# Input buffer countdowns — positive means the action is queued.
# Set by states that can't immediately handle the input;
# consumed (zeroed) by the first state that can act on it.
var _attack_buffer: float = 0.0
var _dash_buffer:   float = 0.0

# --- Hitstop ---

## Seconds both attacker and target freeze when a hit connects.
## All _physics_process logic (cooldowns, state machine) is skipped while > 0.
## HK uses ~7 frames at 60 fps ≈ 0.12 s — just enough to register a hit clearly.
@export var hitstop_duration: float = 0.04

# Counts down each frame; set by hitbox.gd when a hit lands
var hitstop_time: float = 0.0

# --- State Tracking ---

var facing_direction: int = 1
var was_on_floor: bool = false

## True if the player was on the floor at the very start of this physics frame,
## captured BEFORE any move_and_slide() is called by any state.
## Attack state reads this instead of is_on_floor() so that a player who
## presses attack while falling but lands in the same physics step is still
## treated as airborne — the attack direction is what the player intended when
## they pressed the button, not where they ended up after movement resolved.
var grounded_at_frame_start: bool = false
var can_coyote_jump: bool = false
var has_jumped: bool = false

## Remaining cooldown before next dash is allowed (counts down each frame)
var dash_cooldown: float = 0.0

## Remaining cooldown before next pierce dash is allowed (counts down each frame)
var pierce_cooldown: float = 0.0

## True after an aerial dash until the player lands — blocks a second air dash
var used_aerial_dash: bool = false

# Looping tween that toggles sprite visibility during i-frames.
# Killed and reset by _on_invincibility_ended() when the window closes.
var _iframe_tween: Tween = null

# --- Node References ---

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var camera: Camera2D = $PlayerCamera

## Combat components — these are child nodes we'll add to the scene
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var health = $HealthComponent

# Particle burst played when the pierce dash charge becomes available again
var _pierce_ready_particles: CPUParticles2D

# Previous-frame dash_cooldown — used to detect the crossing from >0 to 0
var _prev_dash_cooldown: float = 0.0

## HUD that displays player health as heart pips
var _player_hud: CanvasLayer

const _HUD_SCENE := preload("res://scenes/ui/player_hud.tscn")


func _ready() -> void:
	add_to_group("player")

	# Connect health signals so we can react to damage and death
	if health:
		health.health_changed.connect(_on_health_changed)
		health.died.connect(_on_died)

	# Connect hurtbox so we can read the knockback vector on each hit.
	# HealthComponent connects to the same signal for damage — both fire.
	if hurtbox:
		hurtbox.hurt.connect(_on_hurtbox_hurt)
		hurtbox.invincibility_ended.connect(_on_invincibility_ended)

	# Spawn the HUD and wire it to the health component
	_player_hud = _HUD_SCENE.instantiate()
	add_child(_player_hud)
	if health:
		_player_hud.initialize(health.max_health)
		health.health_changed.connect(_player_hud.update_health)

	# Build the pierce-ready burst emitter at runtime so we don't need
	# a separate scene node for a simple one-shot effect
	_pierce_ready_particles = CPUParticles2D.new()
	_pierce_ready_particles.emitting = false
	_pierce_ready_particles.one_shot = true
	_pierce_ready_particles.explosiveness = 1.0   # all particles at once
	_pierce_ready_particles.amount = 12
	_pierce_ready_particles.lifetime = 0.4
	_pierce_ready_particles.initial_velocity_min = 40.0
	_pierce_ready_particles.initial_velocity_max = 80.0
	_pierce_ready_particles.spread = 180.0          # burst in all directions
	_pierce_ready_particles.gravity = Vector2.ZERO
	_pierce_ready_particles.color = Color(0.3, 0.8, 1.0)  # cyan — matches pierce tint
	add_child(_pierce_ready_particles)



# =============================================================
# DASH COOLDOWN TICKING
# =============================================================
# Runs every physics frame regardless of which state is active.
# States read dash_cooldown / pierce_cooldown but never write them
# (except dash.gd which resets them on enter).

func _physics_process(delta: float) -> void:
	# Snapshot floor state before any move_and_slide() runs this frame.
	# States call move_and_slide() inside their own _physics_process, which
	# Godot runs AFTER this (parent before children). So this value reflects
	# where the player truly was at frame start — not where movement put them.
	grounded_at_frame_start = is_on_floor()

	# Hitstop — freeze all processing while a hit-freeze is active
	if hitstop_time > 0.0:
		hitstop_time = maxf(hitstop_time - delta, 0.0)
		return

	# Tick knockback window
	_knockback_timer = maxf(_knockback_timer - delta, 0.0)

	# Tick input buffers
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_dash_buffer   = maxf(_dash_buffer   - delta, 0.0)

	# Tick regular dash cooldown and detect the moment it reaches zero
	_prev_dash_cooldown = dash_cooldown
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	if has_dash and _prev_dash_cooldown > 0.0 and dash_cooldown <= 0.0:
		_on_dash_ready()

	# Clear the aerial-dash lock the moment the player touches ground
	if used_aerial_dash and is_on_floor():
		used_aerial_dash = false

	# Tick pierce cooldown and fire a visual when it becomes available
	if dash_level == 2:
		var prev_pierce := pierce_cooldown
		pierce_cooldown = maxf(pierce_cooldown - delta, 0.0)
		if prev_pierce > 0.0 and pierce_cooldown <= 0.0:
			_on_pierce_ready()


## Called the moment the pierce dash charge refreshes.
## Plays a particle burst and a subtle camera jolt to communicate
## "pierce is ready" to the player without any UI.
func _on_pierce_ready() -> void:
	_pierce_ready_particles.restart()
	if camera:
		camera.shake(2.0)


func _on_dash_ready() -> void:
	pass


# =============================================================
# COMBAT CALLBACKS
# =============================================================

## Called when the player takes damage or heals
func _on_health_changed(current: int, max_hp: int) -> void:
	print("Player HP: ", current, "/", max_hp)

	# Flash white briefly when hit (visual feedback)
	if current < max_hp:
		_flash_damage()

	# Screen shake on hit — slightly stronger than landing a hit (getting hit feels worse)
	if camera:
		camera.shake(4.0)


## Called every time the hurtbox takes a hit — applies velocity impulse and
## starts the input-lockout window. Fires in parallel with HealthComponent's
## own listener on the same signal, so HP is already reduced by the time this runs.
func _on_hurtbox_hurt(_damage: int, knockback: Vector2) -> void:
	velocity = knockback

	# Ground hits are purely horizontal — add upward lift so the knockback
	# is visually readable and doesn't get instantly killed by ground friction.
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = -knockback_lift

	_knockback_timer = knockback_duration

	# Start the i-frame visibility flash — toggles every 0.08 s until
	# the hurtbox's invincibility window closes and fires invincibility_ended.
	_start_iframe_flash()


## Called when health reaches zero
func _on_died() -> void:
	print("Player died!")
	# For now, just reload the current scene.
	# Later we'll add a proper death screen.
	get_tree().reload_current_scene()


## Starts a looping visibility toggle every 0.08 s to signal i-frames.
## The loop runs indefinitely; _on_invincibility_ended() kills it.
## Writes to sprite.visible — does not conflict with the modulate flash.
func _start_iframe_flash() -> void:
	if _iframe_tween:
		_iframe_tween.kill()
	sprite.visible = true
	_iframe_tween = create_tween().set_loops()
	_iframe_tween.tween_callback(func(): sprite.visible = not sprite.visible)
	_iframe_tween.tween_interval(0.12)


## Called when hurtbox.invincibility_ended fires — stops the flash and
## guarantees the sprite is visible when the player can take damage again.
func _on_invincibility_ended() -> void:
	if _iframe_tween:
		_iframe_tween.kill()
		_iframe_tween = null
	sprite.visible = true


## Brief white flash to show the player got hit.
## Modulate tints the entire sprite.
func _flash_damage() -> void:
	sprite.modulate = Color(10, 10, 10)  # Bright white flash
	# Create a quick tween to fade back to normal
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


# =============================================================
# HELPER FUNCTIONS (called by states)
# =============================================================

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		# Apply a heavier multiplier while falling so the descent is noticeably
		# faster than the ascent — the core of the HK "weighty" jump arc.
		var g: float = gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func handle_horizontal_movement(delta: float) -> void:
	# During the short knockback window, let the hit's velocity carry.
	# Without this, ground friction (3000 px/s²) erased a 200 px/s knockback
	# within ~4 frames — hits only moved the player ~11 px (measured).
	# Jump, dash and attack are separate states, so they still work here;
	# only walking/friction waits the 0.15 s out.
	if _knockback_timer > 0.0:
		return

	var fric: float = ground_friction if is_on_floor() else air_friction

	var input_dir: float = Input.get_axis("move_left", "move_right")
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration

	if input_dir != 0.0:
		var is_turning: bool = (input_dir > 0.0 and velocity.x < 0.0) or (input_dir < 0.0 and velocity.x > 0.0)

		if is_on_floor() and is_turning:
			velocity.x = input_dir * run_speed
		else:
			velocity.x = move_toward(velocity.x, input_dir * run_speed, accel * delta)

		facing_direction = signi(int(input_dir))
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func update_sprite() -> void:
	sprite.flip_h = (facing_direction == 1)


func update_coyote_time() -> void:
	if is_on_floor():
		has_jumped = false

	if was_on_floor and not is_on_floor() and not has_jumped:
		can_coyote_jump = true
		coyote_timer.start()

	was_on_floor = is_on_floor()


func _on_coyote_timer_timeout() -> void:
	can_coyote_jump = false


func perform_jump() -> void:
	velocity.y = -jump_force
	has_jumped = true
	can_coyote_jump = false
