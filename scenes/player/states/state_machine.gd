# =============================================================
# STATE MACHINE
# =============================================================
# This node manages all states. It:
# 1. Keeps track of which state is currently active
# 2. Calls the active state's update/physics_update every frame
# 3. Handles transitions when a state says "switch to X"
# =============================================================

class_name StateMachine
extends Node

@export var initial_state_name: String = "Idle"

var player: CharacterBody2D
var current_state: State
var states: Dictionary = {}
var active: bool = false


func _ready() -> void:
	# Find the player — our parent node
	player = get_parent() as CharacterBody2D
	if player == null:
		push_warning("StateMachine: Parent is not a CharacterBody2D!")
		return

	# Collect all child State nodes
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.player = player

	# Start in the initial state
	if states.has(initial_state_name):
		current_state = states[initial_state_name]
		current_state.enter()
		active = true
	elif states.size() > 0:
		current_state = states.values()[0]
		current_state.enter()
		active = true


func _process(delta: float) -> void:
	if active and current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if not active or current_state == null:
		return
	# Safety: make sure our player still exists (could be freed
	# during a scene transition)
	if not is_instance_valid(player):
		active = false
		return

	# Hitstop — player._physics_process ticks the timer; we just skip state logic.
	# Still poll dash input so a press during the freeze gets buffered and fires
	# the moment hitstop ends.
	if player.hitstop_time > 0.0:
		if Input.is_action_just_pressed("dash") and player.has_dash:
			player._dash_buffer = player.dash_buffer_duration
		return

	var next_state_name: String = current_state.physics_update(delta)
	if next_state_name != "":
		transition_to(next_state_name)


func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_warning("State '" + state_name + "' not found in StateMachine!")
		return
	if current_state == states[state_name]:
		return

	current_state.exit()
	current_state = states[state_name]
	current_state.enter()
