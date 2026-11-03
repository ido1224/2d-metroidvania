# =============================================================
# BASE ENEMY
# =============================================================
# Shared foundation for all enemy types. Handles:
#   - Gravity
#   - Facing direction (flips Sprite2D + RayCast2Ds)
#   - Knockback application and decay
#   - Damage flash
#   - Death tween + queue_free
#   - Detection/Attack zone tracking (player_in_detection_zone,
#     player_in_attack_zone booleans read by states)
#   - Wiring up Hurtbox → hurt signal and HealthComponent → died
#
# Required child nodes in every concrete enemy scene:
#   Sprite2D, CollisionShape2D,
#   StateMachine (EnemyStateMachine),
#   Hurtbox (Area2D with hurtbox.gd),
#   Hitbox  (Area2D with hitbox.gd),
#   HealthComponent (Node with health_component.gd),
#   DetectionZone (Area2D, mask = Player layer 2),
#   AttackZone    (Area2D, mask = Player layer 2),
#   WallCheck (RayCast2D),
#   FloorCheck (RayCast2D)
# =============================================================

class_name BaseEnemy
extends CharacterBody2D

signal enemy_died
signal enemy_damaged(current_hp: int, max_hp: int)

# --- Tuning ---

## Horizontal movement speed (pixels/second)
@export var run_speed: float = 60.0

## Terminal fall speed (pixels/second)
@export var max_fall_speed: float = 600.0

## How quickly knockback fades — higher = shorter slide (units: fraction lost per second,
## fed into lerp each frame). 8.0 ≈ knockback gone in ~0.12s — quick jolt, not a slide.
@export var knockback_decay: float = 8.0

# --- Runtime state ---

## Reference to the player node; null-safe everywhere it's used
var player: CharacterBody2D

## 1 = facing right, -1 = facing left
var facing_direction: int = 1

## Accumulated knockback — applied additively by the Hurt state
var knockback_velocity: Vector2 = Vector2.ZERO

## Set true when the player enters the DetectionZone, false when they leave
var player_in_detection_zone: bool = false

## Set to true the moment death is triggered; guards against double force_transition
var is_dead: bool = false

## Seconds both attacker and target freeze when a hit connects.
## All _physics_process logic is skipped while > 0.
## Matched to player.hitstop_duration — both sides freeze for the same window.
@export var hitstop_duration: float = 0.12

# Counts down each frame; set by a hitbox when a hit connects
var hitstop_time: float = 0.0

# Gravity fetched from project settings so it matches the physics world
var _gravity: float


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	player = get_tree().get_first_node_in_group("player")

	# Hurtbox.hurt fires when a Hitbox overlaps this enemy.
	# HealthComponent also connects to this signal internally to apply
	# take_damage(). We connect here for knockback, flash, and state
	# transitions — DO NOT call take_damage again (would double-damage).
	$Hurtbox.hurt.connect(_on_hurt)

	# HealthComponent signals
	$HealthComponent.died.connect(_on_died)

	# Detection zone body tracking
	$DetectionZone.body_entered.connect(_on_detection_entered)
	$DetectionZone.body_exited.connect(_on_detection_exited)

	# Contact damage — fires whenever the player's hurtbox overlaps the enemy
	# body, independent of any attack state. Uses the player's own i-frames to
	# rate-limit damage, so no extra timer is needed here.
	if has_node("BodyArea"):
		$BodyArea.area_entered.connect(_on_body_contact)


func _physics_process(delta: float) -> void:
	# Hitstop — freeze all processing while a hit-freeze is active
	if hitstop_time > 0.0:
		hitstop_time = maxf(hitstop_time - delta, 0.0)
		return

	# Decay knockback every frame regardless of state.
	# lerp-based so the rate is framerate-independent (knockback_decay = fraction lost/second).
	# The Hurt state reads knockback_velocity.x to drive movement.
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)
	if knockback_velocity.length() < 0.5:
		knockback_velocity = Vector2.ZERO


# =============================================================
# HELPERS (called by states)
# =============================================================

## Apply gravity up to max_fall_speed. Call in physics_update().
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, max_fall_speed)


