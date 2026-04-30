# =============================================================
# FALL STATE
# =============================================================
# Player is in the air and moving downward.
#
# Transitions:
#   -> "Jump"   : coyote jump
#   -> "Idle"   : lands with no input
#   -> "Run"    : lands while moving
#   -> "Attack" : player presses attack
# =============================================================

extends State


func enter() -> void:
	pass


func physics_update(delta: float) -> String:
	player.apply_gravity(delta)
	player.handle_horizontal_movement(delta)
	player.update_sprite()
	player.update_coyote_time()
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

	# --- Coyote jump ---
	if Input.is_action_just_pressed("jump"):
		if player.can_coyote_jump:
			return "Jump"
		else:
			player.jump_buffer_timer.start()

	# --- Landing ---
	if player.is_on_floor():
		if not player.jump_buffer_timer.is_stopped():
			return "Jump"

		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			return "Run"
		else:
			return "Idle"

	return ""
