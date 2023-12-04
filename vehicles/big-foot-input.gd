extends Node

@export var rearWheels: Array[KVWheel]

var vehicle: KVVehicle

# Called when the node enters the scene tree for the first time.
func _ready():
	vehicle = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _unhandled_input(event):
	if event.is_action_pressed('toggle-rear-steering'):
		for wheel in rearWheels:
			wheel.steer = !wheel.steer

func _physics_process(delta):
	vehicle.accelerateRoll(-vehicle.localAngularVelocity.z*4.0)
