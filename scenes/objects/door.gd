# =============================================================
# DOOR / ROOM EXIT
# =============================================================
# Place this at the edges of rooms. When the player walks into
# it, it triggers a room transition.
#
# Each door has:
# - target_scene: which room to load
# - target_door_id: which door in the new room to spawn at
# - door_id: this door's unique name (so other doors can
#   reference it as a spawn point)
#
# The door also has a SpawnPoint marker — that's where the
# player appears when arriving FROM another room through
# this door.
# =============================================================

class_name Door
extends Area2D

## Unique ID for this door. Other doors reference this when
## they want to send the player here.
@export var door_id: String = ""

## Path to the scene file this door leads to.
@export_file("*.tscn") var target_scene: String = ""

## The door_id in the TARGET scene where the player should spawn.
@export var target_door_id: String = ""

## Where the player appears when arriving through this door.
@onready var spawn_point: Marker2D = $SpawnPoint


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	get_tree().create_timer(0.5).timeout.connect(_enable_monitoring)


func _enable_monitoring() -> void:
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	print("Door touched by: ", body.name)

	# Ignore anything that isn't the player
	if not body.is_in_group("player"):
		print("Not a player, ignoring")
		return

	print("target_scene: ", target_scene)
	print("target_door_id: ", target_door_id)

	if target_scene != "" and target_door_id != "":
		print("Starting transition!")
		GameManager.transition_to_room(target_scene, target_door_id)
	else:
		print("ERROR: target_scene or target_door_id is empty!")
