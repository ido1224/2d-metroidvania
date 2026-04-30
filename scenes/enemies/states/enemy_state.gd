# =============================================================
# BASE ENEMY STATE
# =============================================================
# Template for all enemy states. Every concrete state
# (Idle, Patrol, Chase, Attack, Hurt, Death) extends this.
#
# The enemy reference is resolved in _ready() by walking up two
# levels: State → StateMachine → Enemy (CharacterBody2D).
# =============================================================

class_name EnemyState
extends Node

## Reference to the owning enemy. Set automatically in _ready().
var enemy: CharacterBody2D


func _ready() -> void:
	# State → StateMachine → Enemy
	enemy = get_parent().get_parent() as CharacterBody2D


# Called when this state becomes active.
func enter() -> void:
	pass


# Called when leaving this state.
func exit() -> void:
	pass


# Called every frame (non-physics). For visual updates.
func update(_delta: float) -> void:
	pass


# Called every physics frame.
# Return "" to stay, or a state name string to transition.
func physics_update(_delta: float) -> String:
	return ""
