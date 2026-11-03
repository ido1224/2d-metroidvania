# =============================================================
# SHOOTER
# =============================================================
# A ground enemy that fights at range. It keeps 90–170 px from
# the player (backing off if they get close, without walking off
# ledges or into walls) and fires slow, telegraphed orbs
# (projectile.tscn) when it has a clear line of sight.
#
#   Idle       — stands still until the player is detected
#   Alert      — "!" beat
#   Reposition — keeps its distance; decides when to shoot
#   Shoot      — orange glow windup, fire, short recovery
#   Hurt / Death
#
# Counterplay: close the distance (it's slow and has 2 HP), dodge
# or pierce-dash through the orbs, or hit an orb back at it.
# =============================================================

class_name Shooter
extends BaseEnemy

const PROJECTILE := preload("res://scenes/enemies/projectile/projectile.tscn")

## Minimum time between shots (seconds), counted from the last shot
@export var shot_cooldown: float = 1.3

## Orb speed (pixels/second). Slow on purpose — it should be dodgeable.
@export var projectile_speed: float = 130.0

## Where shots come from, relative to the body centre
@export var muzzle_offset: Vector2 = Vector2(0, -4)

var _since_shot: float = 999.0


func _physics_process(delta: float) -> void:
	super(delta)
	if hitstop_time > 0.0:
		return
	_since_shot += delta


# =============================================================
# HELPERS (called by shooter states)
# =============================================================

func shot_ready() -> bool:
	return _since_shot >= shot_cooldown


func muzzle_position() -> Vector2:
	return global_position + muzzle_offset


## Fire one orb from the muzzle toward [target] (a world position).
func fire_at(target: Vector2) -> void:
	var from: Vector2 = muzzle_position()
	var dir: Vector2 = (target - from).normalized()
	if dir.is_zero_approx():
		dir = Vector2(float(facing_direction), 0.0)
	var p: Projectile = PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = from + dir * 10.0
	p.launch(dir, projectile_speed)
	_since_shot = 0.0


## True if nothing on the World layer is between the muzzle and the player.
func has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var query := PhysicsRayQueryParameters2D.create(
			muzzle_position(), player.global_position, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func face_player() -> void:
	if not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		set_facing(1 if dx > 0.0 else -1)
