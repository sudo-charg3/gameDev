extends Label

@onready var world: Node3D = $".."

var time := 0.0

func _ready():
	time = world.speedrun_time

func _physics_process(delta: float) -> void:
	time += delta
	update_ui()

func update_ui() -> void:
	var formatted_time := "%.2f" % time
	world.speedrun_time = time
	text = formatted_time
