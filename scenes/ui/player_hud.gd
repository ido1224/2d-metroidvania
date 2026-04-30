# =============================================================
# PLAYER HUD
# =============================================================
# Displays the player's health as a row of discrete heart pips.
# Filled = alive HP, empty = lost HP.
#
# Usage:
#   1. Instantiate player_hud.tscn and add as a child of Player
#   2. Call initialize(health.max_health) once after adding
#   3. Connect HealthComponent.health_changed to update_health
#
# Hearts are ColorRect nodes created at runtime inside
# HBoxContainer — no texture assets needed.
# =============================================================

class_name PlayerHUD
extends CanvasLayer

## Size of each heart pip in pixels
@export var heart_size: Vector2 = Vector2(20, 20)

## Color of a filled (alive) heart
@export var filled_color: Color = Color(0.9, 0.1, 0.2)

## Color of an empty (lost) heart
@export var empty_color: Color = Color(0.3, 0.3, 0.3)

## All heart ColorRect references, ordered left to right
var heart_containers: Array[ColorRect] = []

## Tracks last known HP to detect damage vs. heal direction
var _previous_hp: int = 0

@onready var _hbox: HBoxContainer = $MarginContainer/HBoxContainer


# --- Setup ---

## Call once to build the initial set of heart pips.
## Safe to call again if max_health ever increases.
func initialize(max_health: int) -> void:
	# Remove any existing hearts (safe to call on first init too)
	for child in _hbox.get_children():
		child.queue_free()
	heart_containers.clear()

	# Build one ColorRect per HP point
	for i in max_health:
		var heart := ColorRect.new()
		heart.custom_minimum_size = heart_size
		heart.color = filled_color
		_hbox.add_child(heart)
		heart_containers.append(heart)

	# Assume full health at initialization
	_previous_hp = max_health


# --- Signal handler (connect to HealthComponent.health_changed) ---

func update_health(current_hp: int, max_hp: int) -> void:
	# If hearts were added mid-game, rebuild before updating colors
	if max_hp > heart_containers.size():
		initialize(max_hp)

	# Update all heart colors
	for i in heart_containers.size():
		heart_containers[i].color = filled_color if i < current_hp else empty_color

	# Punch animation — scale pop on the heart that just changed
	if current_hp < _previous_hp:
		# Took damage: punch the first heart that just went empty
		_punch_heart(current_hp)
	elif current_hp > _previous_hp:
		# Healed: punch the last heart that just became filled
		_punch_heart(current_hp - 1)

	_previous_hp = current_hp


# --- Internal ---

func _punch_heart(index: int) -> void:
	if index < 0 or index >= heart_containers.size():
		return

	var heart := heart_containers[index]
	if not is_instance_valid(heart):
		return

	# Use a tween owned by the heart itself so it dies with the node
	heart.scale = Vector2(1.3, 1.3)
	var tween := heart.create_tween()
	tween.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
