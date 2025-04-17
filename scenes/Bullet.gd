extends RigidBody3D  # or CharacterBody3D

@export var speed: float = 20.0
var velocity: Vector3 = Vector3.ZERO

func set_velocity(dir: Vector3) -> void:
	velocity = dir.normalized() * speed

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
