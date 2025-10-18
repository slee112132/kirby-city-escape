extends RigidBody2D

@export var speed := 250.0
@export_enum("car","fridge","pole") var kind := "car"

@onready var anim: AnimatedSprite2D = $Obstacles

@onready var _shapes := {
	"car":    $Shape_Car,
	"fridge": $Shape_Fridge,
	"pole":   $Shape_Pole,
}

func _ready() -> void:
	gravity_scale = 0.0
	custom_integrator = true
	contact_monitor = true
	max_contacts_reported = 4
	z_index = 20
	collision_layer = 1 << 3
	collision_mask  = 1 << 1

	_enable_only(kind)
	_apply_visual(kind)
	add_to_group("enemies")

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		body_entered.connect(_on_body_entered)


func _enable_only(name: String) -> void:
	for s in _shapes.values():
		if s: s.disabled = true
	if _shapes.has(name) and _shapes[name]:
		_shapes[name].disabled = false

func _apply_visual(name: String) -> void:
	if anim == null:
		push_error("Obstacles (AnimatedSprite2D) not found.")
		return
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		push_error("AnimatedSprite2D is missing an animation named '%s'." % name)
		return
	anim.animation = name
	# If you set only 1 frame per kind and want it static, you can leave it stopped.
	if not anim.is_playing():
		anim.play()

func _process(delta: float) -> void:
	if global_position.y > get_viewport_rect().size.y + 64.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("game", "game_over")
