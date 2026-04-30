extends Camera2D

@export var follow_speed := 6.0

var target: Node2D
var room_rect: Rect2

func _ready():
	make_current() # Correct for Godot 4
	target = get_parent().get_node("Player")

func _process(delta):
	if target:
		global_position = global_position.lerp(
			target.global_position,
			follow_speed * delta
		)

func set_room_limits(rect: Rect2):
	room_rect = rect
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.position.x + rect.size.x
	limit_bottom = rect.position.y + rect.size.y
