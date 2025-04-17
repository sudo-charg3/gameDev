extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _process(delta):
	animation_player.play("casc")
