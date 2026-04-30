# =============================================================
# HITBOX (Damage Dealer)
# =============================================================
# Attach this to anything that deals damage: player attacks,
# enemy attacks, projectiles, traps, etc.
#
# How it works:
# - This is an Area2D that detects overlap with Hurtboxes
# - When it touches a Hurtbox, it tells the Hurtbox to take damage
# - It only activates when you call activate() and deactivates
#   after a short time (or when you call deactivate())
#
# Physics layers:
# - Player's hitbox: Layer 4 (PlayerHitbox), Mask 7 (EnemyHurtbox)
# - Enemy's hitbox: Layer 5 (EnemyHitbox), Mask 6 (PlayerHurtbox)
#
# This way player attacks only hit enemies, and enemy attacks
# only hit the player. No friendly fire.
# =============================================================

class_name Hitbox
extends Area2D

## How much damage this hitbox deals
@export var damage: int = 1

## Knockback force applied to whatever gets hit.
## Direction is calculated automatically (away from the hitbox).
@export var knockback_force: float = 200.0

## Is this hitbox currently able to deal damage?
var is_active: bool = false

# Targets already hit during the current active window.
# Cleared on activate() so each new swing can hit the same target again,
# but a single swing cannot hit the same hurtbox twice.
var _hit_targets: Array = []

# When non-zero, overrides the position-based knockback direction.
# Set via activate(explicit_dir) for melee attacks where the hitbox
# may be closer to the attacker than to the target (causing the
# position-math to point the wrong way).
var _knockback_dir_override: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Start disabled — hitboxes only activate during attacks
	monitoring = false

	# Connect the signal for when we overlap a hurtbox
	area_entered.connect(_on_area_entered)


## Turn the hitbox on. Call this when an attack starts.
## Pass explicit_dir to lock the knockback direction regardless of
## where the hitbox and hurtbox happen to be in world space — useful
## for melee attacks where origins may be very close or overlapping.
func activate(explicit_dir: Vector2 = Vector2.ZERO) -> void:
	_hit_targets.clear()
	is_active = true
	monitoring = true
	_knockback_dir_override = explicit_dir


## Turn the hitbox off. Call this when an attack ends.
func deactivate() -> void:
	is_active = false
	monitoring = false
	_knockback_dir_override = Vector2.ZERO


## When we overlap another Area2D, check if it can receive damage
func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return

	# One hit per target per activation window — prevents the same swing
	# from landing twice if the area_entered signal re-fires (e.g. monitoring
	# toggled while already overlapping).
	if area in _hit_targets:
		return

	# Use has_method so this works regardless of whether the hurtbox
	# was instantiated from components/ or the legacy componets/ folder
	if area.has_method("take_hit"):
		_hit_targets.append(area)

		var knockback_direction: Vector2
		if _knockback_dir_override != Vector2.ZERO:
			# Caller supplied an explicit direction — trust it over position math.
			# Position math fails when hitbox and hurtbox origins are very close.
			knockback_direction = _knockback_dir_override.normalized()
		else:
			# Default: direction from hitbox centre outward toward the target
			knockback_direction = (area.global_position - global_position).normalized()

		var hit_landed: bool = area.take_hit(damage, knockback_direction * knockback_force)

		# Only freeze both parties when the hit actually went through.
		# If take_hit returned false, the target was in i-frames — applying
		# hitstop would make a blocked hit feel identical to a real one.
		if hit_landed:
			var target = area.get_parent()
			if "hitstop_time" in target:
				target.hitstop_time = target.hitstop_duration
