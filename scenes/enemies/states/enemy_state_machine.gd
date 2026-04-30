# =============================================================
# ENEMY STATE MACHINE
# =============================================================
# Mirrors the player's StateMachine design:
#   - Child EnemyState nodes are discovered at _ready()
#   - physics_update() return value drives transitions
#   - force_transition() lets external signals (hurt, death)
#     override the current state immediately
# =============================================================

class_name EnemyStateMachine
extends Node

@export var initial_state_name: String = "Idle"

var enemy: CharacterBody2D
var current_state: EnemyState
var states: Dictionary = {}
var active: bool = false


func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	if enemy == null:
		push_warning("EnemyStateMachine: parent is not a CharacterBody2D!")
		return

	# Collect all direct EnemyState children
	for child in get_children():
		if child is EnemyState:
			states[child.name] = child

	# Enter the initial state
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
	if not is_instance_valid(enemy):
		active = false
		return

	# Hitstop — let base_enemy tick the timer; we just skip state logic
	if enemy.hitstop_time > 0.0:
		return

	var next_state_name: String = current_state.physics_update(delta)
	if next_state_name != "":
		transition_to(next_state_name)


# Normal transition — ignores same-state re-entry.
func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_warning("EnemyStateMachine: state '" + state_name + "' not found!")
		return
	if current_state == states[state_name]:
		return

	current_state.exit()
	current_state = states[state_name]
	current_state.enter()


# Forced transition — used by external signals (hurt, death).
# Always exits the current state and enters the target, even if
# it's the same state (e.g. taking damage while already Hurt).
func force_transition(target_state_name: String) -> void:
	if not states.has(target_state_name):
		push_warning("EnemyStateMachine: force_transition — state '" + target_state_name + "' not found!")
		return

	if current_state:
		current_state.exit()

	current_state = states[target_state_name]
	current_state.enter()
	active = true
