extends VBoxContainer

const WORLD = preload("res://scenes/level01.tscn")

func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_packed(WORLD)
	

func _on_exit_pressed() -> void:
	pass # Replace with function body.
	get_tree().quit()
