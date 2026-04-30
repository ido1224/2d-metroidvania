# =============================================================
# GROUND WALKER — DEATH STATE
# =============================================================
# Enemy is dead. Disables all hitbox/hurtbox interactions and
# calls enemy.die() which plays a shrink/fade tween then frees
# the node. No transitions out of this state.
#
# Entered via EnemyStateMachine.force_transition("Death").
# =============================================================

extends EnemyState


func enter() -> void:
	# Stop all movement immediately
	enemy.velocity = Vector2.ZERO

	# Prevent any further damage or dealing damage
	var hurtbox := enemy.get_node("Hurtbox")
	hurtbox.monitoring = false
	hurtbox.set_deferred("monitorable", false)
	enemy.get_node("Hitbox").deactivate()

	# Hand off to base_enemy.die() — async tween then queue_free
	enemy.die()


func physics_update(_delta: float) -> String:
	# Enemy is being freed by the tween; no transitions
	return ""
