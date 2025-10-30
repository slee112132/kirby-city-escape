extends Node

@export var enemy_scene: PackedScene
var score: int = 0

# HUD
var _ui_hud: CanvasLayer
var _hud_pill: PanelContainer
var _lbl_score: Label
var _lbl_star: Label


@onready var enemy_timer: Timer       = get_node_or_null("EnemyTimer") as Timer
@onready var score_timer: Timer       = get_node_or_null("ScoreTimer") as Timer
@onready var start_timer: Timer       = get_node_or_null("StartTimer") as Timer
@onready var music: AudioStreamPlayer = get_node_or_null("Music") as AudioStreamPlayer
@onready var death_sound: AudioStreamPlayer = get_node_or_null("DeathSound") as AudioStreamPlayer
@onready var player: Node             = get_node_or_null("Player")
@onready var start_pos: Marker2D      = get_node_or_null("StartPosition") as Marker2D
@onready var spawn_path: PathFollow2D = get_node_or_null("EnemyPath/EnemySpawnLocation") as PathFollow2D
@onready var cam: Camera2D            = get_node_or_null("Camera2D") as Camera2D

# FX
var _shake_tween: Tween
var _fx_layer: CanvasLayer
var _flash: ColorRect

# UI overlays
var _ui_start: CanvasLayer
var _ui_over: CanvasLayer
var _btn_play: Button
var _btn_retry: Button
var _lbl_over_score: Label

# Difficulty scaling
const LEVELS := [
	{"score": 0,   "enemy_mult": 1.00, "spawn_mult": 1.00, "player_mult": 1.00},
	{"score": 10,  "enemy_mult": 1.15, "spawn_mult": 1.10, "player_mult": 1.05},
	{"score": 25,  "enemy_mult": 1.35, "spawn_mult": 1.25, "player_mult": 1.10},
	{"score": 45,  "enemy_mult": 1.60, "spawn_mult": 1.45, "player_mult": 1.18},
	{"score": 70,  "enemy_mult": 1.90, "spawn_mult": 1.70, "player_mult": 1.25},
	{"score": 100, "enemy_mult": 2.30, "spawn_mult": 2.00, "player_mult": 1.35},
	{"score": 150, "enemy_mult": 2.40, "spawn_mult": 2.25, "player_mult": 1.5},
	{"score": 200, "enemy_mult": 2.5, "spawn_mult": 2.5, "player_mult": 1.75},
	{"score": 400, "enemy_mult": 2.75, "spawn_mult": 2.75, "player_mult": 2},
]

var _curr_level_idx: int = 0
var _base_enemy_wait: float = 1.5
var _base_player_fall: float = 300.0
var _base_player_rise: float = 250.0
var _curr_enemy_mult: float = 1.0

func _ready() -> void:
	add_to_group("game")
	_connect_timers()
	_setup_fx_overlay()
	_setup_ui_overlays()
	_setup_hud()

	# Cache bases
	if enemy_timer:
		_base_enemy_wait = max(0.1, enemy_timer.wait_time)
	if player:
		if "fall_speed" in player:
			_base_player_fall = float(player.get("fall_speed"))
		if "rise_speed" in player:
			_base_player_rise = float(player.get("rise_speed"))

	# Listen for hits
	if player and player.has_signal("hit"):
		if not player.hit.is_connected(_on_player_hit):
			player.hit.connect(_on_player_hit)

	_show_start_ui()
	_update_score_ui()  # show 0 at start

# ------------------------------
#            UI
# ------------------------------

