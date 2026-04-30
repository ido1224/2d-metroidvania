# =============================================================
# BASE ROOM
# =============================================================
# Attach this script to the root node of every room scene.
# It reads the RoomBoundsMin and RoomBoundsMax markers to
# define the camera boundaries for this room.
#
# When the room loads, it finds the player and tells the
# player's camera where the room edges are.
#
# Every room you create should follow this structure:
#
# Room (Node2D) — base_room.gd
# ├── TileMapLayer        — terrain and collision
# ├── RoomBoundsMin       — Marker2D at top-left corner
# ├── RoomBoundsMax       — Marker2D at bottom-right corner
# ├── Enemies (Node2D)    — container for enemy instances
# ├── Items (Node2D)      — container for pickups
# └── Doors (Node2D)      — container for door/transition areas
# =============================================================

class_name BaseRoom
extends Node2D

## Unique identifier for this room. Used by the save system
## to track visited rooms, and by the map to know which room
## the player is in. Set this in the Inspector for each room.
@export var room_id: String = ""

# References to the boundary markers.
# These are Marker2D nodes you place in the editor to define
# where the camera should stop scrolling.
@onready var bounds_min: Marker2D = $RoomBoundsMin
@onready var bounds_max: Marker2D = $RoomBoundsMax


func _ready() -> void:
	# Find the player in the scene tree.
	# We wait one frame to make sure everything is initialized.
	call_deferred("_setup_room")


func _setup_room() -> void:
	# Find the player node. It should be a direct child of this
	# room or instanced in the scene tree.
	var player = _find_player()
	if player == null:
		push_warning("BaseRoom: Could not find Player node!")
		return

	# Tell the player's camera about this room's boundaries.
	if player.camera:
		player.camera.set_room_bounds(
			bounds_min.global_position.x,
			bounds_max.global_position.x,
			bounds_min.global_position.y,
			bounds_max.global_position.y
		)


## Search the scene tree for the player node.
## First checks the "player" group, then falls back to searching
## children for a CharacterBody2D (in case group wasn't added yet).
func _find_player() -> CharacterBody2D:
	# Try group first (most reliable)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]

	# Fallback: search our direct children
	for child in get_children():
		if child is CharacterBody2D:
			return child

	return null


## Call this to get the room bounds as a Rect2.
## Useful for other systems that need to know the room size.
func get_room_bounds() -> Rect2:
	var top_left: Vector2 = bounds_min.global_position
	var size: Vector2 = bounds_max.global_position - top_left
	return Rect2(top_left, size)
