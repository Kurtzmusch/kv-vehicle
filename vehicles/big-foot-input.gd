extends Node

@export var rearWheels: Array[KVWheel]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _unhandled_input(event):
	if event.is_action_pressed('toggle-rear-steering'):
		for wheel in rearWheels:
			wheel.steer = !wheel.steer
