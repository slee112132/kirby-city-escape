extends Node

@export var enemy_scene: PackedScene
var score := 0

func _ready() -> void:
	# Wire timers (okay if already connected in the editor)
	$EnemyTimer.timeout.connect(_on_enemy_timer_timeout)
	$ScoreTimer.timeout.connect(_on_score_timer_timeout)
	$StartTimer.timeout.connect(_on_start_timer_timeout)
	new_game()

func game_over() -> void:
	$ScoreTimer.stop()
	$EnemyTimer.stop()
	$Music.stop()
	$DeathSound.play()

func new_game() -> void:
	score = 0
	$Player.start($StartPosition.position)

	# Clear any existing enemies (make sure Enemy.gd adds itself to "enemies")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

	$StartTimer.start()
	if not $Music.playing:
		$Music.play()

func _on_start_timer_timeout() -> void:
	# Adjust wait_time for spawn rate if you like, e.g.:
	# $EnemyTimer.wait_time = 1.25
	$EnemyTimer.start()
	$ScoreTimer.start()

func _on_score_timer_timeout() -> void:
	score += 1
	# $HUD.update_score(score)  # if/when you re-enable HUD

func _on_enemy_timer_timeout() -> void:
	if enemy_scene == null:
		push_error("enemy_scene is not set on Main"); 
		return

	var e = enemy_scene.instantiate()

	# Optional: set variant if your Enemy.gd exposes set_kind(...)
	e.kind = ["car", "fridge", "pole"].pick_random()

	# Pick a spawn point along the path
	var spawn: PathFollow2D = $EnemyPath/EnemySpawnLocation
	spawn.progress_ratio = randf()

	# Place on screen and ensure it renders above backgrounds
	e.global_position = spawn.global_position
	e.z_index = 20

	# If enemy root is RigidBody2D, give it motion and disable gravity
	if e is RigidBody2D:
		var rb := e as RigidBody2D
		rb.gravity_scale = 0.0
		var dir: float = spawn.rotation + PI / 2.0 + randf_range(-PI / 4.0, PI / 4.0)
		rb.rotation = dir
		var speed: float = randf_range(120.0, 240.0)
		rb.linear_velocity = Vector2(speed, 0.0).rotated(dir)

	# If enemy is Area2D instead, give it its own _process to move down.

	add_child(e)
	# print("Spawned enemy at ", e.global_position)  # debug if needed
