extends RigidBody2D
signal hit
signal rise_changed(is_rising: bool)

@export var fall_speed: float = 300.0
@export var rise_speed: float = 250.0
@export var move_speed: float = 220.0
@export var knock_speed: float = 700.0
@export var offscreen_margin: float = 96.0

var screen_size: Vector2
var is_rising: bool = false
var _is_hit: bool = false

@onready var _sprite: AnimatedSprite2D = get_node_or_null("Kirby") as AnimatedSprite2D
@onready var _col: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	set("continuous_cd", true)
	set("ccd_mode", 1)
	if not is_in_group("player"):
		add_to_group("player")
	collision_layer = 1 << 1
	collision_mask  = 1 << 3
	if _col:
		_col.disabled = false

func _physics_process(delta: float) -> void:
	if _is_hit:
		var vp := get_viewport().get_visible_rect().size
		if global_position.y < -offscreen_margin \
		or global_position.y > float(vp.y) + offscreen_margin \
		or global_position.x < -offscreen_margin \
		or global_position.x > float(vp.x) + offscreen_margin:
			if is_visible():
				hide()
		return
	var dir_x := 0.0
	var vy := fall_speed
	if Input.is_action_pressed("move_up"):
		vy = -rise_speed
	if Input.is_action_pressed("move_right"):
		dir_x += 1.0
	if Input.is_action_pressed("move_left"):
		dir_x -= 1.0
	linear_velocity = Vector2(dir_x * move_speed, vy)
	var p := global_position
	var clamped := p.clamp(Vector2.ZERO, screen_size)
	if p != clamped:
		global_position = clamped
		linear_velocity.x = 0.0
	var now_rising := vy < 0.0
	if now_rising != is_rising:
		is_rising = now_rising
		rise_changed.emit(is_rising)
	if _sprite:
		_sprite.animation = "rising" if vy < 0.0 else "falling"
		if dir_x != 0.0:
			_sprite.flip_h = dir_x < 0.0
		if dir_x != 0.0 or vy != 0.0:
			_sprite.play()
		else:
			_sprite.stop()

func start(pos: Vector2) -> void:
	global_position = pos
	show()
	_is_hit = false
	if _col: _col.set_deferred("disabled", false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	if _sprite:
		_sprite.modulate = Color(1,1,1,1)
		_sprite.animation = "falling"
		_sprite.play()

func take_hit_from(enemy: Node) -> void:
	var dir := Vector2.ZERO
	if "linear_velocity" in enemy and (enemy.linear_velocity as Vector2).length() > 0.0:
		dir = (enemy.linear_velocity as Vector2).normalized()
	elif "global_position" in enemy:
		dir = (global_position - enemy.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_is_hit = true
	hit.emit()
	if _col:
		_col.set_deferred("disabled", true)
	linear_velocity = dir * knock_speed
	angular_velocity = 0.0
	if _sprite:
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("hit"):
			_sprite.animation = "hit"
			_sprite.play()
		else:
			var t := create_tween()
			_sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
			t.tween_property(_sprite, "modulate", Color(1,1,1,1), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func take_hit() -> void:
	take_hit_from(self)
