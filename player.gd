extends RigidBody2D
signal hit
@export var speed = 400 # How fast the player will move (pixels/sec).
@export var fall_speed := 300.0      # constant downward speed
@export var rise_speed := 250.0      # how fast you move upward
@export var move_speed := 220.0      # left/right speed
var screen_size # Size of the game window.


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var dir_x := 0.0
	var dir_y := 1.0        # default = falling

	# horizontal
	if Input.is_action_pressed("move_right"):
		dir_x += 1.0
	if Input.is_action_pressed("move_left"):
		dir_x -= 1.0

	# upward movement cancels fall while key held
	if Input.is_action_pressed("move_up"):
		dir_y = -rise_speed / fall_speed

	# build velocity (no normalization)
	var velocity := Vector2(dir_x * move_speed, dir_y * fall_speed)

	# move
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)

	# flip + animation
	if dir_y < 0.0:
		$Kirby.animation = "rising"
	else:
		$Kirby.animation = "falling"

	if dir_x != 0.0:
		$Kirby.flip_h = dir_x < 0.0

	if dir_x != 0.0 or dir_y != 0.0:
		$Kirby.play()
	else:
		$Kirby.stop()

		

func _on_body_entered(_body):
	hide() # Player disappears after being hit.
	hit.emit()
	# Must be deferred as we can't change physics properties on a physics callback.
	$CollisionShape2D.set_deferred("disabled", true)
func start(pos):
	position = pos
	show()
	$CollisionShape2D.disabled = false


func _on_hurtbox_body_entered(body: Node) -> void:
	print("HURTBOX body_entered by:", body.name, " groups:", body.get_groups())
	if body.is_in_group("enemies"):
		print("HIT CONFIRMED")
		hide()
		hit.emit()
		$CollisionShape2D.set_deferred("disabled", true)
