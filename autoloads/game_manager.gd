# =============================================================
# GAME MANAGER (Autoload)
# =============================================================
# Handles room transitions with fade effect.
# Register as Autoload: Project → Project Settings → Globals → Autoload
# Path: res://autoloads/game_manager.gd
# Name: GameManager
# =============================================================

extends Node

@export var fade_duration: float = 0.3

var is_transitioning: bool = false
var fade_rect: ColorRect
var fade_tween: Tween
var target_door_id: String = ""


func _ready() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade_rect)


func transition_to_room(target_scene: String, door_id: String) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	target_door_id = door_id

	# Step 1: Fade to black
	await fade_to_black()

	# Step 2: Load the new room
	get_tree().change_scene_to_file(target_scene)

	# Step 3: Wait for the new scene to fully initialize.
	# Two frames ensures all _ready() functions have run
	# and all @onready variables are set.
	await get_tree().process_frame
	await get_tree().process_frame

	# Step 4: Place the player at the target door
	place_player_at_door()

	# Step 5: Fade back in
	await fade_to_clear()

	is_transitioning = false


func fade_to_black() -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	await fade_tween.finished


func fade_to_clear() -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	await fade_tween.finished


func place_player_at_door() -> void:
	# Find the player — might not exist in the new scene
	var players = get_tree().get_nodes_in_group("player")
	var player: CharacterBody2D

	if players.is_empty():
		# No player in this room — spawn one
		var player_scene = preload("res://scenes/player/player.tscn")
		player = player_scene.instantiate()
		get_tree().current_scene.add_child(player)
	else:
		player = players[0]

	# Find all Door nodes in the scene
	var doors: Array = []
	find_doors_recursive(get_tree().current_scene, doors)

	# Find the door matching our target ID
	for door in doors:
		if door.door_id == target_door_id:
			player.global_position = door.spawn_point.global_position
			player.velocity = Vector2.ZERO
			return

	push_warning("GameManager: Could not find door with id '" + target_door_id + "'")


func find_doors_recursive(node: Node, result: Array) -> void:
	if node is Door:
		result.append(node)
	for child in node.get_children():
		find_doors_recursive(child, result)