func _make_bubble_button(text: String, base_color: Color, hover_color: Color, press_color: Color, min_size := Vector2(220, 60)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_font_size_override("font_size", 22)
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = base_color
	sb_normal.corner_radius_top_left = 30
	sb_normal.corner_radius_top_right = 30
	sb_normal.corner_radius_bottom_left = 30
	sb_normal.corner_radius_bottom_right = 30
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = hover_color
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = press_color
	b.add_theme_stylebox_override("normal", sb_normal)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_stylebox_override("focus", sb_hover)
	return b

func _setup_ui_overlays() -> void:
	var rect: Rect2i = get_viewport().get_visible_rect()
	# ---------- START UI ----------
	_ui_start = CanvasLayer.new()
	_ui_start.name = "UI_Start"
	_ui_start.layer = 100
	add_child(_ui_start)
	var start_root := Control.new()
	start_root.name = "Root"
	start_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_start.add_child(start_root)
	var start_bg := ColorRect.new()
	start_bg.color = Color(1.0, 0.83, 0.91, 1.0)
	start_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_root.add_child(start_bg)
	var start_center := CenterContainer.new()
	start_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	start_root.add_child(start_center)
	var start_box := VBoxContainer.new()
	start_box.alignment = BoxContainer.ALIGNMENT_CENTER
	start_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	start_box.add_theme_constant_override("separation", 16)
	start_center.add_child(start_box)
	var title := Label.new()
	title.text = "⭐ KIRBY FALL ⭐"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.92, 0.27, 0.61))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_box.add_child(title)
	var sub := Label.new()
	sub.text = "Float, fall, and dodge obstacles!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.67, 0.13, 0.46))
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_box.add_child(sub)
	_btn_play = _make_bubble_button("💫  Start Game", Color(1.0, 0.60, 0.75), Color(1.0, 0.66, 0.80), Color(0.95, 0.48, 0.68), Vector2(220, 60))
	_btn_play.focus_mode = Control.FOCUS_ALL
	_btn_play.pressed.connect(_on_play_pressed)
	start_box.add_child(_btn_play)

	# ---------- GAME OVER UI ----------
	_ui_over = CanvasLayer.new()
	_ui_over.name = "UI_GameOver"
	_ui_over.layer = 100
	add_child(_ui_over)
	var over_root := Control.new()
	over_root.name = "Root"
	over_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_over.add_child(over_root)
	var over_bg := ColorRect.new()
	over_bg.color = Color(1.0, 0.78, 0.87, 0.95)
	over_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_root.add_child(over_bg)
	var over_center := CenterContainer.new()
	over_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	over_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	over_root.add_child(over_center)
	var over_box := VBoxContainer.new()
	over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	over_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	over_box.add_theme_constant_override("separation", 14)
	over_center.add_child(over_box)
	var over_title := Label.new()
	over_title.text = "GAME OVER"
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_title.add_theme_font_size_override("font_size", 48)
	over_title.add_theme_color_override("font_color", Color(0.90, 0.25, 0.56))
	over_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	over_box.add_child(over_title)
	_lbl_over_score = Label.new()
	_lbl_over_score.text = "Score: 0"
	_lbl_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_over_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_over_score.add_theme_font_size_override("font_size", 28)
	_lbl_over_score.add_theme_color_override("font_color", Color(0.73, 0.18, 0.48))
	_lbl_over_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	over_box.add_child(_lbl_over_score)
	_btn_retry = _make_bubble_button("Try Again", Color(1.0, 0.55, 0.74), Color(1.0, 0.62, 0.79), Color(0.95, 0.47, 0.67), Vector2(200, 56))
	_btn_retry.focus_mode = Control.FOCUS_ALL
	_btn_retry.pressed.connect(_on_retry_pressed)
	over_box.add_child(_btn_retry)

	get_viewport().size_changed.connect(func() -> void:
		var r: Rect2i = get_viewport().get_visible_rect()
		over_root.size = r.size
		start_root.size = r.size
	)
	_ui_start.visible = false
	_ui_over.visible = false

