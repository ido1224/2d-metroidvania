# =============================================================
# RUN STATE
# =============================================================
# Player is on the ground and moving.
#
# Transitions:
#   -> "Idle"   : player stops and velocity reaches zero
#   -> "Jump"   : player presses jump
#   -> "Fall"   : player runs off a ledge
#   -> "Attack" : player presses attack
# =============================================================

extends State


func enter() -> void:
	pass


func physics_update(delta: float) -> String:
	player.handle_horizontal_movement(delta)
	player.apply_gravity(delta)
	player.update_sprite()
	player.update_coyote_time()
	player.move_and_slide()

	# --- Dash ---
	if (Input.is_action_just_pressed("dash") or player._dash_buffer > 0.0) and player.has_dash and player.dash_cooldown <= 0.0 and not player.used_aerial_dash:
		player._dash_buffer = 0.0
		return "Dash"

	# --- Attack ---
	if Input.is_action_just_pressed("attack") or player._attack_buffer > 0.0:
		player._attack_buffer = 0.0
		return "Attack"

	# --- Jump ---
	if Input.is_action_just_pressed("jump") or not player.jump_buffer_timer.is_stopped():
		return "Jump"

	# --- Stopped moving ---
	var input_dir: float = Input.get_axis("move_left", "move_right")
	if input_dir == 0.0 and abs(player.velocity.x) < 1.0:
		return "Idle"

	# --- Airborne ---
	if not player.is_on_floor():
		return "Fall"

	return ""
