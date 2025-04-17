extends Node3D

@export var rotation_speed: float = 2.0
@export var bullet_scene: PackedScene
@export var shoot_interval: float = 2.0
#@onready var player = $"../player"
@onready var player = $"../player/player_ka_dil"

#@onready var player = get_node($"../player") # Adjust this to match your actual scene path
@onready var bullet_spawn = $BulletSpawn
@onready var timer = $Timer

func _ready():
	timer.wait_time = shoot_interval
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var to_player: Vector3 = (player.global_position - global_position).normalized()
	var target_rotation = facing_rotation_towards(to_player)

	# Smoothly interpolate toward the target rotation
	rotation = rotation.slerp(target_rotation, rotation_speed * delta)

func facing_rotation_towards(direction: Vector3) -> Vector3:
	# Build the rotation that would look in the direction we want
	var basis = Basis()
	basis = basis.looking_at(direction, Vector3.UP)
	return basis.get_euler()

func _on_timer_timeout() -> void:
	shoot()

func shoot() -> void:
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)  # Or use `get_parent()` if bullets stay in the same container

	bullet.global_position = bullet_spawn.global_position

	var direction = (player.global_position - bullet_spawn.global_position).normalized()
	bullet.look_at(player.global_position, Vector3.UP)

	if bullet.has_method("set_velocity"):
		bullet.set_velocity(direction)
