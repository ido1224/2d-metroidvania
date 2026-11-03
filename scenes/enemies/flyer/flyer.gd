# =============================================================
# FLYER
# =============================================================
# An airborne enemy. Ignores gravity (CharacterBody2D in
# MOTION_MODE_FLOATING) and moves freely on both axes.
#
#   Hover  — drifts in a slow figure around its home point
#   Alert  — spotted the player: stops, faces them, "!" squash
#   Chase  — flies to a spot above and to the side of the player
#   Dive   — telegraphed straight-line dive at where the player
#            was when the windup ended; bonks on walls/floor
#   Return — player lost or leashed too far: flies back home
#   Hurt / Death
#
# Combat read: the windup (pull back + red tint) is the dodge
# cue, the recovery after the dive is the punish window. From
# above, the player can also pogo it.
# =============================================================

class_name Flyer
extends BaseEnemy

## Vertical bob while hovering (pixels)
@export var bob_amplitude: float = 4.0

## Bob speed (radians/second fed into sin)
@export var bob_speed: float = 3.0

## Furthest it will chase from its home point before giving up (pixels)
@export var leash_distance: float = 260.0

## Where it was placed in the room; Hover and Return orbit this point.
## Captured on the first physics frame, not in _ready(): a Flyer spawned
## from code is added to the tree BEFORE its position is set, so reading
## it in _ready() gave (0, 0) and it flew off to the room's corner.
## Setting it yourself before that frame also works.
var home_position: Vector2:
	set(value):
		home_position = value
		_home_set = true

## Running clock for the hover bob / drift (seconds)
var hover_time: float = 0.0

var _home_set: bool = false


func _ready() -> void:
	super()
	# Also set in the .tscn; repeated here so a hand-built Flyer can't
	# accidentally end up in grounded mode (it would slide along floors).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if not _home_set:
		home_position = global_position
	super(delta)
	if hitstop_time > 0.0:
		return
	hover_time += delta


# =============================================================
# HELPERS (called by flyer states)
# =============================================================

## Vertical bob offset for the current moment
func bob_offset() -> float:
	return sin(hover_time * bob_speed) * bob_amplitude


## Accelerate velocity toward [target], steering around platforms and walls.
## Slows down when close, so the flyer settles on a point instead of
## overshooting and jittering.
func steer_toward(target: Vector2, speed: float, accel: float, delta: float) -> void:
	var to_target: Vector2 = target - global_position
	var dist: float = to_target.length()
	var desired := Vector2.ZERO
	if dist > 1.0:
		var dir: Vector2 = _clear_direction(to_target / dist, minf(avoid_lookahead, dist))
		desired = dir * minf(speed, dist * 4.0)
	velocity = velocity.move_toward(desired, accel * delta)


# =============================================================
# OBSTACLE AVOIDANCE
# =============================================================
# All checks use the flyer's real collision box against the World
# layer (its collision_mask), not a thin ray, so it never picks a
# gap it can't actually fit through.

## How far ahead (pixels) it looks for platforms when steering
@export var avoid_lookahead: float = 28.0

# Turn angles tried in order (radians, mirrored to both sides): straight,
# ~30°, ~57°, ~86°, ~120°. Beyond that it is boxed in and just pushes on.
const _AVOID_TURNS: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.1]

# Which way it last turned to get round something (+1 / -1). Trying the same
# side first stops it flip-flopping in front of a platform edge.
var _avoid_side: float = 1.0


func _clear_direction(wanted: Vector2, lookahead: float) -> Vector2:
	for turn in _AVOID_TURNS:
		for side in ([_avoid_side, -_avoid_side] if turn > 0.0 else [1.0]):
			var dir: Vector2 = wanted.rotated(turn * side)
			if not test_move(global_transform, dir * lookahead):
				if turn > 0.0:
					_avoid_side = side
				return dir
	return wanted


## True if the flyer's body could travel in a straight line from [from]
## to [to] without touching a platform or wall.
func has_clear_path(from: Vector2, to: Vector2) -> bool:
	return not test_move(Transform2D(0.0, from), to - from)


## True if the flyer's body would fit at [point] without overlapping
## any platform or wall.
func is_open_point(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Turn to face the player (no-op if the player is gone or right above)
func face_player() -> void:
	if not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		set_facing(1 if dx > 0.0 else -1)


## Face the way it's moving horizontally
func face_velocity() -> void:
	if absf(velocity.x) > 4.0:
		set_facing(1 if velocity.x > 0.0 else -1)


## Contact from above would push the player into the floor; push them
## straight sideways, away from the flyer, instead. Kept flat on purpose:
## player.gd only adds its upward hop when the knockback has no upward part.
func contact_knockback_direction(diff: Vector2) -> Vector2:
	var side: float = signf(diff.x) if absf(diff.x) > 2.0 else float(facing_direction)
	return Vector2(side, 0.0)


## True when it has strayed further than leash_distance from home
func is_leashed() -> bool:
	return global_position.distance_to(home_position) > leash_distance
