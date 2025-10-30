extends TextureRect

@export var rise_action: StringName = &"move_up"
@export var fall_scroll_speed: float = 120.0
@export var rise_scroll_speed: float = 65.0
@export var smooth: float = 8.0

var _mat: ShaderMaterial
var _uv_off: Vector2 = Vector2.ZERO
var _uv_vel: float = 0.0

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_TILE
	if material == null or !(material is ShaderMaterial):
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
uniform vec2 uv_offset = vec2(0.0, 0.0);
void fragment() {
    vec2 uv = fract(UV + uv_offset);
    COLOR = texture(TEXTURE, uv);
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat
	else:
		_mat = material as ShaderMaterial

func _process(delta: float) -> void:
	if _mat == null:
		return
	var target_px_per_sec: float
	if Input.is_action_pressed(rise_action):
		target_px_per_sec = -rise_scroll_speed
	else:
		target_px_per_sec = fall_scroll_speed
	if smooth > 0.0:
		_uv_vel = lerp(_uv_vel, target_px_per_sec, clamp(smooth * delta, 0.0, 1.0))
	else:
		_uv_vel = target_px_per_sec
	var uv_per_sec: float = _uv_vel / max(1.0, float(size.y))
	_uv_off.y += uv_per_sec * delta
	_mat.set_shader_parameter("uv_offset", _uv_off)