## Change facing direction, flip sprite, and realign RayCast2Ds.
func set_facing(direction: int) -> void:
	facing_direction = direction
	$Sprite2D.flip_h = (direction == -1)

	# Keep raycasts always pointing in the direction the enemy is moving
	if has_node("WallCheck"):
		$WallCheck.target_position.x = absf($WallCheck.target_position.x) * direction
	if has_node("FloorCheck"):
		$FloorCheck.target_position.x = absf($FloorCheck.target_position.x) * direction


## Compute knockback direction from a world-space source position and apply it.
## Useful for projectile impacts or area-of-effect damage sources.
func apply_knockback(source_global_position: Vector2, force: float) -> void:
	var direction: Vector2 = (global_position - source_global_position).normalized()
	knockback_velocity = Vector2(direction.x, 0.0) * force


## Brief over-bright flash to signal that the enemy took a hit.
func flash() -> void:
	$Sprite2D.modulate = Color(1.0, 0.2, 0.2)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


## Tween the Sprite2D scale to [target] over [duration] seconds.
## Uses EASE_OUT / TRANS_BACK by default for a springy feel.
## Kills any tween assigned to [tween_slot] first so callers can
## track the Tween to cancel it if the state changes mid-animation.
##
## Usage (from a state):
##   enemy.squash_stretch(Vector2(1.3, 0.75), 0.12)
func squash_stretch(
		target: Vector2,
		duration: float,
		ease_type: int = Tween.EASE_OUT,
		trans_type: int = Tween.TRANS_BACK) -> Tween:
	var spr: Sprite2D = $Sprite2D
	var t: Tween = create_tween()
	t.set_ease(ease_type)
	t.set_trans(trans_type)
	t.tween_property(spr, "scale", target, duration)
	return t


## Virtual death handler — called by the Death state.
## Emits enemy_died, plays a shrink+fade tween, then frees the node.
## Override in subclasses for custom death behaviour (e.g. drop loot).
func die() -> void:
	enemy_died.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()


# =============================================================
# SIGNAL HANDLERS
# =============================================================

# Fires when a Hitbox overlaps our Hurtbox.
# HealthComponent._on_hurtbox_hurt already ran first (it connected
# in its own _ready()), so current_health is already reduced here.
func _on_hurt(_damage: int, knockback: Vector2) -> void:
	# Skip entirely if already dying (death tween may still be playing)
	if is_dead:
		return

	knockback_velocity = knockback
	flash()
	enemy_damaged.emit($HealthComponent.current_health, $HealthComponent.max_health)

	# Guard: if HP just hit 0, _on_died already queued "Death" —
	# don't overwrite it with "Hurt"
	if $HealthComponent.current_health > 0:
		$StateMachine.force_transition("Hurt")


# Fires when HealthComponent.died is emitted (HP reached 0).
func _on_died() -> void:
	# Guard against double-trigger (e.g. take_damage called while already dying)
	if is_dead:
		return
	is_dead = true
	$StateMachine.force_transition("Death")


# --- Zone tracking ---

func _on_detection_entered(body: Node2D) -> void:
	if body == player:
		player_in_detection_zone = true

func _on_detection_exited(body: Node2D) -> void:
	if body == player:
		player_in_detection_zone = false


# Fires when the player's hurtbox overlaps the enemy body (BodyArea).
# area_entered fires once on contact, not every frame, so we don't need
# any extra cooldown logic — the player's hurtbox i-frames (0.5 s) ensure
# the player can't be hit again until they separate and re-enter.
func _on_body_contact(area: Area2D) -> void:
	# Don't deal contact damage while dying — death tween may still be running
	if is_dead:
		return
	if not area.has_method("take_hit"):
		return

	# Push the player directly away from the enemy's centre. If the player is
	# somehow exactly on top of the enemy, fall back to the facing direction.
	var diff: Vector2 = area.global_position - global_position
	if diff.is_zero_approx():
		diff = Vector2(float(facing_direction), 0.0)

	area.take_hit(1, contact_knockback_direction(diff) * 160.0)


## Direction the player is pushed on body contact, given the offset from the
## enemy's centre to the player's hurtbox. Override for enemies that touch the
## player from above (Flyer), where "straight away" points into the floor.
func contact_knockback_direction(diff: Vector2) -> Vector2:
	return diff.normalized()
