# =============================================================
# GROUND WALKER
# =============================================================
# A basic ground-patrolling enemy that moves toward the player
# and attacks with a horizontal melee strike.
#
# Attacking is now fully handled by the Attack state in the
# state machine (states/ground_walker/attack.gd). Chase detects
# melee range and transitions to Attack; Attack runs the windup
# + active phases and decides what comes next.
#
# States: Idle → Patrol → Chase → Attack / Hurt / Death
# =============================================================

extends BaseEnemy


func _physics_process(delta: float) -> void:
	# BaseEnemy handles hitstop ticking and knockback decay.
	# If hitstop is active it returns early — we must also skip
	# any subclass logic that follows.
	super(delta)
	if hitstop_time > 0.0:
		return
