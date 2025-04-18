extends Node3D

@onready var cam_pivot = $cam_pivot

@export var speedrun_time = 0
var rotation_speed = 10

func _process(delta):
	cam_pivot.rotation_degrees.y += delta * rotation_speed
