# =============================================================
# PLAYER CAMERA
# =============================================================
# Attached as a child of the Player node so it follows
# automatically. This script adds:
#
# 1. LOOK-AHEAD — shifts the camera in the direction the player
#    is facing/moving so you can see more of what's coming.
#
# 2. ROOM CLAMPING — keeps the camera inside the room boundaries
#    so you never see empty space outside the level. Each room
#    sets these limits when the player enters it.
#
# 3. SCREEN SHAKE — call shake() from anywhere to add juice to
#    hits, explosions, boss intros, etc.
#
# We DON'T use Godot's built-in camera smoothing because it
# causes the player to drift off-center when moving fast.
# Instead we handle the offset manually for more control.
# =============================================================

extends Camera2D

# --- Look-ahead ---

## How far ahead the camera shifts (in pixels) toward the
## direction the player is facing
@export var look_ahead_distance: float = 30.0

## How fast the camera moves to the look-ahead position.
## Higher = snappier. Lower = more drift.
@export var look_ahead_speed: float = 5.0

# --- Room Clamping ---

## These define the edges of the current room in world pixels.
## The camera won't scroll past these boundaries.
## Defaults are very large so the camera works even before
## a room sets its real bounds.
var room_left: float = -10000.0
var room_right: float = 10000.0
var room_top: float = -10000.0
var room_bottom: float = 10000.0

# --- Screen Shake ---

## How strong the current shake is (decreases over time)
var shake_intensity: float = 0.0

## How fast the shake fades out
var shake_decay: float = 5.0

# --- Internal ---

## The target offset we're smoothly moving toward
var target_offset: Vector2 = Vector2.ZERO

## Reference to the player (our parent node)
@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	# Disable Godot's built-in smoothing — we handle it ourselves
	position_smoothing_enabled = false

	# Make sure camera is active
	make_current()


func _process(delta: float) -> void:
	update_look_ahead(delta)
	update_screen_shake(delta)
	clamp_to_room()


# =============================================================
# LOOK-AHEAD
# =============================================================

func update_look_ahead(delta: float) -> void:
	# Calculate where we want the camera offset to be.
	# player.facing_direction is -1 (left) or 1 (right).
	var target_x: float = player.facing_direction * look_ahead_distance

	# Smoothly move the offset toward the target.
	# lerp = linear interpolation. It moves a fraction of the
	# remaining distance each frame, creating smooth easing.
	target_offset.x = lerp(target_offset.x, target_x, look_ahead_speed * delta)

	# Apply the offset to our position.
	# Since we're a child of Player, position (0,0) = player center.
	# We only need to set the offset.
	offset = target_offset


# =============================================================
# SCREEN SHAKE
# =============================================================

## Call this from anywhere to trigger a screen shake.
## Example: player.camera.shake(8.0) for a medium hit,
##          player.camera.shake(15.0) for a big impact.
func shake(intensity: float) -> void:
	shake_intensity = intensity


func update_screen_shake(delta: float) -> void:
	if shake_intensity > 0.1:
		# Add a random offset to the camera position.
		# randf_range gives a random float between -1 and 1,
		# multiplied by intensity for the shake amount.
		offset += Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

		# Fade the shake out over time
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		# Shake is done — zero it out to prevent tiny jitter
		shake_intensity = 0.0


# =============================================================
# ROOM CLAMPING
# =============================================================

func clamp_to_room() -> void:
	# Get the visible area size (half the viewport because the
	# camera is centered on the player).
	# Since zoom affects how much we see, we divide by zoom
	# to get the actual visible area in world pixels.
	var half_width: float = (get_viewport_rect().size.x / zoom.x) / 2.0
	var half_height: float = (get_viewport_rect().size.y / zoom.y) / 2.0

	# Clamp so the camera edges don't go past room boundaries.
	# If the room is smaller than the viewport, center the camera
	# in that axis instead.
	var room_width: float = room_right - room_left
	var room_height: float = room_bottom - room_top

	if room_width <= half_width * 2.0:
		# Room is smaller than viewport — center horizontally
		offset.x = (room_left + room_width / 2.0) - global_position.x
	else:
		# Clamp camera edges to room edges
		var min_x: float = room_left + half_width - global_position.x
		var max_x: float = room_right - half_width - global_position.x
		offset.x = clampf(offset.x, min_x, max_x)

	if room_height <= half_height * 2.0:
		# Room is smaller than viewport — center vertically
		offset.y = (room_top + room_height / 2.0) - global_position.y
	else:
		var min_y: float = room_top + half_height - global_position.y
		var max_y: float = room_bottom - half_height - global_position.y
		offset.y = clampf(offset.y, min_y, max_y)


## Called by the room/transition system to update boundaries
## when the player enters a new room.
func set_room_bounds(left: float, right: float, top: float, bottom: float) -> void:
	room_left = left
	room_right = right
	room_top = top
	room_bottom = bottom
