# =============================================================
# FLYER — CHASE STATE
# =============================================================
# Flies to a "perch" point above and to the side of the player,
# then dives from there.
#
# A perch only counts if the flyer fits there AND has a clear
# straight line from it to the player (so the dive can land).
# Candidates, in order: same side as now, other side, straight
# above, then the same three at half height (for low ceilings).
# The last perch that worked is tried first, so it doesn't hop
# between options every frame.
#
# It only dives once settled near a valid perch, at least
# MIN_CHASE_TIME after entering Chase, with a clear line to the
# player right now. If no perch is valid (player under a platform
# etc.) it hovers overhead and waits for an opening.
#
# Transitions:
#   -> "Dive"   : settled near a valid perch, clear line to player
#   -> "Return" : player left DetectionZone, or leash exceeded
# =============================================================

extends EnemyState

## Perch offset from the player (pixels): sideways and up
const PERCH_X: float = 56.0
const PERCH_Y: float = 52.0

## How close to the perch counts as "settled" (pixels)
const PERCH_TOLERANCE: float = 20.0

## Minimum time between entering Chase and diving — also acts as
## the gap between consecutive dives (Dive always exits via Chase)
const MIN_CHASE_TIME: float = 0.7

## Speed multiplier over run_speed while chasing
const CHASE_SPEED_MULT: float = 1.5

var _timer: float = 0.0
var _last_perch: int = 0


func enter() -> void:
	_timer = 0.0


func physics_update(delta: float) -> String:
	if not is_instance_valid(enemy.player):
		return "Return"
	if not enemy.player_in_detection_zone or enemy.is_leashed():
		return "Return"

	_timer += delta

	var player_pos: Vector2 = enemy.player.global_position
	var perch_index: int = _find_perch(player_pos)
	var perch: Vector2
	if perch_index >= 0:
		perch = player_pos + _perch_offsets(player_pos)[perch_index]
	else:
		# Nowhere to dive from — hold overhead, out of the way, and wait
		perch = player_pos + Vector2(0.0, -PERCH_Y)
	perch.y += enemy.bob_offset()

	enemy.steer_toward(perch, enemy.run_speed * CHASE_SPEED_MULT, 320.0, delta)
	enemy.move_and_slide()
	enemy.face_player()

	if (perch_index >= 0
			and _timer >= MIN_CHASE_TIME
			and enemy.global_position.distance_to(perch) <= PERCH_TOLERANCE
			and enemy.has_clear_path(enemy.global_position, player_pos)):
		return "Dive"
	return ""


# Perch candidates relative to the player, in preference order.
func _perch_offsets(player_pos: Vector2) -> Array[Vector2]:
	var side: float = 1.0 if enemy.global_position.x >= player_pos.x else -1.0
	return [
		Vector2(side * PERCH_X, -PERCH_Y),
		Vector2(-side * PERCH_X, -PERCH_Y),
		Vector2(0.0, -PERCH_Y),
		Vector2(side * PERCH_X, -PERCH_Y * 0.5),
		Vector2(-side * PERCH_X, -PERCH_Y * 0.5),
		Vector2(0.0, -PERCH_Y * 0.5),
	]


# Index of the first usable perch (last-used one first), or -1 if none.
func _find_perch(player_pos: Vector2) -> int:
	var offsets: Array[Vector2] = _perch_offsets(player_pos)
	var order: Array[int] = [_last_perch]
	for i in offsets.size():
		if i != _last_perch:
			order.append(i)
	for i in order:
		var p: Vector2 = player_pos + offsets[i]
		if enemy.is_open_point(p) and enemy.has_clear_path(p, player_pos):
			_last_perch = i
			return i
	return -1
