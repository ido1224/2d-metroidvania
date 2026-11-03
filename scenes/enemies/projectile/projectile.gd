# =============================================================
# PROJECTILE (reusable enemy shot)
# =============================================================
# A slow orb that flies in a straight line. Any enemy can fire
# one: instance projectile.tscn, add it to the room, set its
# global_position, then call launch(direction, speed).
#
#   - Pops on World geometry (root Area2D masks World = 1)
#   - Pops when its Hitbox touches the player's hurtbox
#     (a pierce dash disables that hurtbox, so it passes through)
#   - Pops after `lifetime` seconds
#   - HIT IT BACK: its Hurtbox sits on EnemyHurtbox (64), so the
#     player's attack can hit it. It then reverses in the
#     direction of the swing, speeds up, turns white, and its
#     Hitbox switches to the PLAYER's side (layer 8, mask 64),
#     so it damages enemies — including whoever fired it.
#
# Drawn with _draw(), no texture needed.
# =============================================================

class_name Projectile
extends Area2D

## Seconds before it fizzles out on its own
@export var lifetime: float = 4.0

## Speed multiplier when the player hits it back
@export var reflect_speed_mult: float = 1.6

## Visual radius (pixels). The hit shapes are set in the .tscn.
@export var radius: float = 4.0

@export var color: Color = Color(1.0, 0.55, 0.15)
@export var reflected_color: Color = Color(0.85, 0.95, 1.0)

var velocity: Vector2 = Vector2.ZERO
var reflected: bool = false

var _age: float = 0.0
var _popped: bool = false

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Hitbox's own area_entered handler (connected in its _ready, which ran
	# first) applies the damage; this one just pops the orb afterwards.
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hurtbox.hurt.connect(_on_hurt)


## Start flying. [direction] is normalised here.
func launch(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	hitbox.activate(_flat_knockback_dir(velocity))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _popped:
		return
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		pop()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, reflected_color if reflected else color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 1.0, 0.85))


## Burst and disappear. Safe to call more than once.
func pop() -> void:
	if _popped:
		return
	_popped = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(2.2, 2.2), 0.08)
	t.tween_property(self, "modulate:a", 0.0, 0.08)
	t.chain().tween_callback(queue_free)


# ── Signals ──────────────────────────────────────────────────────────────────

func _on_body_entered(_body: Node2D) -> void:
	pop()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area != hurtbox and area.has_method("take_hit"):
		pop()


# The player's attack hit the orb: send it back.
func _on_hurt(_damage: int, knockback: Vector2) -> void:
	if reflected or _popped:
		return
	reflected = true
	var dir: Vector2 = knockback.normalized() if not knockback.is_zero_approx() else -velocity.normalized()
	velocity = dir * velocity.length() * reflect_speed_mult
	_age = 0.0

	# Switch sides: now a player hitbox (layer 8) that hits enemy hurtboxes (64).
	# Deferred because we're inside a physics callback.
	hitbox.set_deferred("collision_layer", 8)
	hitbox.set_deferred("collision_mask", 64)
	hurtbox.set_deferred("monitorable", false)
	hitbox.call_deferred("activate", _flat_knockback_dir(velocity))
	queue_redraw()


# Knock whoever it hits straight sideways (player.gd / enemy Hurt states add
# their own vertical handling). Matches the walker and flyer.
func _flat_knockback_dir(v: Vector2) -> Vector2:
	return Vector2(signf(v.x) if absf(v.x) > 0.1 else 1.0, 0.0)
