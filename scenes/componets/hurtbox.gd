extends Area2D

signal hurt(damage: int, knockback: Vector2)

## Emitted the frame invincibility expires — used by player.gd to stop
## the i-frame sprite flash and restore visibility.
signal invincibility_ended

## How many frames of invincibility the player gets after being hit.
## Assumes 60 fps physics — 78 frames ≈ 1.3 s (Hollow Knight baseline).
@export_range(1, 180, 1, "suffix:frames") var invincibility_frames: int = 78

var is_invincible: bool = false
var invincibility_timer: Timer


func _ready() -> void:
	monitoring = false
	monitorable = true

	invincibility_timer = Timer.new()
	invincibility_timer.wait_time = invincibility_frames / 60.0
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)


## Returns true if damage went through, false if blocked by i-frames.
## Callers (hitboxes) should only apply hitstop / camera shake / flash
## when this returns true — otherwise those effects fire during i-frames
## and make a blocked hit feel identical to a real one.
func take_hit(damage: int, knockback: Vector2) -> bool:
	if is_invincible:
		return false

	is_invincible = true
	invincibility_timer.start()
	hurt.emit(damage, knockback)
	return true


func _on_invincibility_timeout() -> void:
	is_invincible = false
	invincibility_ended.emit()
