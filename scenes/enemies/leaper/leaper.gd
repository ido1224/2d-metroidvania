# =============================================================
# LEAPER
# =============================================================
# A ground enemy that attacks by jumping at the player in an arc.
#
#   Idle / Patrol — the Ground Walker's (generic) states
#   Alert         — "!" beat
#   Stalk         — creeps toward the player, stops at ledges/walls;
#                   starts a leap when in range and the jump is safe
#   Leap          — CROUCH (telegraph) → AIR (body is the hitbox)
#                   → LAND (dazed: the punish window)
#   Hurt / Death
#
# The jump is real ballistics: compute_leap() solves for the
# launch velocity that lands it where the player stood at the end
# of the crouch, using the project's gravity. trajectory_clear()
# traces that arc with the Leaper's own collision box first, so
# it never jumps into a platform, a wall, or off into a pit.
# =============================================================

class_name Leaper
extends BaseEnemy

## Normal height of the jump's peak above its start (pixels)
@export var leap_height: float = 48.0

## Highest it will ever jump (pixels) — players above this are out of reach
@export var max_leap_height: float = 96.0

## Horizontal speed cap while airborne (pixels/second)
@export var max_leap_hspeed: float = 240.0

## Rest after landing before it can leap again (seconds, counted from landing)
@export var leap_cooldown: float = 1.2

var _since_land: float = 999.0


func _physics_process(delta: float) -> void:
	super(delta)
	if hitstop_time > 0.0:
		return
	_since_land += delta


# =============================================================
# HELPERS (called by leaper states)
# =============================================================

func leap_ready() -> bool:
	return _since_land >= leap_cooldown


func mark_landed() -> void:
	_since_land = 0.0


## Where its centre should end up to land on the player's floor
## (player centre is 12 px above their feet, the Leaper's is 8).
func leap_target() -> Vector2:
	if not is_instance_valid(player):
		return global_position
	return player.global_position + Vector2(0, 4)


## The best safe leap at the player right now, or Vector2.ZERO if there is
## none. Tries the normal arc first, then steeper ones (e.g. to clear a
## block it's standing right next to), up to max_leap_height.
func plan_leap() -> Vector2:
	var target: Vector2 = leap_target()
	var h: float = leap_height
	while h <= max_leap_height + 0.1:
		var v: Vector2 = compute_leap(target, h)
		if trajectory_clear(v):
			return v
		h += 24.0
	return Vector2.ZERO


## Launch velocity that lands its centre on [target] with a peak [peak]
## pixels above the start (raised automatically when the target is higher),
## or Vector2.ZERO if that would need more than max_leap_height.
func compute_leap(target: Vector2, peak: float = -1.0) -> Vector2:
	var g: float = _gravity
	var dx: float = target.x - global_position.x
	var dy: float = target.y - global_position.y   # + = target is lower
	var h: float = leap_height if peak < 0.0 else peak
	if -dy > h - 12.0:
		h = -dy + 24.0
	if h > max_leap_height:
		return Vector2.ZERO
	var vy: float = -sqrt(2.0 * g * h)
	var fall: float = h + dy
	if fall <= 0.0:
		return Vector2.ZERO
	var t: float = -vy / g + sqrt(2.0 * fall / g)
	var vx: float = clampf(dx / t, -max_leap_hspeed, max_leap_hspeed)
	return Vector2(vx, vy)


## Trace the arc launched with [v] using the Leaper's own collision box.
## False if it would hit anything before coming down, or if there's no
## floor where it lands.
func trajectory_clear(v: Vector2) -> bool:
	if v == Vector2.ZERO:
		return false
	var g: float = _gravity
	# Airtime until it falls back to the target height (same maths as compute_leap)
	var target: Vector2 = leap_target()
	var dy: float = target.y - global_position.y
	var h: float = (v.y * v.y) / (2.0 * g)
	var t_total: float = -v.y / g + sqrt(2.0 * maxf(h + dy, 0.0) / g)

	const STEPS := 12
	var prev: Vector2 = global_position + Vector2(0, -1)   # lift off the floor contact
	for i in range(1, STEPS):
		var t: float = t_total * float(i) / float(STEPS)
		var p: Vector2 = global_position + Vector2(v.x * t, v.y * t + 0.5 * g * t * t)
		if test_move(Transform2D(0.0, prev), p - prev):
			return false
		prev = p

	# Floor under the landing spot (within 24 px below where its centre ends up)
	var land: Vector2 = global_position + Vector2(v.x * t_total, dy)
	var q := PhysicsRayQueryParameters2D.create(land, land + Vector2(0, 24), 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func face_player() -> void:
	if not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		set_facing(1 if dx > 0.0 else -1)
