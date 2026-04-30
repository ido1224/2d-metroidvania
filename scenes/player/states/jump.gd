# =============================================================
# JUMP STATE
# =============================================================
# Player just jumped and is moving upward.
#
# Transitions:
#   -> "Fall"   : velocity.y becomes >= 0 (peak of jump)
#   -> "Attack" : player presses attack
# =============================================================

extends State


func enter() -> void:
	player.perform_jump()
	player.jump_buffer_timer.stop()
	player.coyote_timer.stop()


func physics_update(delta: float) -> String:
	player.apply_gravity(delta)
	player.handle_horizontal_movement(delta)
	player.update_sprite()
	player.move_and_slide()

	# --- Ground slam ---
	if Input.is_action_just_pressed("ground_slam"):
		return "GroundSlam"

	# --- Dash ---
	if (Input.is_action_just_pressed("dash") or player._dash_buffer > 0.0) and player.has_dash and player.dash_cooldown <= 0.0 and not player.used_aerial_dash:
		player._dash_buffer = 0.0
		return "Dash"

	# --- Attack ---
	if Input.is_action_just_pressed("attack") or player._attack_buffer > 0.0:
		player._attack_buffer = 0.0
		return "Attack"

	# --- Variable jump height ---
	if Input.is_action_just_released("jump") and player.velocity.y < 0.0:
		player.velocity.y *= player.jump_cut_multiplier

	# --- Transition to Fall ---
	if player.velocity.y >= 0.0:
		return "Fall"

	return ""
