# =============================================================
# BASE STATE
# =============================================================
# This is the template for ALL states. Every state (Idle, Run,
# Jump, Fall, etc.) extends this script.
#
# It does nothing on its own — child states override these
# functions to define their behavior.
#
# "class_name State" registers this as a custom type in Godot,
# so other scripts can reference it by name.
# =============================================================

class_name State
extends Node

# Reference to the player node. Set by the StateMachine when
# the scene is ready. Every state can access the player's
# velocity, position, sprite, etc. through this.
var player: CharacterBody2D


# Called when this state becomes active.
# Use this to set up animations, reset timers, etc.
func enter() -> void:
	pass


# Called when this state is about to be replaced by another.
# Use this to clean up anything the state started.
func exit() -> void:
	pass


# Called every frame (tied to monitor refresh rate).
# Use for visual updates, non-physics logic.
func update(_delta: float) -> void:
	pass


# Called every physics frame (60 times/sec).
# Use for movement, gravity, collision checks.
# Returns a String with the name of the next state to
# transition to, or an empty string to stay in this state.
func physics_update(_delta: float) -> String:
	return ""
