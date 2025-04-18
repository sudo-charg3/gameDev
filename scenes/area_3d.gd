extends Area3D

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.name == "player": # Make sure your player node is named "Player"
		get_tree().reload_current_scene()
