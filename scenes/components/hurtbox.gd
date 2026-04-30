# =============================================================
# HURTBOX (Damage Receiver)
# =============================================================
# Attach this to anything that can take damage: the player,
# enemies, breakable walls, etc.
#
# How it works:
# - This is an Area2D that Hitboxes detect
# - When a Hitbox overlaps us, it calls our take_hit() function
# - We emit a signal so our parent (or a HealthComponent) can
#   respond to the damage
# - We handle invincibility frames (i-frames) so you can't
#   get hit every single frame
#
# Physics layers:
# - Player's hurtbox: Layer 6 (PlayerHurtbox), Mask 0 (scans nothing)
# - Enemy's hurtbox: Layer 7 (EnemyHurtbox), Mask 0 (scans nothing)
#
# Hurtboxes don't scan for anything — they just exist on a
# layer so Hitboxes can find them.
# =============================================================

class_name Hurtbox
extends Area2D

## Emitted when this hurtbox takes a hit.
## Other nodes (like HealthComponent) connect to this.
signal hurt(damage: int, knockback: Vector2)

## Emitted the frame invincibility expires.
signal invincibility_ended

## How long after getting hit before we can be hit again (seconds).
## 20 frames at 60 fps = 20 / 60 ≈ 0.333 s.
@export var invincibility_duration: float = 20.0 / 60.0

## Are we currently invincible (recently got hit)?
var is_invincible: bool = false

## Timer for i-frames
var invincibility_timer: Timer


func _ready() -> void:
	# Hurtboxes don't scan for anything — they just sit on
	# a layer and wait for Hitboxes to find them
	monitoring = false
	monitorable = true

	# Create the i-frame timer
	invincibility_timer = Timer.new()
	invincibility_timer.wait_time = invincibility_duration
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)


## Called by a Hitbox when it overlaps us.
## Returns true if the hit went through, false if blocked by i-frames.
## Callers should only apply hitstop / effects when this returns true.
func take_hit(damage: int, knockback: Vector2) -> bool:
	# Ignore hits during i-frames
	if is_invincible:
		return false

	# Start i-frames
	is_invincible = true
	invincibility_timer.start()

	# Emit the signal so our parent / health component can respond
	hurt.emit(damage, knockback)
	return true


## I-frames over — can be hit again
func _on_invincibility_timeout() -> void:
	is_invincible = false
	invincibility_ended.emit()
