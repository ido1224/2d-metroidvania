extends Node

signal health_changed(current_health: int, max_health: int)
signal died

@export var max_health: int = 5

var current_health: int
var hurtbox: Area2D


func _ready() -> void:
	current_health = max_health

	# Auto-find the hurtbox sibling node
	var parent = get_parent()
	for child in parent.get_children():
		if child.has_method("take_hit"):
			hurtbox = child
			break

	if hurtbox:
		hurtbox.hurt.connect(_on_hurtbox_hurt)


func _on_hurtbox_hurt(damage: int, _knockback: Vector2) -> void:
	take_damage(damage)


func take_damage(amount: int) -> void:
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	