func _setup_hud() -> void:
	_ui_hud = CanvasLayer.new()
	_ui_hud.name = "UI_HUD"
	_ui_hud.layer = 50
	add_child(_ui_hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_hud.add_child(root)

	# Top-center container
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 8
	top.offset_bottom = 80
	root.add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(center)

	# Pretty pill background with shadow
	_hud_pill = PanelContainer.new()
	_hud_pill.custom_minimum_size = Vector2(260, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.80, 0.90, 0.92)  # soft pink
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	_hud_pill.add_theme_stylebox_override("panel", sb)
	center.add_child(_hud_pill)

	# Contents
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hud_pill.add_child(row)

	_lbl_score = Label.new()
	_lbl_score.text = "Score: 0"
	_lbl_score.add_theme_font_size_override("font_size", 26)
	_lbl_score.add_theme_color_override("font_color", Color(0.24, 0.06, 0.20)) # deep kirby plum
	row.add_child(_lbl_score)

	# Make sure it stays centered on resize
	get_viewport().size_changed.connect(func() -> void:
		# no-op; anchors handle it
		pass)


func _update_score_ui(pop: bool = true) -> void:
	if _lbl_score:
		_lbl_score.text = "Score: %d" % score
		if pop:
			var t := create_tween()
			t.tween_property(_lbl_score, "scale", Vector2(1.12, 1.12), 0.08)
			t.tween_property(_lbl_score, "scale", Vector2.ONE, 0.12)

func _fade_in_ui(layer: CanvasLayer) -> void:
	if not layer or layer.get_child_count() == 0:
		return
	var root := layer.get_child(0)
	if not (root is CanvasItem):
		return
	(root as CanvasItem).modulate = Color(1, 1, 1, 0)
	layer.visible = true
	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_in_ui_delayed(layer: CanvasLayer, delay: float = 0.35, duration: float = 0.9) -> void:
	if not layer or layer.get_child_count() == 0:
		return
	var root := layer.get_child(0)
	if not (root is CanvasItem):
		return
	(root as CanvasItem).modulate = Color(1, 1, 1, 0)
	layer.visible = true
	var t := create_tween()
	var tw := t.tween_property(root, "modulate:a", 1.0, duration)
	tw.set_delay(delay)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_start_ui() -> void:
	if _ui_over: _ui_over.visible = false
	if _ui_start:
		_fade_in_ui(_ui_start)
	_stop_gameplay()

func _show_game_over_ui() -> void:
	if _ui_start: _ui_start.visible = false
	if _ui_over:
		_lbl_over_score.text = "Score: %d" % score
		_fade_in_ui_delayed(_ui_over, 0.35, 0.9)

# ------------------------------
#         BUTTONS
# ------------------------------

func _on_play_pressed() -> void:
	_ui_start.visible = false
	new_game()

func _on_retry_pressed() -> void:
	_ui_over.visible = false
	new_game()

# ------------------------------
#      CORE GAME CONTROL
# ------------------------------

func _connect_timers() -> void:
	if enemy_timer and not enemy_timer.timeout.is_connected(_on_enemy_timer_timeout):
		enemy_timer.timeout.connect(_on_enemy_timer_timeout)
	elif not enemy_timer:
		push_error("[Main] Missing Timer node: EnemyTimer")
	if score_timer and not score_timer.timeout.is_connected(_on_score_timer_timeout):
		score_timer.timeout.connect(_on_score_timer_timeout)
	elif not score_timer:
		push_error("[Main] Missing Timer node: ScoreTimer")
	if start_timer and not start_timer.timeout.is_connected(_on_start_timer_timeout):
		start_timer.timeout.connect(_on_start_timer_timeout)
	elif not start_timer:
		push_error("[Main] Missing Timer node: StartTimer")

func _on_player_hit() -> void:
	game_over()

func _stop_gameplay() -> void:
	if score_timer: score_timer.stop()
	if enemy_timer: enemy_timer.stop()

func game_over() -> void:
	_stop_gameplay()
	if music and music.playing: music.stop()
	if death_sound: death_sound.play()
	do_hit_fx()
	_show_game_over_ui()
	if has_node("KnockOut"):
		$KnockOut.play()

func new_game() -> void:
	# reset score + UI
	score = 0
	_update_score_ui(false)

# reset difficulty
	_curr_level_idx = 0
	_curr_enemy_mult = 1.0
	_apply_level(LEVELS[_curr_level_idx], true)  # <-- fixed

	# center player
	var view_size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var center: Vector2 = view_size * 0.5
	if player:
		if "linear_velocity" in player:
			player.linear_velocity = Vector2.ZERO
		player.rotation = 0.0
		if "start" in player:
			player.call_deferred("start", center)
		else:
			player.global_position = center
		if cam:
			cam.global_position = center

	# clear enemies
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

	# hide overlays
	if _ui_start: _ui_start.visible = false
	if _ui_over:  _ui_over.visible  = false

	# start timers + music
	if start_timer: start_timer.start()
	if music and not music.playing:
		music.play()

func _on_start_timer_timeout() -> void:
	if enemy_timer: enemy_timer.start()
	if score_timer: score_timer.start()

func _on_score_timer_timeout() -> void:
	score += 1
	_update_score_ui()
	_maybe_update_difficulty()

func _on_enemy_timer_timeout() -> void:
	if enemy_scene == null:
		push_error("[Main] enemy_scene is not set on Main")
		return
	if spawn_path == null:
		push_error("[Main] Missing PathFollow2D at 'EnemyPath/EnemySpawnLocation'")
		return

	var e: Node = enemy_scene.instantiate()
	var picked_kind: String = ["car", "fridge", "pole"].pick_random()
	for p in e.get_property_list():
		if p.get("name") == "kind":
			e.set("kind", picked_kind)
			break

	# pick spawn and position
	spawn_path.progress_ratio = randf()
	e.global_position = spawn_path.global_position
	e.z_index = 20

	# initial velocity (scaled by current difficulty)
	if e is RigidBody2D:
		var rb: RigidBody2D = e as RigidBody2D
		rb.gravity_scale = 0.0
		rb.linear_damp = 0.0
		rb.angular_damp = 0.0
		rb.set("continuous_cd", true)
		rb.set("ccd_mode", 1)
		var dir: float = spawn_path.rotation + PI / 2.0 + randf_range(-PI / 4.0, PI / 4.0)
		rb.rotation = dir
		var base_spd: float = randf_range(120.0, 240.0)
		var spd: float = base_spd * LEVELS[_curr_level_idx]["enemy_mult"]
		rb.linear_velocity = Vector2(spd, 0.0).rotated(dir)

	add_child(e)

# ------------------------------
#        DIFFICULTY
# ------------------------------

func _maybe_update_difficulty() -> void:
	# find highest level whose score threshold is <= current score
	var idx := _curr_level_idx
	for i in range(LEVELS.size()):
		if score >= int(LEVELS[i]["score"]):
			idx = i
	if idx != _curr_level_idx:
		_curr_level_idx = idx
		_apply_level(LEVELS[_curr_level_idx])

func _apply_level(level: Dictionary, initial: bool = false) -> void:
	# enemy spawn rate
	var spawn_mult: float = float(level["spawn_mult"])
	if enemy_timer:
		enemy_timer.wait_time = max(0.12, _base_enemy_wait / spawn_mult)

	# player speeds
	var p_mult: float = float(level["player_mult"])
	if player:
		if "fall_speed" in player:
			player.set("fall_speed", _base_player_fall * p_mult)
		if "rise_speed" in player:
			player.set("rise_speed", _base_player_rise * p_mult)

	# existing enemies — scale their velocity proportionally
	var new_enemy_mult: float = float(level["enemy_mult"])
	var scale := new_enemy_mult / _curr_enemy_mult
	if not initial and abs(scale - 1.0) > 0.001:
		get_tree().call_group("enemies", "multiply_speed", scale)
	_curr_enemy_mult = new_enemy_mult

# ------------------------------
#              FX
# ------------------------------

func _setup_fx_overlay() -> void:
	_fx_layer = get_node_or_null("UI_FX") as CanvasLayer
	if _fx_layer == null:
		_fx_layer = CanvasLayer.new()
		_fx_layer.name = "UI_FX"
		add_child(_fx_layer)
	_flash = get_node_or_null("UI_FX/Flash") as ColorRect
	if _flash == null:
		_flash = ColorRect.new()
		_flash.name = "Flash"
		_flash.color = Color(1, 1, 1, 0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Rect2i = get_viewport().get_visible_rect()
		_flash.size = r.size
		_fx_layer.add_child(_flash)
	get_viewport().size_changed.connect(func() -> void:
		if is_instance_valid(_flash):
			var rr: Rect2i = get_viewport().get_visible_rect()
			_flash.size = rr.size
	)

func do_hit_fx() -> void:
	screen_flash(0.85, 0.18)
	camera_shake(0.28, 10.0, 7)

func screen_flash(alpha: float = 0.85, duration: float = 0.2) -> void:
	if _flash == null: return
	_flash.color = Color(1, 1, 1, alpha)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func camera_shake(duration: float = 0.25, magnitude: float = 8.0, steps: int = 6) -> void:
	if cam == null: return
	if _shake_tween and _shake_tween.is_running(): _shake_tween.kill()
	var orig: Vector2 = cam.offset
	_shake_tween = create_tween()
	var seg: float = max(0.01, duration / float(max(1, steps)))
	for i in range(steps):
		var target: Vector2 = orig + Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude))
		_shake_tween.tween_property(cam, "offset", target, seg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(cam, "offset", orig, seg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
