extends Label

@export var frontWheels: Array[KVWheel]
@export var drivetrain: KVDrivetrain

var mode = 0

func _ready():
	pass

func _process(delta):
	pass

func _unhandled_input(event):
	if event.is_action_pressed('toggle-rear-steering'):
		print(mode)
		mode += 1
		mode %= 2
		if mode == 1:
			for wheel in frontWheels:
				drivetrain.poweredWheels.erase(wheel)
				wheel.powered = false
			
		if mode == 0:
			for wheel in frontWheels:
				drivetrain.poweredWheels.append(wheel)
			
		drivetrain.updatePoweredWheels()
		print(drivetrain.poweredWheels)
