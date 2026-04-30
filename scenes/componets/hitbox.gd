extends Area2D

## Emitted when this hitbox successfully lands a hit on a hurtbox.
## No arguments — listeners just need to know "something was hit".
signal hit_landed

@export var damage: int = 1
@export var knockback_force: float = 200.0

var is_active: bool = false

# Tracks which hurtboxes have already been hit this activation.
# Cleared on activate() so each swing can only damage each target once.
var _hit_targets: Array = []


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_targets.clear()
	is_active = true
	monitoring = true


func deactivate() -> void:
	is_active = false
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	if area in _hit_targets:
		return
	if area.has_method("take_hit"):
		_hit_targets.append(area)
		var knockback_direction: Vector2 = (area.global_position - global_position).normalized()
		var hit_landed_result: bool = area.take_hit(damage, knockback_direction * knockback_force)
		hit_landed.emit()

		if hit_landed_result:
			# Stun only the target (enemy), never the attacker (player)
			var target = area.get_parent()
			if "hitstop_time" in target:
				target.hitstop_time = target.hitstop_duration

			# Camera shake — only present on the player
			var attacker = get_parent()
			if attacker.has_node("PlayerCamera"):
				attacker.get_node("PlayerCamera").shake(2.5)
