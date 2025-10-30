class_name ObstacleEnemy
extends RigidBody2D

@export var speed: float = 250.0
@export_enum("car", "fridge", "pole") var kind: String = "car"

@onready var anim: AnimatedSprite2D = get_node_or_null("Obstacles") as AnimatedSprite2D
@onready var _shapes := {
	"car":    get_node_or_null("Shape_Car"),
	"fridge": get_node_or_null("Shape_Fridge"),
	"pole":   get_node_or_null("Shape_Pole"),
}

var _fallback_shapes: Array[Node] = []
var _hit: bool = false
var _base_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	set("continuous_cd", true)
	set("ccd_mode", 1)
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	physics_material_override.bounce = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	z_index = 20
	collision_layer = 1 << 3
	collision_mask  = 1 << 1
	_collect_shapes(self)
	_enable_only(kind)
	_apply_visual(kind)
	add_to_group("enemies")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if _base_vel == Vector2.ZERO and linear_velocity.length() > 0.0:
		_base_vel = linear_velocity
	if not _hit and _base_vel != Vector2.ZERO:
		linear_velocity = _base_vel

func _process(_delta: float) -> void:
	var vp_size: Vector2i = get_viewport().get_visible_rect().size
	if global_position.y > float(vp_size.y) + 64.0 \
	or global_position.x < -128.0 or global_position.x > float(vp_size.x) + 128.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit: return
	if body.is_in_group("player"):
		_hit = true
		if "take_hit_from" in body:
			body.take_hit_from(self)
		elif "take_hit" in body:
			body.take_hit()
		else:
			get_tree().call_group("game", "game_over")
		_disable_collisions()
		_base_vel = Vector2.ZERO
		linear_velocity = Vector2.ZERO
		_fade_and_free(0.15)

func _enable_only(name: String) -> void:
	for s in _shapes.values():
		if s: s.disabled = true
	for fs in _fallback_shapes:
		if fs is CollisionShape2D:
			(fs as CollisionShape2D).disabled = true
		elif fs is CollisionPolygon2D:
			(fs as CollisionPolygon2D).disabled = true
	var enabled_any := false
	if _shapes.has(name) and _shapes[name]:
		var node: Node = _shapes[name]
		if node is CollisionShape2D:
			(node as CollisionShape2D).disabled = false; enabled_any = true
		elif node is CollisionPolygon2D:
			(node as CollisionPolygon2D).disabled = false; enabled_any = true
		else:
			_set_shapes_disabled(node, false)
			enabled_any = _count_enabled_shapes_under(node) > 0
	if not enabled_any and _fallback_shapes.size() > 0:
		for fs in _fallback_shapes:
			if fs is CollisionShape2D:
				(fs as CollisionShape2D).disabled = false
			elif fs is CollisionPolygon2D:
				(fs as CollisionPolygon2D).disabled = false

func _apply_visual(name: String) -> void:
	if anim == null:
		return
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		return
	anim.animation = name
	if not anim.is_playing():
		anim.play()

func _fade_and_free(duration: float) -> void:
	var target: CanvasItem = (anim as CanvasItem) if anim != null else (self as CanvasItem)
	var t: Tween = create_tween()
	t.tween_property(target, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.finished.connect(queue_free)

func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask  = 0
	contact_monitor = false

func _collect_shapes(root: Node) -> void:
	for c in root.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			_fallback_shapes.append(c)
		if c.get_child_count() > 0:
			_collect_shapes(c)

func _set_shapes_disabled(root: Node, disabled: bool) -> void:
	for c in root.get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).disabled = disabled
		elif c is CollisionPolygon2D:
			(c as CollisionPolygon2D).disabled = disabled
		if c.get_child_count() > 0:
			_set_shapes_disabled(c, disabled)

func _count_enabled_shapes() -> int:
	var n := 0
	for s in _fallback_shapes:
		if s is CollisionShape2D and not (s as CollisionShape2D).disabled: n += 1
		elif s is CollisionPolygon2D and not (s as CollisionPolygon2D).disabled: n += 1
	return n

func _count_enabled_shapes_under(root: Node) -> int:
	var n := 0
	for c in root.get_children():
		if c is CollisionShape2D and not (c as CollisionShape2D).disabled: n += 1
		elif c is CollisionPolygon2D and not (c as CollisionPolygon2D).disabled: n += 1
		if c.get_child_count() > 0:
			n += _count_enabled_shapes_under(c)
	return n
# Scale this enemy's speed by a factor at runtime (used for difficulty bumps)
func multiply_speed(f: float) -> void:
	if f == 0.0: return
	linear_velocity *= f
	if " _base_vel" in self: # if you kept a cached base vel as in earlier versions
		_base_vel *= f
